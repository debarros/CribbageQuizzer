test_that("a new deck is 52 distinct cards", {
  deck <- new_deck()
  expect_equal(nrow(deck), 52L)
  expect_equal(anyDuplicated(paste(deck$rank, deck$suit)), 0L)
  expect_equal(sort(unique(deck$rank)), 1:13)
  expect_setequal(unique(deck$suit), SUITS)
})

test_that("card values cap face cards at ten", {
  expect_equal(card_value(1L), 1L)    # ace is low
  expect_equal(card_value(10L), 10L)
  expect_equal(card_value(11L), 10L)  # jack
  expect_equal(card_value(13L), 10L)  # king
  expect_equal(card_value(c(1L, 5L, 12L)), c(1L, 5L, 10L))
})

test_that("card labels render ranks and suits", {
  expect_equal(card_label(cd(c("AS", "10D", "KH"))), c("AS", "10D", "KH"))
  expect_equal(card_label(cd("AS"), symbols = TRUE), "A♠")
})

test_that("dealing draws five distinct cards without replacement", {
  set.seed(99)
  for (i in seq_len(50L)) {
    d <- deal_hand()
    expect_equal(nrow(d$hand), 4L)
    expect_equal(nrow(d$starter), 1L)
    all_cards <- rbind(d$hand, d$starter)
    expect_equal(anyDuplicated(paste(all_cards$rank, all_cards$suit)), 0L)
  }
})

test_that("invalid layouts are rejected", {
  four <- cd(c("5H", "6D", "7C", "8S"))
  starter <- cd("9H")

  expect_error(score_hand(four[1:3, ], starter), "exactly 4 cards")
  expect_error(score_hand(four, rbind(starter, cd("2C"))), "exactly 1 card")

  duplicated_card <- cd(c("5H", "5H", "7C", "8S"))
  expect_error(score_hand(duplicated_card, starter), "cannot appear twice")

  bad_rank <- four; bad_rank$rank[1] <- 14L
  expect_error(score_hand(bad_rank, starter), "ranks must be")

  bad_suit <- four; bad_suit$suit[1] <- "X"
  expect_error(score_hand(bad_suit, starter), "suits must be")
})
