# Quiz performance statistics.
#
# A user's record of Quiz Me answers, kept in their own browser's localStorage
# rather than on a server: no accounts, nothing stored about anyone centrally.
# The app round-trips it as a JSON string; everything here is plain R so the
# rules can be tested without Shiny.
#
# What is counted:
#   answered / correct   first answer to each dealt hand (re-checks don't count)
#   streak / best_streak consecutive correct first answers
#   under / over         wrong answers below / above the true total
#   recent               the last RECENT_MAX results, oldest first, 1 = correct
#   seen / right         per scoring category: hands where that category scored
#                        points, and how many of those were answered correctly
#
# Stored data is untrusted -- the user can edit localStorage, and an older or
# newer app version may have written it -- so stats_from_json() never trusts a
# field it has not checked.
#
# No Shiny code belongs in this file.

STATS_VERSION <- 1L
RECENT_MAX <- 50L

# Must match the names of score_hand()'s breakdown; the test suite checks it.
STAT_CATEGORIES <- c("fifteens", "pairs", "runs", "flush", "nobs")

#' A fresh record with nothing answered.
empty_stats <- function() {
  zeros <- setNames(integer(length(STAT_CATEGORIES)), STAT_CATEGORIES)
  list(
    version = STATS_VERSION,
    answered = 0L, correct = 0L,
    streak = 0L, best_streak = 0L,
    under = 0L, over = 0L,
    recent = integer(0),
    seen = zeros, right = zeros
  )
}

#' Add one answer to the record.
#'
#' @param stats  a record from empty_stats() or stats_from_json()
#' @param scored the result of score_hand() for the hand that was answered
#' @param guess  the user's whole-number answer
record_answer <- function(stats, scored, guess) {
  is_right <- isTRUE(guess == scored$total)

  stats$answered <- stats$answered + 1L
  if (is_right) {
    stats$correct <- stats$correct + 1L
    stats$streak <- stats$streak + 1L
    stats$best_streak <- max(stats$best_streak, stats$streak)
  } else {
    stats$streak <- 0L
    if (guess < scored$total) stats$under <- stats$under + 1L
    else stats$over <- stats$over + 1L
  }

  stats$recent <- utils::tail(c(stats$recent, as.integer(is_right)), RECENT_MAX)

  present <- STAT_CATEGORIES[scored$breakdown[STAT_CATEGORIES] > 0L]
  stats$seen[present] <- stats$seen[present] + 1L
  if (is_right) stats$right[present] <- stats$right[present] + 1L

  stats
}

#' Serialise a record for localStorage.
stats_to_json <- function(stats) {
  as.character(jsonlite::toJSON(
    list(
      version = stats$version,
      answered = stats$answered, correct = stats$correct,
      streak = stats$streak, best_streak = stats$best_streak,
      under = stats$under, over = stats$over,
      # I() keeps a one-element vector as a JSON array under auto_unbox.
      recent = I(stats$recent),
      seen = as.list(stats$seen), right = as.list(stats$right)
    ),
    auto_unbox = TRUE
  ))
}

#' Rebuild a record from localStorage, repairing anything malformed.
#'
#' Returns empty_stats() for missing, unparseable or foreign data, and clamps
#' individual fields that are out of range, so a corrupted entry can never
#' throw inside the app.
stats_from_json <- function(json) {
  if (!is.character(json) || length(json) != 1L || is.na(json) || !nzchar(json)) {
    return(empty_stats())
  }
  raw <- tryCatch(jsonlite::fromJSON(json, simplifyVector = FALSE),
                  error = function(e) NULL)
  if (!is.list(raw) || is.null(names(raw))) return(empty_stats())
  if (!identical(count_field(raw$version), STATS_VERSION)) return(empty_stats())

  stats <- empty_stats()
  for (field in c("answered", "correct", "streak", "best_streak", "under", "over")) {
    stats[[field]] <- count_field(raw[[field]])
  }
  for (field in c("seen", "right")) {
    block <- raw[[field]]
    if (!is.list(block)) next
    for (category in STAT_CATEGORIES) {
      stats[[field]][[category]] <- count_field(block[[category]])
    }
  }
  # Drop bad entries rather than zeroing them, which would invent misses.
  recent <- Filter(function(x) is.numeric(x) && length(x) == 1L && x %in% c(0, 1),
                   if (is.list(raw$recent)) raw$recent else list())
  stats$recent <- utils::tail(as.integer(unlist(recent)), RECENT_MAX)

  # Keep the parts consistent with each other, whatever was stored.
  stats$correct <- min(stats$correct, stats$answered)
  stats$right <- pmin(stats$right, stats$seen)
  stats$streak <- min(stats$streak, stats$correct)
  stats$best_streak <- max(stats$best_streak, stats$streak)
  stats
}

# A stored count: a single non-negative whole number, otherwise 0.
count_field <- function(x) {
  if (is.list(x) && length(x) == 1L) x <- x[[1]]
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0 ||
      x != round(x) || x > .Machine$integer.max) {
    return(0L)
  }
  as.integer(x)
}

#' Percentage of `part` in `whole`, as display text: "75%", or NA if whole is 0.
format_pct <- function(part, whole) {
  ifelse(whole > 0L, paste0(round(100 * part / whole), "%"), NA_character_)
}

#' Figures for display, derived from a record.
#'
#' @param recent_n how many of the latest answers "recent accuracy" covers
#' @return list of the headline counts, recent accuracy, and a per-category
#'   data.frame (category, seen, right, pct) in STAT_CATEGORIES order
summarize_stats <- function(stats, recent_n = 20L) {
  recent <- utils::tail(stats$recent, recent_n)
  list(
    answered = stats$answered,
    correct = stats$correct,
    accuracy = format_pct(stats$correct, stats$answered),
    streak = stats$streak,
    best_streak = stats$best_streak,
    recent_count = length(recent),
    recent_accuracy = format_pct(sum(recent), length(recent)),
    under = stats$under,
    over = stats$over,
    categories = data.frame(
      category = STAT_CATEGORIES,
      seen = unname(stats$seen),
      right = unname(stats$right),
      pct = format_pct(unname(stats$right), unname(stats$seen)),
      stringsAsFactors = FALSE
    )
  )
}
