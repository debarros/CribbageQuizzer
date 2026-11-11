---
name: cribbage-pin-plan
description: "Where plan cribbage/pin (the Documents clone's next-to-last plan, cribbage/catch-up being its last: .gitattributes with * -text, the .pjd pin to pjdtools 0.13.0, its environment, the rendered project files and this committed store) and its records live, its Decisions 359 to 362, and what its planning measured: * -text makes five files read as modified until git read-tree HEAD and then git checkout-index -f -a have run, the guards now run a pinned wheel whose absence denies every Bash call, pjd adopt cannot make a first pin, and the adapter's battery exits 2 until the cutover makes the trunk"
metadata:
  type: project
---

The plan is `~/.claude/plans/pasted-content-id-bab3-plan-cribbage-pi-humble-kite.md` (the mailbox copy); its run
folder is `C:/Users/pjdeb/src/.runs/cribbage/pin/` (`x/`: the plan's copy, the readings, the messages, the replay's
page, the progress, `stops.md` with PJ's replies at any stop); its records in the tree are `ops/plans/pin/closeout.md`
and `ops/plans/pin/evidence/`. PJ answered Decisions 359 to 362 on 2026-11-10 in the planning session's question
dialog, each by selecting the drafted label of the recommended option (the case that Decision 199C's quote check
flags): 359A, the adapter `.pjd/project.toml` carries a `[commands] battery` naming `pjd replay` with the default
released side; 360A, no `[permissions] allow` yet, since this repository had no standing allow rules to carry and
`machine/cribbage-hub` has the first worktree session measure the prompts first; 361A, this store with one note and
the import in `CLAUDE.md`; 362A, no `TASKS.md`, the close-out being the closure of the wait `cribbage:Q_pin`. Their
records are the machine repository's `ops/decisions/D0359.md` to `D0362.md`.

**Why:** Phase 3 of the machine transition (`C:/Users/pjdeb/src/machine/ORDER-OF-WORK.md`). `cribbage/catch-up`
(Decision 403A) followed it as the last plan executed in `C:/Users/pjdeb/Documents/CribbageQuizzer`: it merged
GitHub's `main`, which held the pull requests merged there on 2026-10-22 that the clone lacked, and named the clone in
the adapter's battery with `--also`; its records are `ops/plans/catch-up/closeout.md` and
`ops/plans/catch-up/evidence/`. `machine/cribbage-hub` (Decision 401C) waits on `cribbage:Q_catch-up`, which that
close-out closes, and then makes the hub `C:/Users/pjdeb/src/.hub/cribbage.git` and the trunk
`C:/Users/pjdeb/src/cribbage`.

**What its planning measured** (2026-11-10, rehearsed in a throwaway clone and a stand-in layout root):

- `core.autocrlf` is true and every blob in the index is LF, so `* -text` makes the five files whose working-tree
  bytes are not the index's (`.gitignore`, `CribbageQuizzer.Rproj`, `app.R`, the `rsconnect` `.dcf` and
  `tests/testthat/test-quiz.R`) read as modified. The repair is `git read-tree HEAD` and then
  `git checkout-index -f -a`, which rewrites the working tree from the index and changes no blob;
  `git add --renormalize .` does the opposite and commits CRLF. Found at execution (2026-11-10): in this clone
  git's cached size and mtime still matched the disk, so `git status` listed nothing and `git checkout-index -f -a`
  alone rewrote nothing; `git read-tree HEAD` drops that cache.
  The R suite passes on the all-LF tree.
- The guards of every session here now run `C:/Users/pjdeb/src/.envs/cribbage/<lockhash12>/Scripts/python.exe`, and
  the PreToolUse entries carry `onFailure: "block"`, so a missing or broken environment denies every Bash and
  PowerShell call. It is rebuilt from a terminal with
  `python -I -m pjdtools.env build cribbage --project <the checkout>/.pjd`; the rendered `.githooks/commit-msg`,
  which runs from the cutover on, prints it without `--project`, which builds from the trunk's `.pjd`.
- `pjd adopt` cannot make a first pin (its own docstring says so, and it refuses an unconverted repository and a tree
  outside `src/.wt/<repo>/`), so the pin is written by the plan's own steps: `.pjd/pyproject.toml`,
  `uv lock --offline`, `pjdtools.env build` from the global interpreter, then `pjd render` from the new environment.
  `pjd render` needs `--tree` here, since the default tree must be the trunk or a worktree.
- `pjd replay` is this repository's proof, and `--released` must be named while there is no trunk: its default is the
  environment that the trunk's `.pjd/uv.lock` names. The replay of every call these transcripts hold, released
  0.11.0 against candidate 0.13.0, read `SAME`. The adapter's battery leaves `--released` out, which is right from
  the first adoption after the cutover and exits 2 before it.
- A change to this repository's row of the machine's `repos.toml`, to whether `ops/memory/MEMORY.md` exists, or to
  `.pjd/project.toml`'s `[permissions] allow`, changes the render (Decision 325A). `machine/cribbage-hub` flips
  `converted` to true, which rewrites the land rule and the skill, so the first commit that lands through cribbage's
  hub must carry a fresh render or the gate's rule 8 refuses the push.
- Until `machine/static-layer`, a session here runs the rendered hooks and the user-level ones both; their command
  texts differ, so the harness does not deduplicate them. The commit-msg route still comes from
  `~/.gitconfig-pjdtools-hooks`, so the `.githooks/commit-msg` rendered here is unused until the cutover.
