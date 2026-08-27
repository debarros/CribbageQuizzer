# Cribbage hand scoring.
#
# Scores a 4-card hand plus the starter (cut) card. Every function here is
# pure: same cards in, same score out, no Shiny reactives, no randomness.
#
# The five scoring categories are independent and are summed:
#   fifteens  2 points per distinct subset of cards totalling exactly 15
#   pairs     2 points per distinct pair of equal ranks
#   runs      1 point per card in a maximal run of 3+, times its multiplicity
#   flush     4 for a 4-card hand flush, 5 if the starter matches
#   nobs      1 for a jack IN HAND whose suit matches the starter

#' Score every subset of cards summing to fifteen.
#'
#' Subsets are counted, not cards: three 5s and a jack contain four different
#' fifteens (each 5 with the jack) plus one more (the three 5s together).
score_fifteens <- function(values) {
  n <- length(values)
  if (n < 2L) return(0L)
  hits <- 0L
  for (k in 2:n) {
    subsets <- combn(values, k)
    hits <- hits + sum(colSums(subsets) == 15)
  }
  as.integer(2L * hits)
}

#' Score pairs, counting every distinct two-card combination.
#'
#' This is why three of a kind is 6 (three pairs) and four of a kind is 12
#' (six pairs) rather than 2 and 4.
score_pairs <- function(ranks) {
  counts <- table(ranks)
  as.integer(2L * sum(choose(counts, 2)))
}

#' Score runs of three or more consecutive ranks.
#'
#' Only maximal runs count -- a run of four is 4 points, not two overlapping
#' runs of three. Duplicated ranks multiply the run rather than adding a
#' second one, so 4-5-5-6 is a double run of three: 3 cards x 2 ways = 6.
score_runs <- function(ranks) {
  counts <- table(ranks)
  distinct <- as.integer(names(counts))
  ord <- order(distinct)
  distinct <- distinct[ord]
  multiplicity <- as.integer(counts)[ord]

  total <- 0L
  i <- 1L
  while (i <= length(distinct)) {
    j <- i
    while (j < length(distinct) && distinct[j + 1L] == distinct[j] + 1L) {
      j <- j + 1L
    }
    run_length <- j - i + 1L
    if (run_length >= 3L) {
      total <- total + run_length * prod(multiplicity[i:j])
    }
    i <- j + 1L
  }
  as.integer(total)
}

#' Score a flush.
#'
#' All four hand cards must share a suit; the starter then adds a fifth point
#' if it matches. Three hand cards plus a matching starter is NOT a flush.
#' In the crib, nothing short of all five cards counts at all.
score_flush <- function(hand_suits, starter_suit, is_crib = FALSE) {
  if (length(unique(hand_suits)) != 1L) return(0L)
  if (identical(hand_suits[1], starter_suit)) return(5L)
  if (is_crib) return(0L)
  4L
}

#' Score "his nobs": a jack in hand matching the starter's suit.
#'
#' The starter itself being a jack is his heels, scored by the dealer at cut
#' time rather than during hand counting, so it is not counted here.
score_nobs <- function(hand, starter) {
  as.integer(any(hand$rank == 11L & hand$suit == starter$suit))
}

#' Score a full cribbage layout.
#'
#' @param hand    data.frame of 4 cards (see R/cards.R)
#' @param starter data.frame of 1 card
#' @param is_crib TRUE to apply the crib's stricter flush rule
#' @return list with `total` (integer) and `breakdown` (named integer vector)
score_hand <- function(hand, starter, is_crib = FALSE) {
  validate_layout(hand, starter)

  all_cards <- rbind(hand, starter)
  ranks <- all_cards$rank

  breakdown <- c(
    fifteens = score_fifteens(card_value(ranks)),
    pairs    = score_pairs(ranks),
    runs     = score_runs(ranks),
    flush    = score_flush(hand$suit, starter$suit, is_crib),
    nobs     = score_nobs(hand, starter)
  )

  list(total = as.integer(sum(breakdown)), breakdown = breakdown)
}

#' One-line explanation of a score, for quiz feedback.
#'
#' Returns e.g. "16 (fifteens 8, pairs 6, nobs 1)", or "0 (nothing)".
describe_score <- function(scored) {
  earned <- scored$breakdown[scored$breakdown > 0L]
  if (length(earned) == 0L) return(paste0(scored$total, " (nothing)"))
  parts <- paste(names(earned), earned, collapse = ", ")
  paste0(scored$total, " (", parts, ")")
}
