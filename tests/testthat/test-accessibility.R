# The app must be operable by mouse, keyboard and touch. These assertions pin
# the structure that makes that true, because it is all easy to undo by
# accident -- swapping a <button> back to a <div> looks identical on screen and
# silently removes the element from the keyboard's reach.
#
# app.R is sourced (its final shinyApp() call just builds an object) so the UI
# and the tag helpers can be rendered and inspected as HTML.

app_source <- function() {
  e <- new.env(parent = globalenv())
  sys.source(normalizePath(file.path("..", "..", "app.R"), mustWork = TRUE), envir = e)
  e
}

html_of <- function(x) paste(as.character(x), collapse = "")
count_of <- function(haystack, pattern) {
  length(gregexpr(pattern, haystack, fixed = TRUE)[[1]][gregexpr(pattern, haystack, fixed = TRUE)[[1]] > 0])
}

app <- app_source()
ui_html <- html_of(app$ui)
# tags$head content is hoisted during rendering, so as.character() on the UI
# never shows it -- the head has to be rendered explicitly.
ui_head <- paste(as.character(htmltools::renderTags(app$ui)$head), collapse = "")

test_that("the page declares a viewport, without which phones zoom out", {
  expect_match(ui_head, 'name="viewport"', fixed = TRUE)
  expect_match(ui_head, "width=device-width", fixed = TRUE)
})

test_that("every picker card is a real button, not a clickable div", {
  picker <- html_of(app$picker_tags())

  expect_equal(count_of(picker, "<button"), 52L)
  expect_equal(count_of(picker, 'type="button"'), 52L)
  # A div with a click handler is invisible to the keyboard; a button is not.
  expect_equal(count_of(picker, 'class="cq-btn cq-pick'), 52L)
})

test_that("the picker holds exactly one tab stop", {
  # 52 tab stops would make the last card a 52-press journey; the arrow keys
  # move the single stop instead.
  picker <- html_of(app$picker_tags())
  expect_equal(count_of(picker, 'tabindex="0"'), 1L)
  expect_equal(count_of(picker, 'tabindex="-1"'), 51L)
})

test_that("every card in the deck is offered exactly once, with a spoken name", {
  picker <- html_of(app$picker_tags())
  deck <- new_deck()

  for (id in card_label(deck)) {
    expect_equal(count_of(picker, paste0('data-card="', id, '"')), 1L)
  }
  expect_match(picker, 'aria-label="Ace of Spades"', fixed = TRUE)
  expect_match(picker, 'aria-label="Ten of Diamonds"', fixed = TRUE)
  expect_match(picker, 'aria-label="King of Clubs"', fixed = TRUE)
})

test_that("unavailable cards stay focusable rather than being skipped", {
  # aria-disabled keeps a card in the arrow-key sequence so a screen reader can
  # say it is already chosen; the disabled attribute would drop it silently.
  picker <- html_of(app$picker_tags())
  expect_equal(count_of(picker, 'aria-disabled="false"'), 52L)
  expect_equal(count_of(picker, "disabled=\"disabled\""), 0L)
})

test_that("suit glyphs are hidden from screen readers", {
  # A screen reader announcing the heart glyph is noise; the card's aria-label
  # carries the real name.
  picker <- html_of(app$picker_tags())
  expect_equal(count_of(picker, 'class="cq-suit" aria-hidden="true"'), 52L)
  expect_equal(count_of(picker, 'class="cq-rank" aria-hidden="true"'), 52L)
})

test_that("chosen cards are buttons that say what activating them does", {
  slots <- html_of(app$slot_tags(c("5S", "JS")))

  expect_equal(count_of(slots, "<button"), 2L)
  expect_match(slots, "Five of Spades, starter. Activate to remove it.", fixed = TRUE)
  expect_match(slots, "Jack of Spades, hand 1. Activate to remove it.", fixed = TRUE)
})

test_that("empty slots announce themselves rather than being silent boxes", {
  slots <- html_of(app$slot_tags(c("5S")))
  expect_match(slots, 'aria-label="Hand 1, empty"', fixed = TRUE)
  expect_match(slots, 'aria-label="Hand 4, empty"', fixed = TRUE)
  expect_equal(count_of(slots, "<button"), 1L)
})

test_that("the quiz hand is described but not operable", {
  layout <- list(hand = card_from_id(c("JS", "5H", "5D", "5C")),
                 starter = card_from_id("5S"))
  h <- html_of(app$layout_tags(layout))

  # Nothing here is clickable, so nothing here should be a button or a tab stop.
  expect_equal(count_of(h, "<button"), 0L)
  expect_equal(count_of(h, "tabindex"), 0L)
  expect_equal(count_of(h, 'role="img"'), 5L)
  expect_match(h, 'aria-label="Five of Spades, the starter"', fixed = TRUE)
  expect_match(h, 'aria-label="Jack of Spades"', fixed = TRUE)
})

test_that("the score is readable without seeing the layout", {
  s <- html_of(app$score_tags(c("5S", "JS", "5H", "5D", "5C")))
  expect_match(s, "This layout scores 29 points", fixed = TRUE)
  # Each category is spelled out for a screen reader, not left as a bare glyph pair.
  expect_match(s, "fifteens 16", fixed = TRUE)
  expect_match(s, "nobs 1", fixed = TRUE)
})

test_that("a one-point layout is announced as '1 point', not '1 points'", {
  # Starter 8D with JD 3D KD 9C in hand: his nobs and nothing else.
  ids <- c("8D", "JD", "3D", "KD", "9C")
  expect_equal(score_hand(card_from_id(ids)[2:5, ], card_from_id(ids)[1, ])$total, 1L)
  expect_match(html_of(app$score_tags(ids)), "scores 1 point<", fixed = TRUE)

  # And the plural still reads correctly.
  expect_match(html_of(app$score_tags(c("9S", "AS", "2H", "3D", "4C"))),
               "scores 8 points", fixed = TRUE)
})

test_that("live regions announce feedback, progress and score", {
  # Without aria-live a screen reader user gets no notice that anything changed.
  expect_equal(count_of(ui_html, 'aria-live="polite"'), 3L)
  expect_match(ui_html, 'role="status"', fixed = TRUE)
})

test_that("the picker is in the UI, not an output that gets re-rendered", {
  # Re-rendering would replace the element the keyboard user is standing on and
  # throw focus to the top of the page after every pick.
  expect_match(ui_html, 'data-card="AS"', fixed = TRUE)
  expect_equal(count_of(ui_html, 'id="calc_picker"'), 0L)
})

test_that("touch targets meet the 44px minimum and hover is gated", {
  css <- app$CARD_CSS
  expect_match(css, "min-width: 44px", fixed = TRUE)
  expect_match(css, "min-height: 44px", fixed = TRUE)
  # Hover styles stick after a tap on a touchscreen, so they are gated.
  expect_match(css, "@media (hover: hover)", fixed = TRUE)
  expect_match(css, "touch-action: manipulation", fixed = TRUE)
  # Keyboard focus must be visible.
  expect_match(css, ":focus-visible", fixed = TRUE)
})

test_that("the page declares its language", {
  # Without lang, a screen reader speaks the English card names with whatever
  # voice the user defaults to.
  expect_equal(attr(app$ui, "lang"), "en")
})

test_that("red suits are not flattened to black by the button reset", {
  # `.cq-btn { color: inherit }` sits after .cq-red/.cq-black at equal
  # specificity, so it wins and every card button renders in the inherited
  # colour. Measured live: red and black picker cards both became rgb(51,51,51).
  # Strip comments first -- the stylesheet explains this rule in prose, and the
  # explanation contains the very string being searched for.
  css <- gsub("/[*].*?[*]/", "", app$CARD_CSS)
  expect_false(grepl("color: inherit", css, fixed = TRUE))

  # Both suit colours must still be declared.
  expect_match(css, ".cq-red { color: #c0392b; }", fixed = TRUE)
  expect_match(css, ".cq-black { color: #2c3e50; }", fixed = TRUE)
})

test_that("body text clears the 4.5:1 contrast minimum on white", {
  # #7b8794 measures 3.66:1 against white -- under AA. #5b6670 is 5.87:1.
  expect_false(grepl("#7b8794", app$CARD_CSS, fixed = TRUE))

  relative_luminance <- function(hex) {
    v <- grDevices::col2rgb(hex)[, 1] / 255
    v <- ifelse(v <= 0.03928, v / 12.92, ((v + 0.055) / 1.055) ^ 2.4)
    sum(c(0.2126, 0.7152, 0.0722) * v)
  }
  contrast <- function(hex) {
    l <- sort(c(relative_luminance(hex), relative_luminance("#ffffff")),
              decreasing = TRUE)
    (l[1] + 0.05) / (l[2] + 0.05)
  }

  # Every colour the stylesheet puts on text, checked against white.
  text_colours <- unique(regmatches(
    app$CARD_CSS,
    gregexpr("color: #[0-9a-fA-F]{6}", app$CARD_CSS)
  )[[1]])
  text_colours <- sub("color: ", "", text_colours)
  for (hex in text_colours) {
    expect_gte(contrast(hex), 4.5)
  }
})

test_that("the answer field is big enough not to trigger iOS focus zoom", {
  # Bootstrap 3 leaves .form-control at 14px; iOS Safari zooms the viewport when
  # a focused field is under 16px, and the viewport meta allows scaling.
  expect_match(app$CARD_CSS, ".form-control { font-size: 16px; height: 44px; }",
               fixed = TRUE)
})

test_that("stored stats are sent after the session initializes, not on connect", {
  # An input set on shiny:connected is flushed before Shiny's init message and
  # leaves every visible output marked hidden: Quiz Me deals no cards.
  expect_false(grepl("'shiny:connected'", app$APP_JS, fixed = TRUE))
  expect_match(app$APP_JS, "'shiny:sessioninitialized'", fixed = TRUE)
})
