# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

CribbageQuizzer is an **R Shiny web app** for drilling cribbage hand scoring. Scoring and deck logic
are implemented in `R/`; the **UI is still the stock RStudio Shiny template** — `CribbageQuizzer/app.R`
has empty `sidebarPanel`/`mainPanel` bodies and an empty `server` body, with the intended design
written out as comments. There are no automated tests yet.

## Layout

```
CribbageQuizzer/            <- project root (git repo, .Rproj) AND the Shiny app directory
├── CribbageQuizzer.Rproj
├── app.R                   <- single-file Shiny app (ui + server + shinyApp)
└── R/                      <- pure logic, no Shiny (unit-testable)
    ├── cards.R             <- deck, card representation, dealing
    └── scoring.R           <- score_hand() and its five component scorers
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

Run the full test suite (212 assertions across `test-scoring.R` and `test-cards.R`):

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'testthat::test_dir("tests/testthat")'
```

Single test file — `tests/testthat/helper-cribbage.R` sources `R/` and defines the `cd()`/`lay()`/
`total_of()` card-string shorthands, and testthat loads it for both commands:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'testthat::test_file("tests/testthat/test-scoring.R")'
```

## Architecture

The design intent is recorded as comments in `app.R` and is the best statement of where this is
headed:

- **Two modes**, switched from the sidebar: *Quiz Me* (build first) and *Calculate This* (deferred).
- **Quiz Me loop** in the main panel: display a cribbage hand as playing cards → button to deal a new
  random hand that also clears the answer field and feedback → numeric entry for the point total →
  check button that produces feedback saying whether the answer was right, and the correct total if not.
- **Server responsibilities**: deal a hand by sampling a 52-card deck without replacement, score it,
  compare against the user's entry, generate feedback.

Cribbage scoring is the part worth getting right, and it is pure logic — fifteens, pairs, runs,
flushes, and his nobs over a 4-card hand plus the starter card. **Keep scoring and deck/hand logic in
plain R functions under `R/`, entirely free of Shiny reactives**, so it can be unit-tested without
spinning up an app. Reactive code in `app.R` should call into those functions, not reimplement them.
`score_hand(hand, starter, is_crib = FALSE)` is the entry point, returning `total` plus a named
`breakdown` vector; `describe_score()` renders that as quiz feedback. Ranks are stored 1-13, not as
point values, because runs need the true ordering while J/Q/K are all worth 10.

Enumerating scoring combinations is combinatorial; prefer testing scoring against known hands with
hand-checked point totals over trusting a clever implementation. The scoring edge cases that catch
naive implementations: runs must count multiplicatively with pairs (e.g. a double run), a 4-card
flush in hand scores 4 but only counts 5 if the starter matches, and a 5-card flush is only possible
including the starter.
