# Drives the real server function through shiny::testServer -- no browser, so
# the selection state machine is checked deterministically. The app directory
# is two levels up from tests/testthat.

app_dir <- normalizePath(file.path("..", ".."), mustWork = TRUE)

# Convenience: click a run of picker cards in order.
pick_all <- function(session, ids) {
  for (id in ids) session$setInputs(pick_card = id)
}

test_that("the first card picked is the starter and order is preserved", {
  shiny::testServer(app_dir, {
    pick_all(session, c("5S", "JS", "5H", "5D", "5C"))
    expect_equal(selected(), c("5S", "JS", "5H", "5D", "5C"))
  })
})

test_that("a sixth card is refused", {
  shiny::testServer(app_dir, {
    pick_all(session, c("5S", "JS", "5H", "5D", "5C"))
    session$setInputs(pick_card = "2H")
    expect_length(selected(), 5L)
    expect_false("2H" %in% selected())
  })
})

test_that("picking an already-selected card is a no-op", {
  shiny::testServer(app_dir, {
    pick_all(session, c("5S", "JS"))
    session$setInputs(pick_card = "5S")
    expect_equal(selected(), c("5S", "JS"))
  })
})

test_that("a card id that is not in the deck is ignored, not an error", {
  shiny::testServer(app_dir, {
    pick_all(session, c("5S", "JS"))
    # Reachable from the browser console, so the server must not trust it.
    session$setInputs(pick_card = "ZZ")
    session$setInputs(pick_card = "1H")
    session$setInputs(pick_card = "")
    expect_equal(selected(), c("5S", "JS"))
  })
})

test_that("removing the starter promotes the next card into that role", {
  shiny::testServer(app_dir, {
    pick_all(session, c("5S", "JS", "5H", "5D", "5C"))
    session$setInputs(remove_card = "5S")
    expect_equal(selected(), c("JS", "5H", "5D", "5C"))

    # And the promotion really reaches the scoring engine: with the jack now
    # the starter rather than in hand, his nobs no longer counts.
    session$setInputs(pick_card = "5S")
    cards <- card_from_id(selected())
    expect_equal(score_hand(cards[2:5, ], cards[1, ])$total, 28L)
  })
})

test_that("removing a middle card closes the gap without reordering", {
  shiny::testServer(app_dir, {
    pick_all(session, c("AS", "2H", "3D"))
    session$setInputs(remove_card = "2H")
    expect_equal(selected(), c("AS", "3D"))
    session$setInputs(pick_card = "4C")
    expect_equal(selected(), c("AS", "3D", "4C"))
  })
})

test_that("removing a card that was never selected changes nothing", {
  shiny::testServer(app_dir, {
    pick_all(session, c("AS", "2H"))
    session$setInputs(remove_card = "9D")
    expect_equal(selected(), c("AS", "2H"))
  })
})

test_that("a removed card can be picked again", {
  shiny::testServer(app_dir, {
    pick_all(session, c("AS", "2H"))
    session$setInputs(remove_card = "AS")
    session$setInputs(pick_card = "AS")
    expect_equal(selected(), c("2H", "AS"))
  })
})

test_that("clear resets the selection", {
  shiny::testServer(app_dir, {
    pick_all(session, c("5S", "JS", "5H"))
    session$setInputs(clear_selection = 1)
    expect_equal(selected(), character(0))
  })
})

test_that("the score appears only once five cards are selected", {
  shiny::testServer(app_dir, {
    expect_null(output$calc_score)

    pick_all(session, c("5S", "JS", "5H", "5D"))
    expect_null(output$calc_score)

    session$setInputs(pick_card = "5C")
    expect_true(grepl("29", output$calc_score$html, fixed = TRUE))

    # Dropping back below five withdraws the score again.
    session$setInputs(remove_card = "5C")
    expect_null(output$calc_score)
  })
})

test_that("switching modes does not disturb the selection", {
  shiny::testServer(app_dir, {
    session$setInputs(mode = "calc")
    pick_all(session, c("7H", "8S", "9D"))
    session$setInputs(mode = "quiz")
    expect_equal(selected(), c("7H", "8S", "9D"))
    session$setInputs(mode = "calc")
    expect_equal(selected(), c("7H", "8S", "9D"))
  })
})

test_that("dealing a new quiz hand leaves the built layout alone", {
  shiny::testServer(app_dir, {
    pick_all(session, c("7H", "8S", "9D"))
    session$setInputs(deal = 1)
    session$setInputs(deal = 2)
    expect_equal(selected(), c("7H", "8S", "9D"))
  })
})

test_that("a malformed pick_card value is ignored rather than killing the session", {
  # These are only reachable from the browser console, but an unhandled error
  # in an observer makes Shiny close the session and lose the selection.
  shiny::testServer(app_dir, {
    pick_all(session, c("AS", "2H"))
    session$setInputs(pick_card = c("3S", "4S"))   # vector: would throw on if()
    session$setInputs(pick_card = character(0))
    session$setInputs(pick_card = 5)
    session$setInputs(pick_card = TRUE)
    expect_equal(selected(), c("AS", "2H"))

    # A well-formed id still works afterwards.
    session$setInputs(pick_card = "3S")
    expect_equal(selected(), c("AS", "2H", "3S"))
  })
})
