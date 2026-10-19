#!/usr/bin/env python3
"""Generate agent tasks, context packs and STATUS.md from the module specifications.

Usage:  python3 agent/tools/gen_tasks.py

- One task per requirement group (section 4.x) of every module in docs/software/basic.
- agent/tasks/basic.json keeps the implementation state (status, verified, evidence, notes)
  of existing tasks; everything else is regenerated from the specifications.
- agent/packs/<task>.md contains only the parts of a specification that belong to the task.
- docs/software/basic/STATUS.md is generated from agent/tasks/basic.json.

Standard library only. The specifications are never modified.
"""
import hashlib
import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC_DIR = ROOT / "docs" / "software" / "basic"
TASKS_FILE = ROOT / "agent" / "tasks" / "basic.json"
PACK_DIR = ROOT / "agent" / "packs"
STATUS_FILE = SPEC_DIR / "STATUS.md"
SKIP = {"README.md", "STATUS.md"}
REPO_EXCLUDE = {".git", "docs", "agent", ".vscode"}

STATE_FIELDS = ("status", "verified", "evidence", "notes")
STATUSES = ("todo", "in_progress", "implemented", "verified", "blocked", "deferred", "obsolete")

REQ_RE = re.compile(r"^- `(BASE-[A-Z]+-\d+)` \*\*(MUST|SHOULD|MAY)\*\* (.*)$")
ID_RE = re.compile(r"BASE-[A-Z]+-\d\d")
RANGE_RE = re.compile(r"`(BASE-[A-Z]+)-(\d\d)`\s*…\s*`(?:BASE-[A-Z]+)?-?(\d\d)`")
SHORT_RE = re.compile(r"`(BASE-[A-Z]+)-\d\d`((?:\s*,\s*`-\d\d`)+)")


# ---------------------------------------------------------------- parsing

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def split_sections(text):
    """Return {number: [lines]} for '## N. Title' sections and the title line."""
    sections, current = {}, None
    title = ""
    for line in text.split("\n"):
        if line.startswith("# ") and not title:
            title = line[2:].strip()
        m = re.match(r"^## (\d+)\. ", line)
        if m:
            current = m.group(1)
            sections[current] = []
            continue
        if current:
            sections[current].append(line)
    return title, sections


def header_fields(text):
    fields = {}
    for m in re.finditer(r"^\| \*\*(.+?)\*\* \| (.+?) \|$", text, re.M):
        fields[m.group(1)] = m.group(2).strip()
    return fields


def ids_in(text, defined):
    """All requirement IDs a text refers to, including ranges and short forms."""
    found = set(ID_RE.findall(text))
    for m in RANGE_RE.finditer(text):
        prefix, a, b = m.group(1), int(m.group(2)), int(m.group(3))
        found |= {i for i in defined if i.startswith(prefix + "-") and a <= int(i.rsplit("-", 1)[1]) <= b}
    for m in SHORT_RE.finditer(text):
        prefix = m.group(1)
        for n in re.findall(r"`-(\d\d)`", m.group(2)):
            found.add(f"{prefix}-{n}")
    return found & defined if defined else found


def tables(lines):
    """Yield (subsection, header_row, separator_row, [rows]) for every markdown table."""
    sub, i = None, 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("### "):
            sub = line[4:].strip()
        if line.startswith("|") and i + 1 < len(lines) and lines[i + 1].startswith("| :-"):
            header, sep, rows = line, lines[i + 1], []
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(lines[i])
                i += 1
            yield sub, header, sep, rows
            continue
        i += 1


def subsection_text(lines, number):
    """Full text of '### <number> ...' inside a section."""
    out, inside = [], False
    for line in lines:
        if line.startswith("### "):
            inside = line.startswith(f"### {number} ")
        if inside:
            out.append(line)
    return "\n".join(out).strip()


def bullets(lines):
    return [l for l in lines if l.startswith("- ")]


def parse_module(path):
    text = read(path)
    title, sec = split_sections(text)
    hdr = header_fields(text)
    module = re.sub(r"`", "", hdr.get("Module ID", "")).strip()
    groups, current = [], None
    for line in sec.get("4", []):
        m = re.match(r"^### (4\.\d+) (.*)$", line)
        if m:
            current = {"number": m.group(1), "title": m.group(2).strip(), "reqs": []}
            groups.append(current)
            continue
        r = REQ_RE.match(line)
        if r:
            if current is None:
                current = {"number": "4", "title": "Requirements", "reqs": []}
                groups.append(current)
            current["reqs"].append({"id": r.group(1), "level": r.group(2), "text": r.group(3)})
    return {
        "path": path,
        "rel": path.relative_to(ROOT).as_posix(),
        "text": text,
        "title": title,
        "module": module,
        "header": hdr,
        "sections": sec,
        "groups": groups,
        "depends": sorted(set(re.findall(r"BASE-[A-Z]+", hdr.get("Depends on", ""))) - {module}),
        "risk": re.sub(r"`", "", hdr.get("Risk", "")).strip(),
        "spec_status": re.sub(r"`", "", hdr.get("Spec status", "")).strip(),
        "hash": hashlib.sha256(text.encode("utf-8")).hexdigest()[:16],
    }


def phase_map():
    text = read(SPEC_DIR / "README.md")
    phases = {}
    for m in re.finditer(r"^\| \*\*(\d+) – ([^*]+)\*\* \| ([^|]*) \|", text, re.M):
        for mod in re.findall(r"BASE-[A-Z]+", m.group(3)):
            phases[mod] = int(m.group(1))
    return phases


# ---------------------------------------------------------------- repo hints

def repo_index():
    files = []
    for p in ROOT.rglob("*"):
        rel = p.relative_to(ROOT)
        if rel.parts and rel.parts[0] in REPO_EXCLUDE:
            continue
        if p.is_file():
            files.append(rel.as_posix())
    return files


def repo_hints(mod, index):
    names = set()
    for _, _, _, rows in tables(mod["sections"].get("3", [])):
        for row in rows:
            first = row.split("|")[1]
            for n in re.findall(r"`([a-z0-9][a-z0-9+._-]*)`", first):
                names.add(re.sub(r"[-_]?\d[\d.]*$", "", n.split(".bb")[0]))
    hits = []
    for n in sorted(names):
        if len(n) < 3:
            continue
        m = [f for f in index if f"/{n}" in "/" + f or f"{n}_" in f or f"{n}." in f.rsplit("/", 1)[-1]]
        if m:
            hits.append(f"- `{n}`: " + ", ".join(f"`{x}`" for x in m[:6]) + (" …" if len(m) > 6 else ""))
        elif n.startswith("modberry-"):
            hits.append(f"- `{n}`: new recipe (does not exist yet)")
    return hits


# ---------------------------------------------------------------- tasks & packs

def open_points(mod, defined):
    """Open points of a module with the requirement IDs they affect.

    An open point blocks if its decision is empty or starts with **Deferred**.
    'all' in the Affects column means every requirement of the module.
    """
    all_ids = {r["id"] for g in mod["groups"] for r in g["reqs"]}
    out = []
    for _, header, sep, rows in tables(mod["sections"].get("9", [])):
        for row in rows:
            cells = [c.strip() for c in row.strip().strip("|").split("|")]
            if len(cells) < 4:
                continue
            affects = ids_in(cells[2], defined) & all_ids
            if cells[2].strip() == "all":
                affects = set(all_ids)
            decision = cells[-1]
            out.append({"no": cells[0], "question": cells[1], "affects": affects, "decision": decision,
                        "blocking": not decision or decision.startswith("**Deferred"),
                        "verification": "verification task" in decision,
                        "row": row, "header": (header, sep)})
    return out


def build_verification_tasks(mod, defined, phases):
    """One V-task per deferred open point that needs a test or measurement on the device."""
    tasks, packs = [], []
    for op in open_points(mod, defined):
        if not (op["blocking"] and op["verification"]):
            continue
        tid = f"V-{mod['module']}-OP{op['no']}"
        task = {
            "id": tid, "module": mod["module"], "spec": mod["rel"], "spec_hash": mod["hash"],
            "group": f"OP{op['no']}", "title": f"Verify: {op['question']}",
            "phase": phases.get(mod["module"]), "risk": mod["risk"], "human_gate": True,
            "depends_on_modules": [], "reqs": [{"id": i, "level": "—"} for i in sorted(op["affects"])],
            "verify_levels": ["device"], "blocked_by": [], "blocked_reqs": [],
            "pack": f"agent/packs/{tid}.md", "status": "todo", "verified": {"device": "pending"},
            "evidence": [], "notes": "",
        }
        md = [f"# {tid} – {task['title']}", "",
              f"Module `{mod['module']}` · spec `{mod['rel']}` · open point {op['no']}", "",
              "This is a verification task: measure or check on the device (or in the schematic) and record the "
              "result in `notes` and `evidence`. A human then decides the open point in the specification.", "",
              "## Question", "", op["question"], "",
              "## Current entry", "", op["decision"], "",
              "## Affected requirements", ""]
        reqs = {r["id"]: r for g in mod["groups"] for r in g["reqs"]}
        md += [f"- `{i}` **{reqs[i]['level']}** {reqs[i]['text']}" for i in sorted(op["affects"]) if i in reqs]
        pack = "\n".join(md).rstrip() + "\n"
        task["pack_tokens"] = len(pack) // 4
        tasks.append(task)
        packs.append(pack)
    return tasks, packs


def build_task(mod, group, defined, phases, index):
    ids = {r["id"] for r in group["reqs"]}
    sec = mod["sections"]
    tid = f"T-{mod['module']}-{group['number']}"

    def rows_for(section_no):
        out = []
        for sub, header, sep, rows in tables(sec.get(section_no, [])):
            hit = [r for r in rows if ids_in(r, defined) & ids]
            if hit:
                out.append((sub, header, sep, hit))
        return out

    config = rows_for("5")
    verify = rows_for("7")
    referenced = sorted({m for r in group["reqs"] for m in re.findall(r"section (5\.\d+)", r["text"])})
    ref_text = [subsection_text(sec.get("5", []), n) for n in referenced]
    interfaces = [b for b in bullets(sec.get("6", [])) if ids_in(b, defined) & ids]
    constraints = [b for b in bullets(sec.get("8", [])) if ids_in(b, defined) & ids]

    decisions, blocked, op_header = [], [], None
    for op in open_points(mod, defined):
        hit = op["affects"] & ids
        if not hit:
            continue
        op_header = op["header"]
        if op["blocking"]:
            blocked.append({"open_point": op["no"], "question": op["question"],
                            "decision": op["decision"] or "open", "reqs": sorted(hit)})
        else:
            decisions.append(op["row"])
    blocked_reqs = sorted({r for b in blocked for r in b["reqs"]})

    levels = sorted({lv for _, _, _, rows in verify for r in rows
                     for lv in re.findall(r"`(build|manifest|rootfs|device)`", r)})

    task = {
        "id": tid,
        "module": mod["module"],
        "spec": mod["rel"],
        "spec_hash": mod["hash"],
        "group": group["number"],
        "title": f"{mod['title']} – {group['title']}",
        "phase": phases.get(mod["module"]),
        "risk": mod["risk"],
        "human_gate": mod["risk"] == "high",
        "depends_on_modules": mod["depends"],
        "reqs": [{"id": r["id"], "level": r["level"]} for r in group["reqs"]],
        "verify_levels": levels,
        "blocked_by": blocked,
        "blocked_reqs": blocked_reqs,
        "pack": f"agent/packs/{tid}.md",
        "status": "todo",
        "verified": {lv: "pending" for lv in levels},
        "evidence": [],
        "notes": "",
    }

    md = [f"# {tid} – {task['title']}", "",
          f"Module `{mod['module']}` · spec `{mod['rel']}` · risk `{mod['risk']}` · "
          f"human gate: **{'yes' if task['human_gate'] else 'no'}** · phase {task['phase']}",
          f"Depends on modules: {', '.join('`'+d+'`' for d in mod['depends']) or '—'}", "",
          "## Requirements", ""]
    md += [f"- {'**BLOCKED – do not implement:** ' if r['id'] in blocked_reqs else ''}`{r['id']}` **{r['level']}** {r['text']}"
           for r in group["reqs"]]

    comp = list(tables(sec.get("3", [])))
    if comp:
        md += ["", "## Components (module)", ""]
        for _, header, sep, rows in comp:
            md += [header, sep] + rows
    if config:
        md += ["", "## Configuration", ""]
        for sub, header, sep, rows in config:
            if sub:
                md += [f"*{sub}*", ""]
            md += [header, sep] + rows + [""]
    for t in ref_text:
        md += ["", "## Referenced section", "", t]
    if verify:
        md += ["", "## Verification", ""]
        for _, header, sep, rows in verify:
            md += [header, sep] + rows
    if interfaces:
        md += ["", "## Interfaces", ""] + interfaces
    if constraints:
        md += ["", "## Constraints", ""] + constraints
    if decisions:
        md += ["", "## Decisions", "", op_header[0], op_header[1]] + decisions
    if blocked:
        md += ["", "## Blockers", ""]
        md += [f"- Open point {b['open_point']} blocks {', '.join('`'+r+'`' for r in b['reqs'])}: "
               f"{b['question']} ({b['decision']})" for b in blocked]
    hints = repo_hints(mod, index)
    if hints:
        md += ["", "## Repo hints (existing files)", ""] + hints
    pack = "\n".join(md).rstrip() + "\n"
    task["pack_tokens"] = len(pack) // 4
    return task, pack


def merge(new_tasks, old):
    old_by_id = {t["id"]: t for t in old.get("tasks", [])}
    for t in new_tasks:
        o = old_by_id.pop(t["id"], None)
        if not o:
            continue
        for f in STATE_FIELDS:
            if f in o:
                t[f] = o[f]
        if [r["id"] for r in o.get("reqs", [])] != [r["id"] for r in t["reqs"]] or o.get("spec_hash") != t["spec_hash"]:
            t["needs_review"] = o.get("status") not in (None, "todo")
    for o in old_by_id.values():
        o["status"] = "obsolete"
        new_tasks.append(o)
    for t in new_tasks:
        fully_blocked = bool(t.get("reqs")) and set(t.get("blocked_reqs", [])) >= {r["id"] for r in t["reqs"]}
        if t["status"] == "todo" and fully_blocked:
            t["status"] = "blocked"
        if t["status"] == "blocked" and not fully_blocked:
            t["status"] = "todo"
    return new_tasks


def write_status(tasks, modules):
    by_mod = {}
    for t in tasks:
        by_mod.setdefault(t["module"], []).append(t)
    lines = ["# Implementation Status (basic stack)", "",
             "<!-- GENERATED by agent/tools/gen_tasks.py from agent/tasks/basic.json – do not edit. -->", "",
             f"Generated: {date.today().isoformat()}. Source of the state: `agent/tasks/basic.json`.", "",
             "| Phase | Module | Spec status | Tasks | Reqs | todo | in progress | implemented | verified | blocked | needs review |",
             "| :-: | :-- | :-- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |"]
    order = sorted(by_mod, key=lambda m: ((by_mod[m][0].get("phase") or 99), m))
    for m in order:
        ts = [t for t in by_mod[m] if t["status"] != "obsolete"]
        if not ts:            # module removed from the specifications
            continue
        c = {s: sum(1 for t in ts if t["status"] == s) for s in STATUSES}
        mod = modules.get(m, {})
        link = Path(mod.get("rel", "")).relative_to(SPEC_DIR.relative_to(ROOT)).as_posix() if mod.get("rel") else ""
        lines.append(f"| {ts[0].get('phase') if ts else '–'} | [`{m}`]({link}) | {mod.get('spec_status', '')} | {len(ts)} | "
                     f"{sum(len(t['reqs']) for t in ts)} | {c['todo']} | {c['in_progress']} | {c['implemented']} | "
                     f"{c['verified']} | {c['blocked']} | {sum(1 for t in ts if t.get('needs_review'))} |")
    blocked = [t for t in tasks if t.get("blocked_reqs") and t["status"] != "obsolete"]
    if blocked:
        lines += ["", "## Blocked Requirements", "",
                  "A task is `blocked` only if all its requirements are blocked; otherwise the blocked requirements are skipped.", "",
                  "| Task | Status | Blocked requirements | Open point |", "| :-- | :-- | :-- | :-- |"]
        for t in blocked:
            why = "; ".join(f"{b['open_point']}: {b['question']}" for b in t["blocked_by"])
            lines.append(f"| `{t['id']}` | {t['status']} | {', '.join(t['blocked_reqs'])} | {why} |")
    vtasks = [t for t in tasks if t["id"].startswith("V-") and t["status"] != "obsolete"]
    if vtasks:
        lines += ["", "## Verification Tasks (device / schematic)", "", "| Task | Status | Question |", "| :-- | :-- | :-- |"]
        lines += [f"| `{t['id']}` | {t['status']} | {t['title'][8:]} |" for t in vtasks]
    STATUS_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main():
    files = sorted(p for p in SPEC_DIR.rglob("*.md") if p.name not in SKIP)
    modules = {m["module"]: m for m in (parse_module(p) for p in files) if m["module"]}
    defined = {r["id"] for m in modules.values() for g in m["groups"] for r in g["reqs"]}
    phases = phase_map()
    index = repo_index()

    PACK_DIR.mkdir(parents=True, exist_ok=True)
    for old_pack in list(PACK_DIR.glob("T-*.md")) + list(PACK_DIR.glob("V-*.md")):
        old_pack.unlink()
    tasks = []
    for m in modules.values():
        for g in m["groups"]:
            t, pack = build_task(m, g, defined, phases, index)
            (ROOT / t["pack"]).write_text(pack, encoding="utf-8", newline="\n")
            tasks.append(t)
        for t, pack in zip(*build_verification_tasks(m, defined, phases)):
            (ROOT / t["pack"]).write_text(pack, encoding="utf-8", newline="\n")
            tasks.append(t)

    old = json.loads(TASKS_FILE.read_text(encoding="utf-8")) if TASKS_FILE.exists() else {}
    tasks = merge(tasks, old)
    def order(t):
        g = t["group"]
        num = [int(x) for x in g.split(".")] if not g.startswith("OP") else [99, int(g[2:])]
        return ((t.get("phase") or 99), t["module"], num)

    tasks.sort(key=order)
    TASKS_FILE.parent.mkdir(parents=True, exist_ok=True)
    TASKS_FILE.write_text(json.dumps({
        "generated_by": "agent/tools/gen_tasks.py",
        "spec_dir": SPEC_DIR.relative_to(ROOT).as_posix(),
        "statuses": list(STATUSES),
        "tasks": tasks,
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    write_status(tasks, {k: {"rel": v["rel"], "spec_status": v["spec_status"]} for k, v in modules.items()})

    sizes = sorted(t.get("pack_tokens", 0) for t in tasks if t["status"] != "obsolete")
    print(f"modules {len(modules)}, tasks {len(sizes)}, requirements {len(defined)}")
    print(f"pack tokens: min {sizes[0]}, median {sizes[len(sizes)//2]}, max {sizes[-1]}")
    print(f"blocked {sum(1 for t in tasks if t['status'] == 'blocked')}")


if __name__ == "__main__":
    main()
