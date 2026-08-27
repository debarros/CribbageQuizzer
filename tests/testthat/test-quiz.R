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
