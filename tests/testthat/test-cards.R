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

test_that("card ids round-trip through card_from_id and card_label", {
  ids <- c("AS", "2H", "9D", "10C", "JS", "QH", "KD")
  expect_equal(card_label(card_from_id(ids)), ids)

  # Every card in the deck survives a round trip, including the two-character
  # rank "10" that makes naive substr() parsing wrong.
  deck <- new_deck()
  expect_equal(card_label(card_from_id(card_label(deck))), card_label(deck))

  expect_equal(card_from_id("10D")$rank, 10L)
  expect_equal(card_from_id("AS")$rank, 1L)
  expect_equal(card_from_id("KH")$rank, 13L)
  expect_equal(card_from_id("KH")$suit, "H")
  expect_equal(nrow(card_from_id(character(0))), 0L)
})

test_that("unparseable card ids are an error, not a silent NA", {
  expect_error(card_from_id("1H"), "Unparseable")    # no such rank
  expect_error(card_from_id("5X"), "Unparseable")    # no such suit
  expect_error(card_from_id("11H"), "Unparseable")
  expect_error(card_from_id(""), "Unparseable")
  expect_error(card_from_id(c("5H", "ZZ")), "ZZ")
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
