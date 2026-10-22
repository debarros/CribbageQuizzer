# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

CribbageQuizzer is an **R Shiny web app** for drilling cribbage hand scoring. Both modes are built:
*Quiz Me* deals a random layout and checks the user's answer; *Calculate This* lets the user build a
specific layout from a card picker and shows its score. *My Stats* shows the user's Quiz Me record,
which is kept in their browser's `localStorage` (no accounts, nothing stored server-side). Scoring,
deck and stats logic live in `R/` and are covered by the test suite.

## Layout

```
CribbageQuizzer/            <- project root (git repo, .Rproj) AND the Shiny app directory
├── CribbageQuizzer.Rproj
├── app.R                   <- single-file Shiny app: view layer only (ui + server + shinyApp)
├── R/                      <- pure logic, no Shiny (unit-testable)
│   ├── cards.R             <- deck, card ids/names, dealing, layout validation
│   ├── scoring.R           <- score_hand() and its five component scorers
│   └── stats.R             <- quiz performance record: recording, JSON round trip, summary
└── tests/testthat/
    ├── helper-cribbage.R   <- sources R/, defines cd()/lay()/total_of() shorthands
    ├── test-scoring.R      <- scoring rules against hand-checked totals
    ├── test-stats.R        <- stats recording and repairing tampered localStorage data
    ├── test-cards.R        <- deck, card ids, dealing, validation
    ├── test-calculate-this.R <- Calculate This state machine, via shiny::testServer
    ├── test-quiz.R         <- Quiz Me answer checking, via shiny::testServer
    └── test-accessibility.R  <- renders the UI and asserts its accessible structure
```

`app.R` sits next to `R/` deliberately: Shiny auto-sources every `.R` file in an `R/` directory
adjacent to `app.R` before evaluating it (the `shiny.autoload.r` option, TRUE by default), so
`app.R` must NOT call `source()` on those files. Verified working on shiny 1.14.0.

## Environment

R 4.5.2 is installed at `C:\Program Files\R\R-4.5.2` but is **not on PATH**. Invoke it by full path,
or add `C:\Program Files\R\R-4.5.2\bin` to PATH first.

Installed: `shiny` 1.14.0, `bslib` 0.12.0, `testthat` 3.3.2. **Not installed:** `shinytest2`, `renv`.
Install what a task needs rather than assuming it loads. There is no lockfile or dependency manifest —
dependencies are whatever the user library happens to contain.

## Commands

Run the app:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'shiny::runApp(".", port = 3838, launch.browser = FALSE)'
```

`runApp()` blocks. Run it in the background from a tool call and stop it when done rather than
waiting on it.

Syntax-check the app without launching a server — the fastest feedback loop while editing:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'invisible(parse("app.R"))'
```

Run the full test suite:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'testthat::test_dir("tests/testthat")'
```

Single test file:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'testthat::test_file("tests/testthat/test-scoring.R")'
```

**Prefer `shiny::testServer` over driving a browser.** It exercises the real server function with no
browser at all, so reactive behaviour can be tested deterministically — see `test-calculate-this.R`.
Reserve browser work for things only a browser can answer (focus, layout, touch targets).

## Architecture

**Keep scoring and deck/hand logic in plain R functions under `R/`, entirely free of Shiny**, so it
can be unit-tested without spinning up an app. `app.R` is the view layer: it renders and calls into
those functions, and must not reimplement scoring rules.

`score_hand(hand, starter, is_crib = FALSE)` is the entry point, returning `total` plus a named
`breakdown` vector; `describe_score()` renders that as quiz feedback. Ranks are stored 1-13, not as
point values, because runs need the true ordering while J/Q/K are all worth 10. `card_label()` and
`card_from_id()` convert between a card row and its compact id ("5H", "10D"); `card_name()` gives the
spoken form ("Five of Hearts") used for accessible labels.

Enumerating scoring combinations is combinatorial; prefer testing scoring against known hands with
hand-checked point totals over trusting a clever implementation. The edge cases that catch naive
implementations: runs count multiplicatively with duplicated ranks (a double run), a 4-card flush in
hand scores 4 but only 5 if the starter matches, a 5-card flush needs the starter, aces are low so
K-A-2 is not a run, and a jack as *starter* is his heels rather than nobs.

Quiz stats are a JSON record in the browser's `localStorage`. On connect the browser sends it once as
`input$stored_stats` (an empty string when absent or blocked); the server keeps the live copy and
sends the whole record back through the `cq_stats_save` message after every change. Nothing is saved
until that load arrives, so an empty in-memory record can't overwrite a real one. `stats_from_json()`
treats stored data as untrusted and repairs or discards it — users can edit `localStorage`, and a
format change needs a new `STATS_VERSION`. Only the first answer to each dealt hand is recorded.

## Things that will silently break if you "simplify" them

Each of these was a real bug, and each looks like pointless complexity until it regresses.

- **The picker is static UI, not a `renderUI` output.** Its chosen state is toggled in place via the
  `cq_selection` custom message. Re-rendering it destroys the element a keyboard user is focused on
  and throws focus to the top of the page after every pick.
- **Clickable cards are real `<button>` elements.** A styled `div` with a click handler looks
  identical and is unreachable by keyboard. Unavailable cards are `aria-disabled` but stay focusable,
  so arrow navigation does not skip them silently.
- **Enter in the answer field fires a `change` event before clicking Check.** Shiny debounces
  keystrokes 250ms, so a plain click would score the *previous* answer — which is every
  type-then-Enter.
- **Removing a chosen card ignores the follow-up clicks of a double-click.** The slot row compacts
  faster than the double-click interval, so the second click lands on a different card.
- **Calculate This outputs set `suspendWhenHidden = FALSE`.** Outputs starting inside a hidden
  `conditionalPanel` are suspended, and the notice that they became visible does not reliably arrive,
  leaving the panel permanently blank on first switch.
- **The pick observer checks `is.character(id) && length(id) == 1` first.** A vector reaching the
  `%in%` tests throws "the condition has length > 1", and Shiny answers an unhandled observer error
  by closing the session.
- **Answers are compared without `as.integer()`.** Truncating scored 7.9 as a correct 7.
- **`.cq-btn` must not declare `color`.** It sits after `.cq-red`/`.cq-black` at equal specificity,
  so a `color: inherit` there wins and renders every red suit black — on the picker and chosen cards
  only, which is why it survives a glance at Quiz Me.
- **Text colours are checked against a 4.5:1 contrast floor by the test suite.** `#5b6670` passes at
  5.87:1; the `#7b8794` it replaced was 3.66:1.
- **`.form-control` is pinned to 16px.** Under 16px, iOS Safari zooms the viewport when the answer
  field takes focus. Fixing it with `maximum-scale`/`user-scalable=no` would fail WCAG 1.4.4.
