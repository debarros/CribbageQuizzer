# Quiz performance stats: recording answers and surviving a round trip through
# the browser's localStorage, including the garbage that can come back from it.

scored_of <- function(...) {
  l <- lay(...)
  score_hand(l$hand, l$starter)
}

# 5H 5D 5C JS with 5S: 29 points -- fifteens, pairs and nobs, no runs or flush.
perfect <- scored_of("5H", "5D", "5C", "JS", "5S")
# 2C 4D 6H 8S with KC: nothing at all.
nothing <- scored_of("2C", "4D", "6H", "8S", "KC")

test_that("the stat categories match the scorer's breakdown", {
  expect_identical(STAT_CATEGORIES, names(perfect$breakdown))
})

test_that("a correct answer counts towards accuracy and the streak", {
  s <- record_answer(empty_stats(), perfect, 29)
  expect_equal(c(s$answered, s$correct, s$streak, s$best_streak), c(1L, 1L, 1L, 1L))
  expect_equal(s$recent, 1L)
  expect_equal(c(s$under, s$over), c(0L, 0L))
})

test_that("a wrong answer breaks the streak but keeps the best", {
  s <- empty_stats()
  for (i in 1:3) s <- record_answer(s, perfect, 29)
  s <- record_answer(s, perfect, 28)
  expect_equal(s$streak, 0L)
  expect_equal(s$best_streak, 3L)
  expect_equal(s$recent, c(1L, 1L, 1L, 0L))
  s <- record_answer(s, perfect, 29)
  expect_equal(c(s$streak, s$best_streak), c(1L, 3L))
})

test_that("misses are split into undercounts and overcounts", {
  s <- record_answer(empty_stats(), perfect, 24)
  s <- record_answer(s, nothing, 2)
  s <- record_answer(s, perfect, 20)
  expect_equal(c(s$under, s$over), c(2L, 1L))
})

test_that("categories are credited only on hands where they scored", {
  s <- record_answer(empty_stats(), perfect, 29)
  s <- record_answer(s, perfect, 28)
  s <- record_answer(s, nothing, 0)
  expect_equal(unname(s$seen), c(2L, 2L, 0L, 0L, 2L))
  expect_equal(unname(s$right), c(1L, 1L, 0L, 0L, 1L))
})

test_that("only the most recent results are kept", {
  s <- empty_stats()
  for (i in seq_len(RECENT_MAX + 10L)) s <- record_answer(s, nothing, if (i <= 10L) 1 else 0)
  expect_length(s$recent, RECENT_MAX)
  expect_true(all(s$recent == 1L))
  expect_equal(s$answered, RECENT_MAX + 10L)
})

test_that("a record survives the JSON round trip unchanged", {
  s <- empty_stats()
  expect_identical(stats_from_json(stats_to_json(s)), s)

  # One recent result is the case auto_unbox would flatten to a bare number.
  s <- record_answer(s, perfect, 28)
  expect_identical(stats_from_json(stats_to_json(s)), s)

  for (g in c(29, 29, 0, 29)) s <- record_answer(s, perfect, g)
  expect_identical(stats_from_json(stats_to_json(s)), s)
})

test_that("missing or unreadable storage starts a fresh record", {
  fresh <- empty_stats()
  expect_identical(stats_from_json(""), fresh)
  expect_identical(stats_from_json(NULL), fresh)
  expect_identical(stats_from_json(NA_character_), fresh)
  expect_identical(stats_from_json(c("{}", "{}")), fresh)
  expect_identical(stats_from_json(list(answered = 3)), fresh)
  expect_identical(stats_from_json("{not json"), fresh)
  expect_identical(stats_from_json("[1, 2, 3]"), fresh)
  expect_identical(stats_from_json("\"text\""), fresh)
  expect_identical(stats_from_json("[object Object]"), fresh)
})

test_that("a record from another format version is not misread", {
  json <- sub('"version":1', '"version":2', stats_to_json(record_answer(empty_stats(), perfect, 29)))
  expect_identical(stats_from_json(json), empty_stats())
  expect_identical(stats_from_json('{"answered": 5, "correct": 5}'), empty_stats())
})

test_that("tampered fields are repaired rather than trusted", {
  s <- stats_from_json(paste0(
    '{"version":1, "answered":"lots", "correct":-4, "streak":2.5, "best_streak":null,',
    ' "under":1e300, "over":[1,2], "recent":[1, 0, 7, "x", -1, 1.0, null],',
    ' "seen":{"fifteens":3, "runs":"x"}, "right":{"fifteens":9}, "extra":true}'
  ))
  expect_equal(c(s$answered, s$correct, s$streak, s$best_streak, s$under, s$over),
               rep(0L, 6))
  expect_equal(s$recent, c(1L, 0L, 1L))
  # right can never exceed seen.
  expect_equal(s$seen[["fifteens"]], 3L)
  expect_equal(s$right[["fifteens"]], 3L)
  expect_equal(s$seen[["runs"]], 0L)
  expect_named(s, names(empty_stats()))
})

test_that("stored counts are made consistent with each other", {
  s <- stats_from_json(
    '{"version":1, "answered":4, "correct":9, "streak":7, "best_streak":2}'
  )
  expect_equal(s$correct, 4L)
  expect_equal(s$streak, 4L)
  expect_equal(s$best_streak, 4L)
})

test_that("the summary reports percentages and leaves empty ones blank", {
  s <- empty_stats()
  expect_true(is.na(summarize_stats(s)$accuracy))

  for (g in c(29, 29, 28, 29)) s <- record_answer(s, perfect, g)
  sm <- summarize_stats(s)
  expect_equal(sm$accuracy, "75%")
  expect_equal(sm$recent_count, 4L)
  expect_equal(sm$recent_accuracy, "75%")
  expect_equal(sm$categories$pct, c("75%", "75%", NA, NA, "75%"))

  # Recent accuracy covers only the latest answers.
  sm <- summarize_stats(s, recent_n = 2L)
  expect_equal(sm$recent_count, 2L)
  expect_equal(sm$recent_accuracy, "50%")
})
