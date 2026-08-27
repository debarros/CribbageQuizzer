# Deck and card representation.
#
# A "card" is one row of a data.frame with two columns:
#   rank  integer 1-13, where 1 = Ace, 11 = Jack, 12 = Queen, 13 = King
#   suit  one of "S", "H", "D", "C"
#
# Ranks are stored as 1-13 (not as face values) because runs need the true
# ordering: J-Q-K is a run, but all three cards are worth 10 points.
# Aces are always low; K-A-2 is not a run.
#
# No Shiny code belongs in this file.

RANKS <- c("A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K")
SUITS <- c("S", "H", "D", "C")
SUIT_SYMBOLS <- c(S = "♠", H = "♥", D = "♦", C = "♣")

#' Build a standard 52-card deck.
new_deck <- function() {
  deck <- expand.grid(rank = 1:13, suit = SUITS, stringsAsFactors = FALSE)
  deck$rank <- as.integer(deck$rank)
  rownames(deck) <- NULL
  deck[, c("rank", "suit")]
}

#' Point value of a rank: ace is 1, face cards are 10.
card_value <- function(rank) pmin(as.integer(rank), 10L)

#' Human-readable card labels, e.g. "5H" or "5<heart>".
card_label <- function(cards, symbols = FALSE) {
  suit_chr <- if (symbols) unname(SUIT_SYMBOLS[cards$suit]) else cards$suit
  paste0(RANKS[cards$rank], suit_chr)
}

#' Deal a cribbage hand: 4 cards plus a starter, drawn without replacement.
#'
#' Returns a list with `hand` (4 rows) and `starter` (1 row).
deal_hand <- function(deck = new_deck()) {
  idx <- sample.int(nrow(deck), 5L)
  hand <- deck[idx[1:4], , drop = FALSE]
  starter <- deck[idx[5], , drop = FALSE]
  rownames(hand) <- NULL
  rownames(starter) <- NULL
  list(hand = hand, starter = starter)
}

#' Stop with a clear message if hand/starter are not a legal 5-card layout.
validate_layout <- function(hand, starter) {
  if (!is.data.frame(hand) || nrow(hand) != 4L) {
    stop("`hand` must be a data.frame of exactly 4 cards.", call. = FALSE)
  }
  if (!is.data.frame(starter) || nrow(starter) != 1L) {
    stop("`starter` must be a data.frame of exactly 1 card.", call. = FALSE)
  }
  all_cards <- rbind(hand, starter)
  if (!all(all_cards$rank %in% 1:13)) {
    stop("Card ranks must be integers from 1 (ace) to 13 (king).", call. = FALSE)
  }
  if (!all(all_cards$suit %in% SUITS)) {
    stop("Card suits must be one of ", paste(SUITS, collapse = ", "), ".", call. = FALSE)
  }
  if (anyDuplicated(paste(all_cards$rank, all_cards$suit)) > 0L) {
    stop("The same card cannot appear twice in a layout.", call. = FALSE)
  }
  invisible(TRUE)
}
