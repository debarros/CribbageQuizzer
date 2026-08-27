# Sourced by testthat before any test file runs.
#
# This is not an R package, so nothing loads R/ automatically the way Shiny
# does for the app. Source it explicitly, relative to this directory.

for (f in list.files(file.path("..", "..", "R"), pattern = "[.]R$", full.names = TRUE)) {
  source(f)
}

#' Shorthand for card_from_id(), which tests use constantly.
cd <- function(x) card_from_id(x)

#' Build a layout from five card strings: four hand cards then the starter.
lay <- function(...) {
  cards <- cd(c(...))
  stopifnot(nrow(cards) == 5L)
  list(hand = cards[1:4, ], starter = cards[5, ])
}

#' Total score for five card strings.
total_of <- function(..., is_crib = FALSE) {
  l <- lay(...)
  score_hand(l$hand, l$starter, is_crib = is_crib)$total
}
