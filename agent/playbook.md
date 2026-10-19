# Agent Playbook (meta-modberry)

You implement **one task** of `agent/tasks/basic.json` per run. Your only specification is the task pack `agent/packs/<task>.md`. Read nothing else from `docs/software/` unless the pack tells you to.

## Rules

1. **Never edit** `docs/software/**`, `agent/playbook.md`, `agent/tools/**` or the packs. The specifications are the source of truth.
2. In `agent/tasks/basic.json` you change **only** `status`, `verified`, `evidence` and `notes` of **your** task.
3. Implement only the requirements of your pack. Skip requirements marked **BLOCKED**. Do not "improve" other modules.
4. If a requirement is unclear, contradicts the repository, or needs a decision: stop, set `status: "blocked"`, explain in `notes`. Do not guess.
5. If the task has **human gate: yes**: implement and verify up to `build`/`manifest`/`rootfs`, then stop with `status: "implemented"` and a note `human gate: device test required`. Never flash or reboot a device yourself.
6. No secrets in the repository: no passwords, keys, tokens. Use placeholders and the provisioning store (`/data/provisioning/`).
7. Yocto **kirkstone** syntax: `:append`, `:prepend`, `:remove`, `FILES:${PN}`, `RDEPENDS:${PN}`. Put configuration into its own recipe or `bbappend` of this layer; never modify other layers.
8. Every service you add follows `BASE-INIT-20` … `BASE-INIT-25` and `BASE-INIT-50` … `BASE-INIT-53` (systemd unit, `Restart=on-failure`, sandboxing).

## Workflow

0. Run `python3 agent/tools/gen_tasks.py` if `agent/packs/` is missing or older than the specs.
1. Pick a task with `status: "todo"` whose `depends_on_modules` are all `implemented` or `verified`, lowest `phase` first. Set it to `in_progress`.
2. Read the pack. Look at the files under *Repo hints*; search the layer (`grep -r`) for further related files.
3. Implement the requirements. Keep changes small and limited to this task.
4. Run every check of the pack's *Verification* table that you can run: `build`, `manifest`, `rootfs`. Record each result in `verified` (`ok` / `failed` / `pending`) and the command output summary in `evidence`.
5. Commit with the message `<task id>: <short summary>` and the requirement IDs in the body.
6. Set `status`:
   - `verified` – all checks of all levels are `ok` (including `device`, done by a human),
   - `implemented` – all non-device checks are `ok`, device checks `pending`,
   - `blocked` – see rule 4,
   - back to `todo` – if you could not finish; explain in `notes`.

## Definition of Done

All non-blocked MUST requirements of the task are implemented, all runnable checks are `ok`, the image still builds, and no other task's requirements were changed.

## Verification tasks (`V-…`)

They need a measurement on the device or a look into the schematic. Collect the facts, write them into `notes` and `evidence`, set `status: "implemented"`. A human decides the open point in the specification.
