# Quiz Me answer checking, driven through the real server function.

app_dir <- normalizePath(file.path("..", ".."), mustWork = TRUE)

# The dealt hand is random, so read the true total out of the layout rather
# than assuming one.
true_total <- function(layout) score_hand(layout$hand, layout$starter)$total

test_that("an exact answer is accepted and a wrong one is not", {
  shiny::testServer(app_dir, {
    session$setInputs(guess = true_total(layout()), check = 1)
    expect_equal(feedback()$status, "correct")

    session$setInputs(guess = true_total(layout()) + 1, check = 2)
    expect_equal(feedback()$status, "wrong")
  })
})

test_that("a fractional guess is not truncated into a correct answer", {
  # as.integer(7.9) is 7, which would have marked 7.9 correct for a 7 hand.
  shiny::testServer(app_dir, {
    session$setInputs(guess = true_total(layout()) + 0.9, check = 1)
    expect_equal(feedback()$status, "prompt")
    expect_match(feedback()$text, "whole number")

    session$setInputs(guess = true_total(layout()) - 0.1, check = 2)
    expect_equal(feedback()$status, "prompt")
  })
})

test_that("an empty answer asks for a total instead of scoring", {
  shiny::testServer(app_dir, {
    session$setInputs(guess = NA_integer_, check = 1)
    expect_equal(feedback()$status, "prompt")
    expect_match(feedback()$text, "point total first")
  })
})

test_that("dealing a new hand clears the feedback", {
  shiny::testServer(app_dir, {
    session$setInputs(guess = true_total(layout()), check = 1)
    expect_equal(feedback()$status, "correct")
    session$setInputs(deal = 1)
    expect_null(feedback())
  })
})

test_that("dealing replaces the layout with a legal one", {
  shiny::testServer(app_dir, {
    for (i in 1:20) {
      session$setInputs(deal = i)
      l <- layout()
      expect_equal(nrow(l$hand), 4L)
      expect_equal(nrow(l$starter), 1L)
      all_cards <- rbind(l$hand, l$starter)
      expect_equal(anyDuplicated(paste(all_cards$rank, all_cards$suit)), 0L)
    }
  })
})

# ---- Stats ----------------------------------------------------------------

test_that("only the first answer to a hand is recorded", {
  # Otherwise a wrong answer followed by the total shown in the feedback would
  # count as a success.
  shiny::testServer(app_dir, {
    session$setInputs(stored_stats = "")
    session$setInputs(guess = true_total(layout()) + 1, check = 1)
    session$setInputs(guess = true_total(layout()), check = 2)
    expect_equal(stats()$answered, 1L)
    expect_equal(stats()$correct, 0L)

    session$setInputs(deal = 1)
    session$setInputs(guess = true_total(layout()), check = 3)
    expect_equal(stats()$answered, 2L)
    expect_equal(stats()$correct, 1L)
  })
})

test_that("prompts for a valid answer are not recorded", {
  shiny::testServer(app_dir, {
    session$setInputs(stored_stats = "")
    session$setInputs(guess = NA_integer_, check = 1)
    session$setInputs(guess = true_total(layout()) + 0.5, check = 2)
    expect_equal(stats()$answered, 0L)
    # ...and the hand can still be answered for the record.
    session$setInputs(guess = true_total(layout()), check = 3)
    expect_equal(stats()$correct, 1L)
  })
})

test_that("stored stats are loaded once, and new answers build on them", {
  saved <- empty_stats()
  saved$answered <- 10L
  saved$correct <- 7L
  shiny::testServer(app_dir, {
    session$setInputs(stored_stats = stats_to_json(saved))
    expect_equal(stats()$answered, 10L)

    session$setInputs(guess = true_total(layout()), check = 1)
    expect_equal(c(stats()$answered, stats()$correct), c(11L, 8L))

    # A second load (e.g. a reconnect) must not roll the record back.
    session$setInputs(stored_stats = stats_to_json(saved))
    expect_equal(stats()$answered, 11L)
  })
})

test_that("corrupt or hostile stored stats do not break the session", {
  shiny::testServer(app_dir, {
    session$setInputs(stored_stats = list(a = 1, b = "x"))
    expect_identical(stats(), empty_stats())
    session$setInputs(guess = true_total(layout()), check = 1)
    expect_equal(stats()$correct, 1L)
  })
})

test_that("resetting needs confirmation", {
  shiny::testServer(app_dir, {
    session$setInputs(stored_stats = "")
    session$setInputs(guess = true_total(layout()), check = 1)
    session$setInputs(reset_stats = 1)
    expect_equal(stats()$answered, 1L)
    session$setInputs(confirm_reset_stats = 1)
    expect_identical(stats(), empty_stats())
  })
})

test_that("the stats page renders for an empty and a busy record", {
  shiny::testServer(app_dir, {
    session$setInputs(stored_stats = "")
    expect_match(output$stats_display$html, "No answers yet")
    session$setInputs(guess = true_total(layout()) + 1, check = 1)
    html <- output$stats_display$html
    expect_match(html, "hand answered", fixed = TRUE)
    expect_match(html, "you missed", fixed = TRUE)
    expect_match(html, "<caption>", fixed = TRUE)
  })
})
