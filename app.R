# Cribbage Quizzer -- a Shiny app for drilling cribbage hand scoring.
#
# Scoring and deck logic live in R/, which Shiny auto-sources because that
# directory sits next to this file. Do NOT source() those files here.
#
# This file is the view layer only: it renders cards and feedback and calls
# into score_hand() / describe_score(). Keep scoring rules out of it.
#
# Three modes share the sidebar:
#   Quiz Me         deals a random layout and asks the user to score it
#   Calculate This  lets the user build a specific layout and see it scored
#   My Stats        shows how the user has done on Quiz Me
#
# Stats live in the browser's localStorage, not on the server: the server
# receives them once on connect (input$stored_stats) and sends the updated
# record back after every change (the cq_stats_save message). R/stats.R owns
# the record's rules; this file only moves it and displays it.
#
# Interaction is meant to work with a mouse, a keyboard or a touchscreen, on a
# phone, tablet or desktop. Three rules follow from that and are easy to undo
# by accident:
#
#  1. Anything clickable is a real <button>, so it is focusable and responds to
#     Enter and Space without any script.
#  2. The picker is rendered ONCE in the UI and its chosen/available state is
#     updated in place by a custom message. Re-rendering it would destroy the
#     element the keyboard user is standing on and dump focus to the top of the
#     page after every pick.
#  3. Cards a user cannot pick are aria-disabled but still focusable, so arrow
#     navigation does not silently skip them and a screen reader can say why.

library(shiny)

CARD_CSS <- "
:root { --cq-card-w: clamp(46px, 12vw, 62px); --cq-card-h: clamp(66px, 17vw, 88px); }

.cq-cards { display: flex; align-items: flex-end; gap: 10px; flex-wrap: wrap;
            margin: 8px 0 22px; }
.cq-card { width: var(--cq-card-w); height: var(--cq-card-h);
           border: 1px solid #b9c0c8; border-radius: 8px; background: #fff;
           box-shadow: 0 1px 3px rgba(0,0,0,.15); display: flex;
           flex-direction: column; align-items: center; justify-content: center;
           line-height: 1.1; user-select: none; }
.cq-rank { font-size: clamp(15px, 4vw, 20px); font-weight: 700; }
.cq-suit { font-size: clamp(16px, 4.4vw, 22px); }
.cq-red { color: #c0392b; } .cq-black { color: #2c3e50; }
.cq-starter { display: flex; flex-direction: column; align-items: center; gap: 4px; }
.cq-starter-label { font-size: 11px; text-transform: uppercase; letter-spacing: .06em;
                    color: #5b6670; }
.cq-divider { width: 1px; align-self: stretch; background: #dfe3e8; margin: 0 6px; }
.cq-feedback { font-size: 16px; margin-top: 14px; min-height: 24px; }
.cq-correct { color: #1e8449; font-weight: 600; }
.cq-wrong { color: #c0392b; font-weight: 600; }
.cq-prompt { color: #5b6670; }

/* Buttons that look like cards, not like buttons. */
/* No `color: inherit` here: it sits after .cq-red/.cq-black at equal
   specificity and would win, rendering every red suit black. */
.cq-btn { padding: 0; background: #fff; font: inherit;
          -webkit-appearance: none; appearance: none; cursor: pointer;
          touch-action: manipulation; }
.cq-btn:focus-visible { outline: 3px solid #2d6cdf; outline-offset: 2px; }

/* ---- Calculate This ---- */
.cq-slots { display: flex; align-items: flex-end; gap: 10px; flex-wrap: wrap;
            margin: 8px 0 6px; padding: 0; border: 0; list-style: none; }
.cq-slot { display: flex; flex-direction: column; align-items: center; gap: 4px; }
.cq-slot-label { font-size: 11px; text-transform: uppercase; letter-spacing: .06em;
                 color: #5b6670; }
.cq-slot-starter { color: #2c3e50; font-weight: 700; }
.cq-empty { width: var(--cq-card-w); height: var(--cq-card-h);
            border: 1px dashed #cfd6dd; border-radius: 8px; background: #fafbfc; }
.cq-hint { font-size: 13px; color: #5b6670; margin: 0 0 14px; min-height: 18px; }

.cq-picker { display: flex; flex-direction: column; gap: 6px; margin: 4px 0 18px;
             padding: 0; border: 0; }
.cq-picker-row { display: flex; gap: 4px; flex-wrap: wrap; }
.cq-pick { min-width: 44px; min-height: 44px;
           width: clamp(44px, 6.4vw, 48px); height: clamp(44px, 8vw, 56px);
           border: 1px solid #ccd2d9; border-radius: 6px; display: flex;
           flex-direction: column; align-items: center; justify-content: center;
           line-height: 1.05; user-select: none; }
.cq-pick .cq-rank { font-size: 14px; }
.cq-pick .cq-suit { font-size: 14px; }
.cq-taken { opacity: .3; cursor: default; }
.cq-picker-full .cq-pick:not(.cq-taken) { opacity: .45; cursor: default; }

.cq-score { border-top: 1px solid #e4e8ec; padding-top: 14px; }
.cq-total { font-size: clamp(28px, 8vw, 34px); font-weight: 700; color: #2c3e50; }
.cq-total-label { font-size: 14px; color: #5b6670; margin-left: 6px; }
.cq-breakdown { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px;
                padding: 0; list-style: none; }
.cq-brk { border: 1px solid #e4e8ec; border-radius: 6px; padding: 5px 10px;
          font-size: 13px; background: #fff; }
.cq-brk-name { color: #5b6670; text-transform: capitalize; }
.cq-brk-val { font-weight: 700; margin-left: 6px; color: #2c3e50; }
.cq-brk-zero { opacity: .5; }

/* Hover belongs to devices that actually hover. On a touchscreen these stick
   after a tap and make chosen cards look interactive when they are not. */
@media (hover: hover) {
  .cq-pick:not(.cq-taken):hover { border-color: #2d6cdf;
                                  box-shadow: 0 0 0 2px rgba(45,108,223,.25); }
  .cq-removable:hover { border-color: #c0392b;
                        box-shadow: 0 0 0 2px rgba(192,57,43,.30); }
}

/* Stacked layout: give the controls room to breathe on a phone. */
@media (max-width: 767px) {
  .cq-cards, .cq-slots { gap: 6px; }
  .cq-divider { display: none; }
  .cq-actions .btn { min-height: 44px; }
}

/* The app's one text field. Bootstrap 3 leaves .form-control at 14px/34px:
   under 16px, iOS Safari zooms the viewport on focus, and 34px is short of the
   44px buttons beside it. Raising the font-size removes the zoom at source --
   maximum-scale/user-scalable=no would suppress it by killing pinch-zoom and
   fail WCAG 1.4.4 Resize Text. */
.form-control { font-size: 16px; height: 44px; }

/* ---- My Stats ---- */
.cq-tally { font-size: 13px; color: #5b6670; margin-top: 6px; }
.cq-tiles { display: flex; gap: 10px; flex-wrap: wrap; margin: 8px 0 20px;
            padding: 0; list-style: none; }
.cq-tile { border: 1px solid #e4e8ec; border-radius: 8px; padding: 10px 14px;
           min-width: 112px; background: #fff; }
.cq-tile-val { display: block; font-size: 24px; font-weight: 700; color: #2c3e50; }
.cq-tile-name { display: block; font-size: 13px; color: #5b6670; }
.cq-stats-table { max-width: 520px; }
.cq-stats-table td, .cq-stats-table th { text-align: right; }
.cq-stats-table td:first-child, .cq-stats-table th:first-child { text-align: left;
                                                                 text-transform: capitalize; }
.cq-stats-note { font-size: 13px; color: #5b6670; margin: 14px 0; }

.cq-visually-hidden { position: absolute; width: 1px; height: 1px; padding: 0;
                      margin: -1px; overflow: hidden; clip: rect(0 0 0 0);
                      white-space: nowrap; border: 0; }
"

# Enter in the answer field stands in for clicking "Check answer".
#
# Shiny debounces keystrokes by 250ms before sending a value to the server, so
# an Enter pressed straight after typing would otherwise check the PREVIOUS
# value. Firing a change event first flushes the current value immediately
# (Shiny sends change events without the rate policy), and because both
# messages queue on the same websocket in order, the server sees the new
# number before it sees the button click.
#
# The picker is a roving-tabindex grid: it holds ONE tab stop, and the arrow
# keys move between cards. 52 separate tab stops would make reaching the last
# card a 52-press journey.
APP_JS <- "
$(document).on('keydown', '#guess', function(e) {
  if (e.key === 'Enter') {
    e.preventDefault();
    $(this).trigger('change');
    $('#check').click();
  }
});

function cqPickCards() { return $('.cq-pick').toArray(); }

// Exactly one picker card is tabbable at a time; the arrows move that stop.
function cqSetRoving(el) {
  cqPickCards().forEach(function(c) {
    c.setAttribute('tabindex', c === el ? '0' : '-1');
  });
}

$(document).on('keydown', '.cq-pick', function(e) {
  var all = cqPickCards();
  var i = all.indexOf(this);
  if (i < 0) return;
  var perRow = 13, next = null;
  if (e.key === 'ArrowRight') next = all[Math.min(i + 1, all.length - 1)];
  else if (e.key === 'ArrowLeft') next = all[Math.max(i - 1, 0)];
  else if (e.key === 'ArrowDown') next = all[Math.min(i + perRow, all.length - 1)];
  else if (e.key === 'ArrowUp') next = all[Math.max(i - perRow, 0)];
  else if (e.key === 'Home') next = all[Math.floor(i / perRow) * perRow];
  else if (e.key === 'End') next = all[Math.floor(i / perRow) * perRow + perRow - 1];
  else return;
  e.preventDefault();
  if (next) { cqSetRoving(next); next.focus(); }
});

// Focus follows the pointer too, so tabbing back returns to the last card used.
$(document).on('click', '.cq-pick', function() {
  cqSetRoving(this);
  if ($(this).attr('aria-disabled') === 'true') return;
  Shiny.setInputValue('pick_card', $(this).attr('data-card'), {priority: 'event'});
});

var cqLastRemove = 0;
$(document).on('click', '.cq-removable', function(e) {
  // Removing a card compacts the slot row, and the re-render lands well inside
  // the double-click interval -- so the second click of a double-click hits
  // whichever card slid into that position and removes a card the user never
  // aimed at. Drop the follow-up clicks of a burst.
  if (e.detail > 1 || Date.now() - cqLastRemove < 400) return;
  cqLastRemove = Date.now();
  // Remember where we were: the slot row is about to be rebuilt.
  window.cqRemovedFrom = $(this).closest('.cq-slot').index();
  Shiny.setInputValue('remove_card', $(this).attr('data-card'), {priority: 'event'});
});

// The picker is never re-rendered, so chosen state is toggled in place and the
// focused element survives every pick.
Shiny.addCustomMessageHandler('cq_selection', function(msg) {
  var chosen = msg.ids || [], full = chosen.length >= 5;
  $('.cq-picker').toggleClass('cq-picker-full', full);
  $('.cq-pick').each(function() {
    var id = this.getAttribute('data-card');
    var taken = chosen.indexOf(id) !== -1;
    this.classList.toggle('cq-taken', taken);
    this.setAttribute('aria-disabled', (taken || full) ? 'true' : 'false');
    var name = this.getAttribute('data-name');
    this.setAttribute('aria-label', taken ? name + ', already chosen' : name);
  });
  if (!cqPickCards().some(function(c) { return c.getAttribute('tabindex') === '0'; })) {
    cqSetRoving(cqPickCards()[0]);
  }
});

// Quiz stats are kept in this browser only. Hand the stored record to the
// server once per connection -- an empty string when there is none, or when
// storage is blocked (private browsing, disabled site data), so the server
// still knows loading has finished.
//
// This must wait for shiny:sessioninitialized, not shiny:connected. An input
// set on connect is flushed ahead of the Shiny init message, taking the
// first visibility flags of the outputs with it; init then reports them
// hidden, the visible state is never re-sent, and every Quiz Me output stays
// suspended -- no cards, and Check answer does nothing.
var CQ_STATS_KEY = 'cribbageQuizzer.stats';
$(document).one('shiny:sessioninitialized', function() {
  var stored = null;
  try { stored = window.localStorage.getItem(CQ_STATS_KEY); } catch (e) {}
  Shiny.setInputValue('stored_stats', stored === null ? '' : stored, {priority: 'event'});
});

// The server sends the whole record back after every change, reset included.
Shiny.addCustomMessageHandler('cq_stats_save', function(msg) {
  try { window.localStorage.setItem(CQ_STATS_KEY, msg.json); } catch (e) {}
});

// The slot row IS re-rendered, so put focus back where the user was standing.
$(document).on('shiny:value', function(e) {
  if (e.name !== 'calc_slots' || window.cqRemovedFrom == null) return;
  var from = window.cqRemovedFrom;
  window.cqRemovedFrom = null;
  setTimeout(function() {
    var cards = $('.cq-removable').toArray();
    if (cards.length) cards[Math.min(from, cards.length - 1)].focus();
    else { var c = document.getElementById('clear_selection'); if (c) c.focus(); }
  }, 0);
});
"

SLOT_LABELS <- c("Starter", "Hand 1", "Hand 2", "Hand 3", "Hand 4")

# The face of a card: glyphs for sighted users, hidden from screen readers,
# which get a spoken name from the container's aria-label instead.
card_face <- function(card) {
  list(
    span(class = "cq-rank", `aria-hidden` = "true", RANKS[card$rank]),
    span(class = "cq-suit", `aria-hidden` = "true", unname(SUIT_SYMBOLS[card$suit]))
  )
}

suit_class <- function(suit) if (suit %in% c("H", "D")) "cq-red" else "cq-black"

# A card that is only looked at, not operated: an image with a text alternative.
card_tag <- function(card, extra_label = "") {
  div(
    class = paste("cq-card", suit_class(card$suit)),
    role = "img",
    `aria-label` = paste0(card_name(card), extra_label),
    card_face(card)
  )
}

# Quiz Me: the four hand cards, a divider, then the starter under its label.
layout_tags <- function(layout) {
  div(
    class = "cq-cards",
    role = "group",
    `aria-label` = "The hand to score",
    lapply(seq_len(nrow(layout$hand)), function(i) card_tag(layout$hand[i, ])),
    div(class = "cq-divider", `aria-hidden` = "true"),
    div(
      class = "cq-starter",
      span(class = "cq-starter-label", `aria-hidden` = "true", "Starter"),
      card_tag(layout$starter, extra_label = ", the starter")
    )
  )
}

# Calculate This: five labelled slots filled in pick order. The first slot is
# the starter, so removing it promotes the next card into that role. Filled
# slots are buttons because activating one removes that card.
slot_tags <- function(ids) {
  tags$ul(
    class = "cq-slots",
    `aria-label` = "Cards you have chosen",
    lapply(seq_len(5L), function(i) {
      tags$li(
        class = "cq-slot",
        span(class = paste("cq-slot-label", if (i == 1L) "cq-slot-starter" else ""),
             `aria-hidden` = "true", SLOT_LABELS[i]),
        if (i <= length(ids)) {
          card <- card_from_id(ids[i])
          tags$button(
            type = "button",
            class = paste("cq-btn cq-card cq-removable", suit_class(card$suit)),
            `data-card` = ids[i],
            `aria-label` = paste0(card_name(card), ", ", tolower(SLOT_LABELS[i]),
                                  ". Activate to remove it."),
            card_face(card)
          )
        } else {
          div(class = "cq-empty", role = "img",
              `aria-label` = paste0(SLOT_LABELS[i], ", empty"))
        }
      )
    })
  )
}

# The 52-card picker, one row per suit. Rendered once and never replaced: the
# server toggles chosen state through the cq_selection message so that focus
# survives. Only the first card is tabbable; arrows move from there.
picker_tags <- function() {
  div(
    class = "cq-picker",
    role = "group",
    `aria-label` = "Choose a card from the deck",
    lapply(SUITS, function(suit) {
      div(
        class = "cq-picker-row",
        role = "group",
        `aria-label` = unname(SUIT_NAMES[suit]),
        lapply(seq_len(13L), function(rank) {
          card <- data.frame(rank = as.integer(rank), suit = suit,
                             stringsAsFactors = FALSE)
          id <- card_label(card)
          nm <- card_name(card)
          tags$button(
            type = "button",
            class = paste("cq-btn cq-pick", suit_class(suit)),
            `data-card` = id,
            `data-name` = nm,
            `aria-label` = nm,
            `aria-disabled` = "false",
            tabindex = if (rank == 1L && identical(suit, SUITS[1])) "0" else "-1",
            card_face(card)
          )
        })
      )
    })
  )
}

# Total plus every category, zeroes included -- seeing which categories scored
# nothing is the point of a scoring trainer.
score_tags <- function(ids) {
  cards <- card_from_id(ids)
  scored <- score_hand(cards[2:5, ], cards[1, ])
  points_word <- if (scored$total == 1L) "point" else "points"
  div(
    class = "cq-score",
    role = "group",
    `aria-label` = "Score for this layout",
    div(
      span(class = "cq-total", `aria-hidden` = "true", scored$total),
      span(class = "cq-total-label", `aria-hidden` = "true", points_word),
      span(class = "cq-visually-hidden",
           paste("This layout scores", scored$total, points_word))
    ),
    tags$ul(
      class = "cq-breakdown",
      lapply(names(scored$breakdown), function(category) {
        points <- scored$breakdown[[category]]
        tags$li(
          class = paste("cq-brk", if (points == 0L) "cq-brk-zero" else ""),
          span(class = "cq-brk-name", `aria-hidden` = "true", category),
          span(class = "cq-brk-val", `aria-hidden` = "true", points),
          span(class = "cq-visually-hidden", paste(category, points))
        )
      })
    )
  )
}

# My Stats: headline figures as tiles, then accuracy per scoring category.
stats_tags <- function(stats) {
  s <- summarize_stats(stats)
  if (s$answered == 0L) {
    return(p(class = "cq-prompt",
             "No answers yet. Score a few hands in Quiz Me and your results will appear here."))
  }

  tile <- function(value, name) {
    tags$li(class = "cq-tile",
            span(class = "cq-tile-val", value),
            span(class = "cq-tile-name", name))
  }
  missed <- s$answered - s$correct

  tagList(
    tags$ul(
      class = "cq-tiles",
      `aria-label` = "Your quiz results",
      tile(s$answered, if (s$answered == 1L) "hand answered" else "hands answered"),
      tile(s$accuracy, "correct overall"),
      tile(s$recent_accuracy, sprintf("correct in your last %d", s$recent_count)),
      tile(s$streak, "current streak"),
      tile(s$best_streak, "best streak")
    ),
    if (missed > 0L) {
      p(class = "cq-prompt", sprintf(
        "Of the %d %s you missed, you counted too low on %d and too high on %d.",
        missed, if (missed == 1L) "hand" else "hands", s$under, s$over))
    },
    # A real table: a screen reader can announce each figure with its headers.
    tags$table(
      class = "table table-condensed cq-stats-table",
      tags$caption("Accuracy on hands that scored each category"),
      tags$thead(tags$tr(
        tags$th(scope = "col", "Category"),
        tags$th(scope = "col", "Hands"),
        tags$th(scope = "col", "Correct"),
        tags$th(scope = "col", "Accuracy")
      )),
      tags$tbody(lapply(seq_len(nrow(s$categories)), function(i) {
        row <- s$categories[i, ]
        tags$tr(
          tags$th(scope = "row", row$category),
          tags$td(row$seen),
          tags$td(row$right),
          tags$td(if (is.na(row$pct)) {
            # A bare dash is read aloud as "em dash".
            tagList(span(`aria-hidden` = "true", "\u2014"),
                    span(class = "cq-visually-hidden", "none yet"))
          } else {
            row$pct
          })
        )
      }))
    )
  )
}

ui <- fluidPage(
  # Without this the page renders as bare <html>, and a screen reader speaks
  # English card names with whatever voice the user defaults to.
  lang = "en",

  tags$head(
    # Without this a phone lays the page out at ~980px and zooms out.
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$style(HTML(CARD_CSS)),
    tags$script(HTML(APP_JS))
  ),

  titlePanel("Cribbage Quizzer"),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      radioButtons(
        "mode", "Mode",
        choices = c("Quiz Me" = "quiz", "Calculate This" = "calc", "My Stats" = "stats"),
        selected = "quiz"
      )
    ),

    mainPanel(
      width = 9,

      conditionalPanel(
        condition = "input.mode == 'quiz'",
        p(class = "cq-prompt", "Score this hand, counting the starter."),
        uiOutput("hand_display"),
        numericInput("guess", "Point total", value = NA, min = 0, max = 29, step = 1),
        div(
          class = "cq-actions",
          actionButton("check", "Check answer", class = "btn-primary"),
          actionButton("deal", "New hand")
        ),
        uiOutput("feedback", `aria-live` = "polite", role = "status"),
        uiOutput("quiz_tally")
      ),

      conditionalPanel(
        condition = "input.mode == 'calc'",
        p(class = "cq-prompt",
          "Build a layout from the deck below. The first card you pick is the starter."),
        uiOutput("calc_slots"),
        uiOutput("calc_hint", `aria-live` = "polite", role = "status"),
        div(class = "cq-actions", actionButton("clear_selection", "Clear all")),
        picker_tags(),
        uiOutput("calc_score", `aria-live` = "polite")
      ),

      conditionalPanel(
        condition = "input.mode == 'stats'",
        uiOutput("stats_display"),
        p(class = "cq-stats-note",
          "Your stats are saved in this browser only. They are not sent anywhere,",
          "they do not follow you to another device, and clearing this site's",
          "data erases them."),
        div(class = "cq-actions", actionButton("reset_stats", "Reset my stats"))
      )
    )
  )
)

server <- function(input, output, session) {
  deck <- new_deck()
  deck_ids <- card_label(deck)

  # ---- Stats ------------------------------------------------------------

  # The browser's stored record arrives once, just after connecting. Until then
  # nothing is saved, so an empty in-memory record cannot overwrite a real one.
  # (An answer checked in that split second is overwritten by the load.)
  stats <- reactiveVal(empty_stats())
  stats_loaded <- reactiveVal(FALSE)

  observeEvent(input$stored_stats, {
    if (stats_loaded()) return()
    stats(stats_from_json(input$stored_stats))
    stats_loaded(TRUE)
  })

  # Each tab keeps its own copy, so with two tabs open the last one to save wins.
  save_stats <- function(s) {
    stats(s)
    if (stats_loaded()) {
      session$sendCustomMessage("cq_stats_save", list(json = stats_to_json(s)))
    }
  }

  observeEvent(input$reset_stats, {
    showModal(modalDialog(
      title = "Reset your stats?",
      "This erases every Quiz Me result saved in this browser. It cannot be undone.",
      footer = tagList(
        modalButton("Keep my stats"),
        actionButton("confirm_reset_stats", "Reset", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_reset_stats, {
    removeModal()
    save_stats(empty_stats())
  })

  output$stats_display <- renderUI(stats_tags(stats()))

  # ---- Quiz Me ----------------------------------------------------------

  # The layout being quizzed: 4 hand cards plus a starter, dealt without
  # replacement. Reactive so the deal button can replace it.
  layout <- reactiveVal(deal_hand(deck))

  # NULL until the user checks an answer; cleared whenever a new hand is dealt.
  feedback <- reactiveVal(NULL)

  # Only the first answer to a hand counts towards the stats; otherwise a wrong
  # answer followed by the total from the feedback would score as a success.
  hand_recorded <- reactiveVal(FALSE)

  observeEvent(input$deal, {
    layout(deal_hand(deck))
    feedback(NULL)
    hand_recorded(FALSE)
    updateNumericInput(session, "guess", value = NA)
  })

  output$hand_display <- renderUI(layout_tags(layout()))

  observeEvent(input$check, {
    guess <- input$guess

    if (is.null(guess) || is.na(guess)) {
      feedback(list(status = "prompt", text = "Enter a point total first."))
      return()
    }

    # numericInput accepts decimals, and truncating to integer would score 7.9
    # as a correct 7. Treat a fractional entry as a slip rather than a wrong
    # answer, since no cribbage hand is worth a fraction of a point.
    if (guess != round(guess)) {
      feedback(list(status = "prompt", text = "Enter a whole number of points."))
      return()
    }

    scored <- score_hand(layout()$hand, layout()$starter)

    if (!hand_recorded()) {
      hand_recorded(TRUE)
      save_stats(record_answer(stats(), scored, guess))
    }

    if (isTRUE(guess == scored$total)) {
      feedback(list(
        status = "correct",
        text = paste0("Correct — ", describe_score(scored), ".")
      ))
    } else {
      feedback(list(
        status = "wrong",
        text = paste0("Not quite. This hand is worth ", describe_score(scored), ".")
      ))
    }
  })

  output$feedback <- renderUI({
    fb <- feedback()
    if (is.null(fb)) return(div(class = "cq-feedback"))
    css_class <- switch(fb$status,
      correct = "cq-feedback cq-correct",
      wrong   = "cq-feedback cq-wrong",
      "cq-feedback cq-prompt"
    )
    div(class = css_class, fb$text)
  })

  output$quiz_tally <- renderUI({
    s <- stats()
    if (s$answered == 0L) return(NULL)
    p(class = "cq-tally", sprintf("%d of %d correct \u00b7 streak %d",
                                  s$correct, s$answered, s$streak))
  })

  # ---- Calculate This ---------------------------------------------------

  # Card ids in the order they were picked; selected()[1] is the starter.
  selected <- reactiveVal(character(0))

  observeEvent(input$pick_card, {
    id <- input$pick_card
    current <- selected()

    # The picker marks chosen cards aria-disabled, but a click can still race a
    # message, and the input is reachable from the browser console, so re-check
    # every rule here.
    #
    # The scalar check must come first: a vector id would make the two %in%
    # tests below throw "the condition has length > 1", and Shiny answers an
    # unhandled observer error by closing the session, losing the selection.
    if (!is.character(id) || length(id) != 1L) return()
    if (length(current) >= 5L) return()
    if (id %in% current) return()
    if (!id %in% deck_ids) return()

    selected(c(current, id))
  })

  observeEvent(input$remove_card, {
    # setdiff keeps the survivors in pick order, so the card following a
    # removed starter becomes the new starter.
    selected(setdiff(selected(), input$remove_card))
  })

  observeEvent(input$clear_selection, selected(character(0)))

  # Update the picker in place rather than re-rendering it, so a keyboard user
  # keeps their position in the grid across every pick.
  observe({
    session$sendCustomMessage("cq_selection", list(ids = as.list(selected())))
  })

  output$calc_slots <- renderUI(slot_tags(selected()))

  output$calc_hint <- renderUI({
    n <- length(selected())
    p(class = "cq-hint", if (n == 0L) {
      "Pick five cards. The first one is the starter."
    } else if (n < 5L) {
      sprintf("Pick %d more card%s. Activate a chosen card to remove it.",
              5L - n, if (5L - n == 1L) "" else "s")
    } else {
      "Five cards chosen. Activate a chosen card to remove it."
    })
  })

  output$calc_score <- renderUI({
    ids <- selected()
    if (length(ids) < 5L) return(NULL)
    score_tags(ids)
  })

  # Outputs that start life inside a hidden conditionalPanel are suspended, and
  # Shiny only lifts that once it notices they became visible. That notice does
  # not always arrive, which leaves the whole Calculate This panel permanently
  # blank on the first switch into it. These outputs are cheap, so opt them out
  # of suspension entirely rather than depending on visibility tracking.
  for (id in c("calc_slots", "calc_hint", "calc_score", "stats_display")) {
    outputOptions(output, id, suspendWhenHidden = FALSE)
  }
}

shinyApp(ui = ui, server = server)
