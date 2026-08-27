# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

CribbageQuizzer is an **R Shiny web app** for drilling cribbage hand scoring. It is at the skeleton
stage: `CribbageQuizzer/app.R` is the stock RStudio Shiny template with the intended design written
out as comments. **No cribbage logic, no UI inputs, and no tests exist yet** — the `ui` has empty
`sidebarPanel`/`mainPanel` bodies and `server` has an empty function body.

## Layout

The app lives in a **nested subdirectory**, not the project root:

```
CribbageQuizzer/            <- project root (git repo, .Rproj)
├── CribbageQuizzer.Rproj
└── CribbageQuizzer/
    └── app.R               <- single-file Shiny app (ui + server + shinyApp)
```

Paths in commands below are relative to the project root, so the app directory is `CribbageQuizzer`.

## Environment

R 4.5.2 is installed at `C:\Program Files\R\R-4.5.2` but is **not on PATH**. Invoke it by full path,
or add `C:\Program Files\R\R-4.5.2\bin` to PATH first.

Installed: `shiny` 1.14.0, `bslib` 0.12.0. **Not installed:** `testthat`, `shinytest2`, `renv`.
Install what a task needs rather than assuming it loads. There is no lockfile or dependency manifest —
dependencies are whatever the user library happens to contain.

## Commands

Run the app:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'shiny::runApp("CribbageQuizzer", port = 3838, launch.browser = FALSE)'
```

`runApp()` blocks. Run it in the background from a tool call and stop it when done rather than
waiting on it.

Syntax-check the app without launching a server — the fastest feedback loop while editing:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'invisible(parse("CribbageQuizzer/app.R"))'
```

Testing is not set up yet. Once `R/` and `tests/testthat/` exist, install `testthat` first
(`install.packages("testthat")`), then:

```bash
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e 'testthat::test_dir("tests/testthat")'
```

Single test file:

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
A single-file `app.R` does not auto-source `R/`; add explicit `source()` calls (or restructure into a
`ui.R`/`server.R`/`global.R` app) when that directory appears.

Enumerating scoring combinations is combinatorial; prefer testing scoring against known hands with
hand-checked point totals over trusting a clever implementation. The scoring edge cases that catch
naive implementations: runs must count multiplicatively with pairs (e.g. a double run), a 4-card
flush in hand scores 4 but only counts 5 if the starter matches, and a 5-card flush is only possible
including the starter.
