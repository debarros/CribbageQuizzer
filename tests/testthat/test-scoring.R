# Scoring is combinatorial and easy to get subtly wrong, so these tests check
# hand-verified point totals rather than re-deriving the answer in code.

test_that("fifteens count subsets, not cards", {
  # Three 5s and a jack: each 5 with the jack, plus the three 5s together.
  expect_equal(score_fifteens(c(5L, 5L, 5L, 10L, 2L)), 8L)
  # Only {10,5} and {10,2,3} reach fifteen here.
  expect_equal(score_fifteens(c(10L, 5L, 2L, 3L, 4L)), 4L)
  expect_equal(score_fifteens(c(2L, 4L, 6L, 8L, 10L)), 0L)
})

test_that("pairs count every two-card combination", {
  expect_equal(score_pairs(c(3L, 3L, 7L, 9L, 12L)), 2L)   # one pair
  expect_equal(score_pairs(c(3L, 3L, 3L, 9L, 12L)), 6L)   # three of a kind
  expect_equal(score_pairs(c(3L, 3L, 3L, 3L, 12L)), 12L)  # four of a kind
  expect_equal(score_pairs(c(3L, 3L, 7L, 7L, 12L)), 4L)   # two separate pairs
  expect_equal(score_pairs(c(1L, 4L, 7L, 9L, 12L)), 0L)
})

test_that("runs are maximal and multiply on duplicates", {
  expect_equal(score_runs(c(3L, 4L, 5L, 9L, 12L)), 3L)   # plain run of three
  expect_equal(score_runs(c(3L, 4L, 5L, 6L, 12L)), 4L)   # run of four, not two of three
  expect_equal(score_runs(c(3L, 4L, 5L, 6L, 7L)), 5L)    # run of five
  expect_equal(score_runs(c(3L, 4L, 4L, 5L, 12L)), 6L)   # double run
  expect_equal(score_runs(c(3L, 4L, 4L, 5L, 5L)), 12L)   # double double run
  expect_equal(score_runs(c(3L, 4L, 4L, 4L, 5L)), 9L)    # triple run
  expect_equal(score_runs(c(3L, 5L, 7L, 9L, 12L)), 0L)   # nothing consecutive
  expect_equal(score_runs(c(3L, 4L, 12L, 13L, 1L)), 0L)  # a pair of twos is not a run
})

test_that("aces are low and runs do not wrap around", {
  expect_equal(score_runs(c(1L, 2L, 3L, 9L, 12L)), 3L)    # A-2-3 is a run
  expect_equal(score_runs(c(12L, 13L, 1L, 5L, 8L)), 0L)   # Q-K-A is not
  expect_equal(score_runs(c(13L, 1L, 2L, 5L, 8L)), 0L)    # K-A-2 is not
  expect_equal(score_runs(c(11L, 12L, 13L, 5L, 8L)), 3L)  # J-Q-K is
})

test_that("flush needs all four hand cards, and the starter only extends it", {
  expect_equal(score_flush(c("H", "H", "H", "H"), "H"), 5L)
  expect_equal(score_flush(c("H", "H", "H", "H"), "S"), 4L)
  expect_equal(score_flush(c("H", "H", "H", "S"), "H"), 0L)  # 3 + starter is nothing
  # In the crib nothing short of all five counts.
  expect_equal(score_flush(c("H", "H", "H", "H"), "S", is_crib = TRUE), 0L)
  expect_equal(score_flush(c("H", "H", "H", "H"), "H", is_crib = TRUE), 5L)
})

test_that("his nobs needs a jack in hand matching the starter's suit", {
  expect_equal(total_of("JS", "QH", "KD", "3C", "4S"), 4L)  # run of 3 plus nobs
  expect_equal(total_of("JS", "QH", "KD", "3C", "4H"), 3L)  # same run, suit misses
  # A jack as the STARTER is his heels, scored at cut time, not counted here.
  expect_equal(total_of("5S", "5H", "5D", "5C", "JS"), 28L)
})

test_that("classic full hands score correctly", {
  expect_equal(total_of("JS", "5H", "5D", "5C", "5S"), 29L)  # the maximum hand
  expect_equal(total_of("JH", "5H", "5D", "5C", "5S"), 28L)  # nobs misses
  expect_equal(total_of("4S", "5H", "6D", "6C", "5S"), 24L)  # double double run
  expect_equal(total_of("7S", "7H", "8D", "8C", "9S"), 24L)
  expect_equal(total_of("4S", "4H", "4D", "5C", "6S"), 21L)  # triple run
  expect_equal(total_of("3S", "4H", "5D", "6C", "9S"), 8L)
  expect_equal(total_of("AS", "2H", "3D", "4C", "5S"), 7L)   # run of five
  expect_equal(total_of("2H", "4H", "6H", "8H", "KH"), 5L)   # flush, nothing else
  expect_equal(total_of("2H", "4H", "6H", "8H", "KS"), 4L)
  expect_equal(total_of("2S", "4H", "6D", "8C", "KS"), 0L)   # a genuine 0-point hand
})

test_that("score_hand reports a breakdown that sums to the total", {
  scored <- score_hand(lay("JS", "5H", "5D", "5C", "5S")$hand,
                       lay("JS", "5H", "5D", "5C", "5S")$starter)
  expect_equal(scored$breakdown[["fifteens"]], 16L)
  expect_equal(scored$breakdown[["pairs"]], 12L)
  expect_equal(scored$breakdown[["nobs"]], 1L)
  expect_equal(sum(scored$breakdown), scored$total)
  expect_equal(describe_score(scored), "29 (fifteens 16, pairs 12, nobs 1)")
  expect_equal(describe_score(score_hand(lay("2S","4H","6D","8C","KS")$hand,
                                         lay("2S","4H","6D","8C","KS")$starter)),
               "0 (nothing)")
})

test_that("no layout scores an impossible total", {
  # 19, 25, 26 and 27 are unreachable, and 29 is the ceiling.
  set.seed(1234)
  deck <- new_deck()
  totals <- vapply(seq_len(3000L), function(i) {
    d <- deal_hand(deck)
    score_hand(d$hand, d$starter)$total
  }, integer(1))
  expect_true(max(totals) <= 29L)
  expect_length(intersect(totals, c(19L, 25L, 26L, 27L)), 0L)
})
