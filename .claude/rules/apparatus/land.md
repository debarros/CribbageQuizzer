# Landing in cribbage (rendered by pjdtools.render v2 from pjdtools 0.13.0; do not edit by hand)

This repository lands through its hub's gate (`C:\Users\pjdeb\src\.hub\cribbage.git`). A session works in its own worktree under
`C:\Users\pjdeb\src\.wt\cribbage`, on its branch `wt/<name>`, never in the trunk `C:\Users\pjdeb\src\cribbage`, which only the gate moves.

1. Commit on `wt/<name>` in the worktree, the message written to a file with the Write tool and committed with
   `git commit -F <file>`.
2. Land with `git push origin HEAD:main` from the worktree. Never push with `-u`, never run `git update-ref`,
   `git checkout main` or `git branch -f main` aimed at main, and never write into the trunk or the hub.
3. The gate refuses the whole push, naming its rule, when: a hold stands on the repository; a ref other than
   main, `wt/<name>` or a `v<X.Y.Z>` tag is pushed, any ref is deleted, or an existing `v*` tag is moved; main
   would move by a non-fast-forward; a new commit's message holds a byte-order mark, a carriage return or a bare
   `<NAME>` placeholder line; a `v*` tag has no battery record in the journal; the trunk is dirty; main's
   `.pjd/uv.lock` names no release of the flat index, or main's own `uv.lock` names another pjdtools than that;
   or main's rendered files differ from a render from its pin. Report a refusal to PJ as it reads; never work
   around it.
4. A background session pushes no other branch and opens no pull request: landing is step 2, and only when its
   task says to land.
5. The rendered files (this rule, `.claude/settings.json`, the hooks folder's shims and the apparatus skills)
   change only through `pjd render`, run from the pinned environment when the pin moves (`pjd adopt`); never edit
   one by hand: the gate refuses a landing whose rendered files differ from a render from its pin.
