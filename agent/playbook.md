# Agent Playbook (meta-modberry)

You implement **one task** of `agent/tasks/basic.json` per run. Your only specification is the task pack `agent/packs/<task>.md`. Read nothing else from `docs/software/` unless the pack tells you to.

The runner (`agent-system`, separate repository) selects the task, gives you the pack, commits your change and writes the task state from your report. You never edit `agent/tasks/basic.json` yourself.

## Rules

1. **Never edit** `docs/**`, `agent/**` or files outside the write area (recipes, `conf/`, `classes/`, `wic/`, `files/`). The specifications are the source of truth.
2. Implement only the requirements of your pack. Skip requirements marked **BLOCKED**. Do not "improve" other modules.
3. If a requirement is unclear, contradicts the repository, or needs a decision: stop and report `status: "blocked"` with the reason in `notes`. Do not guess.
4. If the task has **human gate: yes**: implement and verify up to `build`/`manifest`/`rootfs`, then report `status: "implemented"`. Never flash or reboot a device.
5. No secrets in the repository: no passwords, keys, tokens. Use placeholders and the provisioning store (`/data/provisioning/`).
6. Yocto **kirkstone** syntax: `:append`, `:prepend`, `:remove`, `FILES:${PN}`, `RDEPENDS:${PN}`. Put configuration into its own recipe or `bbappend` of this layer; never modify other layers.
7. Every service you add follows `BASE-INIT-20` … `BASE-INIT-25` and `BASE-INIT-50` … `BASE-INIT-53` (systemd unit, `Restart=on-failure`, sandboxing).

## Workflow

1. Read the pack. Look at the files under *Repo hints*; search the layer (`grep`) for further related files.
2. Implement the requirements. Keep changes small and limited to this task.
3. Run every check of the pack's *Verification* table that you can run: `build`, `manifest`, `rootfs`.
4. Report (`TaskReport`):
   - `status`: `implemented` – all non-device checks are `ok`; `blocked` – see rule 3; `todo` – not finished, reason in `notes`,
   - `summary`: one line (commit subject),
   - `changed_files`: every file you wrote,
   - `verified`: per level `ok` / `failed` / `pending`,
   - `evidence`: short command results that prove the checks.

## Definition of Done

All non-blocked MUST requirements of the task are implemented, all runnable checks are `ok`, the image still builds, and no other task's requirements were changed.

## Verification tasks (`V-…`)

They need a measurement on the device or a look into the schematic and are done by a human, not by the agents. The result goes into `notes` and `evidence`; a human decides the open point in the specification.
