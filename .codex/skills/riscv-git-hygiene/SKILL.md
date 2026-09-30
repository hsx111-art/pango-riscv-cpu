---
name: riscv-git-hygiene
description: Repository-local Git policy for the ultraembedded/riscv FPGA competition project. Use for status review, staging, commits, upstream synchronization, tags, releases, and generated-artifact hygiene.
---

# RISC-V Competition Git Hygiene

Use this skill whenever Git state, commits, remotes, tags, releases, or generated FPGA/simulation outputs are involved.

## Repository identity

1. Resolve the real Git root first:
   `git rev-parse --show-toplevel`
2. Record the upstream-derived baseline commit before changing remotes or history.
3. Keep `upstream` pointed at the original `ultraembedded/riscv` repository and use `origin` only for the competition repository.
4. Preserve the upstream commit lineage, `LICENSE`, copyright notices, and attribution.

## Status and review gate

Before staging or committing, run from the resolved root:

```text
git status --short --untracked-files=all
git diff --stat
git diff --cached --stat
git diff --check
```

Classify paths before acting:

- tracked RTL, software, tests, scripts, and documentation: keep visible and review;
- reproducible build/simulator output: ignore with `.gitignore`;
- operator-only machine files: use `.git/info/exclude`;
- credentials, tokens, cookies, GUI state, Codex state, and temporary archives: never stage;
- FPGA/PDS bitstreams, reports, and generated project trees: keep outside Git unless a small, intentional evidence artifact is explicitly required.

Do not use `git reset --hard`, `git checkout --`, `git clean -fd`, `skip-worktree`, or a revert merely to make Source Control look clean. Understand the path first and preserve user changes.

## Commit policy

Use one coherent topic per commit and Conventional Commit subjects:

- `fix:` for correctness or tool-compatibility fixes;
- `test:` for regression infrastructure and test coverage;
- `docs:` for architecture, verification, and handoff records;
- `feat:` for new project functionality;
- `perf:` only for measured performance work;
- `chore:` only for repository maintenance and configuration.

Examples:

```text
fix: update TCM SystemC harness for Verilator 5
test: add reproducible ModelSim TCM baseline regression
docs: document verified RV32IM TCM baseline
chore: establish competition repository hygiene
```

Before each commit:

```text
git add <scoped paths>
git diff --cached --check
git diff --cached --stat
git diff --cached --name-status --no-renames
```

Reject the commit if staged paths contain generated `work/`, `obj*`, `build/`, `verilated/`, `*.wlf`, `*.vcd`, temporary `.memh`, credentials, or local IDE/Codex state.

## Verification and tags

A version tag is allowed only after the exact candidate commit has evidence from both baseline commands:

```text
wsl.exe -d Ubuntu-A -- bash -lc "cd /mnt/a/ultraembedded-riscv && bash verification/wsl_baseline.sh"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\modelsim\run_tcm_baseline.ps1
```

Record the date, commit SHA, tool versions, image, PASS markers, and known limitations in `doc/verification/` before tagging.

Use annotated tags with a message containing:

- upstream commit;
- competition repository commit;
- RV32IM / Machine mode / MMU off / TCM configuration;
- WSL and ModelSim results;
- known limitations and unverified configurations.

Before pushing, audit the outgoing range rather than only the worktree:

```text
git diff --name-status upstream/master..HEAD
git log --oneline --decorate upstream/master..HEAD
git status --short --untracked-files=all
```

Never push a tag or branch containing unreviewed generated artifacts.

## Upstream synchronization

Do not rewrite or mass-move upstream RTL to make it look locally organized. Keep competition additions in `verification/`, `doc/`, `scripts/`, `fpga/`, or another explicit project-owned directory. When syncing upstream, fetch into `upstream`, inspect the incoming range, and merge/rebase only with a documented reason and a clean review boundary.

## FPGA/PDS evidence policy

For future on-board or synthesis evidence, record small text metadata under `doc/verification/`:

- PDS version;
- FPGA device and board;
- constraints revision;
- clock target and achieved frequency;
- timing summary;
- resource summary;
- bitstream hash;
- test image/hash and on-board evidence location.

Do not commit generated PDS project directories, bitstreams, or large reports by default. Store them in the team's artifact system and commit only a reproducible manifest or concise summary.
