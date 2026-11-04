# spec-kitty Workflow

spec-kitty is the spec-driven development tool used for significant feature work in this project. It drives an AI agent through a structured lifecycle — discovery → research → spec → plan → implement → review — and keeps the paper trail in the repo.

## When to use spec-kitty

Use it for:
- New features or capabilities (new auth, new template type, new user-facing workflow)
- Breaking changes to infrastructure or user flows
- Work that touches multiple files and needs a traceable decision record

Skip it for: bug fixes, typos, dependency bumps, config tweaks, one-line changes.

## Project structure

Two directories persist in the repo across all missions:

```
.kittify/                          # Project-level config (set up once, shared by all missions)
├── charter/charter.md             # Project governance, quality directives, stakeholder roles
├── config.yaml                    # spec-kitty project config
└── skills-manifest.json           # Registered agent skills

kitty-specs/                       # One subdirectory per completed mission (permanent record)
└── <mission-id>/
    ├── spec.md                    # Requirements document
    ├── research.md                # Research summary
    ├── research/                  # Evidence log + source register CSVs
    ├── data-model.md              # Entity model for the feature
    ├── plan.md                    # Approved implementation plan
    ├── wps.yaml                   # Work-package manifest (authoritative task source)
    ├── tasks.md / tasks/WP*.md    # Generated task files consumed by agents
    ├── checklists/requirements.md # Requirement-traceability checklist
    └── mission-events.jsonl       # Append-only audit log of all state transitions
```

## Starting a new mission

### 1. Create the feature scaffold

```bash
spec-kitty specify <feature-name>
# e.g.: spec-kitty specify workspace-quotas
```

This creates `kitty-specs/<mission-id>/` with the skeleton files and registers the mission.

### 2. Run the agent

From the repo root:

```bash
spec-kitty next --agent claude --mission <mission-id>
```

The agent reads the current mission state and returns the next action. Keep running this command as the agent works through each phase. The state machine progresses through:

```
not_started → discovery → specify → plan → tasks_outline → tasks_packages
           → tasks_finalize → implement → review → accept → done
```

**Important:** Always run `spec-kitty next` from the repo root, not from inside a worktree.

### 3. Implementation lanes

During implementation, spec-kitty creates git worktrees (`.worktrees/<mission>-lane-<x>`) for parallel work packages. Each lane is an isolated branch. Edits to owned files **must happen inside the correct worktree**, not in the main repo checkout. After implementation:

```bash
spec-kitty merge --mission <mission-id> --lane a   # merge lane-a into target branch
spec-kitty merge --mission <mission-id> --lane b   # merge lane-b, etc.
```

### 4. Review and accept

After all work packages are implemented and merged:

```bash
spec-kitty accept --mission <mission-id>
```

This validates completeness (all WPs done, all requirements traced) before the PR is opened.

## Key files to know

**`wps.yaml`** is the single source of truth for what needs to be built. It defines work packages, their dependencies, the files each WP owns, and the subtasks within each WP. The `finalize-tasks` step generates `tasks.md` and `lanes.json` from it. If you need to change scope, edit `wps.yaml` before finalize runs.

**`spec.md`** contains the requirements (FR-xxx, C-xxx, NFR-xxx). Every requirement should trace to a WP in `wps.yaml` and appear in `checklists/requirements.md`.

**`mission-events.jsonl`** is append-only. Never edit it directly — it's the audit log of every state transition. If spec-kitty rejects a `move-task` because the repo is dirty, commit any loose files first, then retry.

## Common pitfalls

- **Uncommitted files block transitions.** spec-kitty checks for a clean working tree before advancing state. Commit `mission-events.jsonl` and any other loose files before running `next` or `move-task`.
- **Git signing.** If the environment doesn't have an SSH signing agent, commits in external repos need `-c gpg.format=openpgp -c commit.gpgsign=false`.
- **`spec-kitty next` from the main repo.** Running it from inside a worktree fails with "must run from the main repository."
- **`--json` not supported everywhere.** The `implement` subcommand does not accept `--json`; drop the flag.

## Completed missions

| Mission ID | Title | PR |
|---|---|---|
| `github-org-gated-signup-01KR1P4G` | GitHub org-gated access for coder.ddev.com | #131 |
