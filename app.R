# Cribbage Quizzer -- a Shiny app for drilling cribbage hand scoring.
#
# Scoring and deck logic live in R/, which Shiny auto-sources because that
# directory sits next to this file. Do NOT source() those files here.
#
# This file is the view layer only: it renders cards and feedback and calls
# into score_hand() / describe_score(). Keep scoring rules out of it.
#
# Two modes share the sidebar:
#   Quiz Me         deals a random layout and asks the user to score it
#   Calculate This  lets the user build a specific layout and see it scored

library(shiny)

CARD_CSS <- "
.cq-cards { display: flex; align-items: flex-end; gap: 10px; flex-wrap: wrap;
            margin: 8px 0 22px; }
.cq-card { width: 62px; height: 88px; border: 1px solid #b9c0c8; border-radius: 8px;
           background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.15);
           display: flex; flex-direction: column; align-items: center;
           justify-content: center; line-height: 1.1; user-select: none; }
.cq-card .cq-rank { font-size: 20px; font-weight: 700; }
.cq-card .cq-suit { font-size: 22px; }
.cq-red { color: #c0392b; } .cq-black { color: #2c3e50; }
.cq-starter { display: flex; flex-direction: column; align-items: center; gap: 4px; }
.cq-starter-label { font-size: 11px; text-transform: uppercase; letter-spacing: .06em;
                    color: #7b8794; }
.cq-divider { width: 1px; align-self: stretch; background: #dfe3e8; margin: 0 6px; }
.cq-feedback { font-size: 16px; margin-top: 14px; min-height: 24px; }
.cq-correct { color: #1e8449; font-weight: 600; }
.cq-wrong { color: #c0392b; font-weight: 600; }
.cq-prompt { color: #7b8794; }

/* ---- Calculate This ---- */
.cq-slots { display: flex; align-items: flex-end; gap: 10px; flex-wrap: wrap;
            margin: 8px 0 6px; }
.cq-slot { display: flex; flex-direction: column; align-items: center; gap: 4px; }
.cq-slot-label { font-size: 11px; text-transform: uppercase; letter-spacing: .06em;
                 color: #7b8794; }
.cq-slot-starter { color: #2c3e50; font-weight: 700; }
.cq-empty { width: 62px; height: 88px; border: 1px dashed #cfd6dd; border-radius: 8px;
            background: #fafbfc; }
.cq-removable { cursor: pointer; }
.cq-removable:hover { border-color: #c0392b; box-shadow: 0 0 0 2px rgba(192,57,43,.30); }
.cq-hint { font-size: 12px; color: #7b8794; margin: 0 0 14px; min-height: 18px; }

.cq-picker { display: flex; flex-direction: column; gap: 5px; margin: 4px 0 18px; }
.cq-picker-row { display: flex; gap: 4px; flex-wrap: wrap; }
.cq-pick { width: 40px; height: 54px; border: 1px solid #ccd2d9; border-radius: 6px;
           background: #fff; display: flex; flex-direction: column; align-items: center;
           justify-content: center; line-height: 1.05; cursor: pointer;
           user-select: none; }
.cq-pick:hover { border-color: #2d6cdf; box-shadow: 0 0 0 2px rgba(45,108,223,.25); }
.cq-pick-rank { font-size: 14px; font-weight: 700; }
.cq-pick-suit { font-size: 14px; }
.cq-taken { opacity: .25; pointer-events: none; }
.cq-picker-full .cq-pick { opacity: .4; pointer-events: none; }

.cq-score { border-top: 1px solid #e4e8ec; padding-top: 14px; }
.cq-total { font-size: 34px; font-weight: 700; color: #2c3e50; }
.cq-total-label { font-size: 14px; color: #7b8794; margin-left: 6px; }
.cq-breakdown { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
.cq-brk { border: 1px solid #e4e8ec; border-radius: 6px; padding: 5px 10px;
          font-size: 13px; background: #fff; }
.cq-brk-name { color: #5b6670; text-transform: capitalize; }
.cq-brk-val { font-weight: 700; margin-left: 6px; color: #2c3e50; }
.cq-brk-zero { opacity: .45; }
"

# Let Enter in the answer field stand in for clicking "Check answer".
#
# Shiny debounces keystrokes by 250ms before sending a value to the server, so
# an Enter pressed straight after typing would otherwise check the PREVIOUS
# value. Firing a change event first flushes the current value immediately
# (Shiny sends change events without the rate policy), and because both
# messages queue on the same websocket in order, the server sees the new
# number before it sees the button click.
#
# The two card handlers are delegated from document because the picker and the
# selected row are rebuilt by renderUI, which replaces their elements. Priority
# 'event' makes a repeated click on the same card fire again rather than being
# dropped as an unchanged input value.
APP_JS <- "
$(document).on('keydown', '#guess', function(e) {
  if (e.key === 'Enter') {
    e.preventDefault();
    $(this).trigger('change');
    $('#check').click();
  }
});
$(document).on('click', '.cq-pick', function() {
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
  Shiny.setInputValue('remove_card', $(this).attr('data-card'), {priority: 'event'});
});
"

SLOT_LABELS <- c("Starter", "Hand 1", "Hand 2", "Hand 3", "Hand 4")

# Render one card as a rounded tile, red for hearts and diamonds.
card_tag <- function(card) {
  div(
    class = paste("cq-card", if (card$suit %in% c("H", "D")) "cq-red" else "cq-black"),
    span(class = "cq-rank", RANKS[card$rank]),
    span(class = "cq-suit", unname(SUIT_SYMBOLS[card$suit]))
  )
}

# Quiz Me: the four hand cards, a divider, then the starter under its label.
layout_tags <- function(layout) {
  div(
    class = "cq-cards",
    lapply(seq_len(nrow(layout$hand)), function(i) card_tag(layout$hand[i, ])),
    div(class = "cq-divider"),
    div(
      class = "cq-starter",
      span(class = "cq-starter-label", "Starter"),
      card_tag(layout$starter)
    )
  )
}

# Calculate This: five labelled slots filled in pick order. The first slot is
# the starter, so removing it promotes the next card into that role.
slot_tags <- function(ids) {
  div(
    class = "cq-slots",
    lapply(seq_len(5L), function(i) {
      div(
        class = "cq-slot",
        span(
          class = paste("cq-slot-label", if (i == 1L) "cq-slot-starter" else ""),
          SLOT_LABELS[i]
        ),
        if (i <= length(ids)) {
          tagAppendAttributes(
            card_tag(card_from_id(ids[i])),
            class = "cq-removable",
            `data-card` = ids[i],
            title = paste0("Remove ", ids[i])
          )
        } else {
          div(class = "cq-empty")
        }
      )
    })
  )
}

# The 52-card picker, one row per suit. Cards already chosen are dimmed, and
# the whole grid goes inert once five are selected.
picker_tags <- function(ids) {
  div(
    class = paste("cq-picker", if (length(ids) >= 5L) "cq-picker-full" else ""),
    lapply(SUITS, function(suit) {
      div(
        class = "cq-picker-row",
        lapply(seq_len(13L), function(rank) {
          id <- paste0(RANKS[rank], suit)
          div(
            class = paste(
              "cq-pick",
              if (suit %in% c("H", "D")) "cq-red" else "cq-black",
              if (id %in% ids) "cq-taken" else ""
            ),
            `data-card` = id,
            span(class = "cq-pick-rank", RANKS[rank]),
            span(class = "cq-pick-suit", unname(SUIT_SYMBOLS[suit]))
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
  div(
    class = "cq-score",
    div(
      span(class = "cq-total", scored$total),
      span(class = "cq-total-label", if (scored$total == 1L) "point" else "points")
    ),
    div(
      class = "cq-breakdown",
      lapply(names(scored$breakdown), function(category) {
        points <- scored$breakdown[[category]]
        div(
          class = paste("cq-brk", if (points == 0L) "cq-brk-zero" else ""),
          span(class = "cq-brk-name", category),
          span(class = "cq-brk-val", points)
        )
      })
    )
  )
}

ui <- fluidPage(
  tags$head(
    tags$style(HTML(CARD_CSS)),
    tags$script(HTML(APP_JS))
  ),

  titlePanel("Cribbage Quizzer"),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      radioButtons(
        "mode", "Mode",
        choices = c("Quiz Me" = "quiz", "Calculate This" = "calc"),
        selected = "quiz"
      )
    ),

    mainPanel(
      width = 9,

      conditionalPanel(
        condition = "input.mode == 'quiz'",
        p(class = "cq-prompt", "Score this hand, counting the starter."),
        uiOutput("hand_display"),
        fluidRow(
          column(
            4,
            numericInput("guess", "Point total", value = NA, min = 0, max = 29, step = 1)
          )
        ),
        actionButton("check", "Check answer", class = "btn-primary"),
        actionButton("deal", "New hand"),
        uiOutput("feedback")
      ),

      conditionalPanel(
        condition = "input.mode == 'calc'",
        p(class = "cq-prompt",
          "Build a layout from the deck below. The first card you pick is the starter."),
        uiOutput("calc_slots"),
        uiOutput("calc_hint"),
        actionButton("clear_selection", "Clear all"),
        uiOutput("calc_picker"),
        uiOutput("calc_score")
      )
    )
  )
)

server <- function(input, output, session) {
  deck <- new_deck()
  deck_ids <- card_label(deck)

  # ---- Quiz Me ----------------------------------------------------------

  # The layout being quizzed: 4 hand cards plus a starter, dealt without
  # replacement. Reactive so the deal button can replace it.
  layout <- reactiveVal(deal_hand(deck))

  # NULL until the user checks an answer; cleared whenever a new hand is dealt.
  feedback <- reactiveVal(NULL)

  observeEvent(input$deal, {
    layout(deal_hand(deck))
    feedback(NULL)
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

  # ---- Calculate This ---------------------------------------------------

  # Card ids in the order they were picked; selected()[1] is the starter.
  selected <- reactiveVal(character(0))

  observeEvent(input$pick_card, {
    id <- input$pick_card
    current <- selected()

    # The picker dims taken cards and goes inert at five, but a click can still
    # race a re-render, and the input is reachable from the browser console, so
    # re-check every rule here.
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

  output$calc_slots <- renderUI(slot_tags(selected()))

  output$calc_picker <- renderUI(picker_tags(selected()))

  output$calc_hint <- renderUI({
    n <- length(selected())
    p(class = "cq-hint", if (n == 0L) {
      "Pick five cards."
    } else if (n < 5L) {
      sprintf("Pick %d more card%s. Click a selected card to remove it.",
              5L - n, if (5L - n == 1L) "" else "s")
    } else {
      "Click a selected card to remove it."
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
  # blank on the first switch into it. These four outputs are cheap, so opt them
  # out of suspension entirely rather than depending on visibility tracking.
  for (id in c("calc_slots", "calc_hint", "calc_picker", "calc_score")) {
    outputOptions(output, id, suspendWhenHidden = FALSE)
  }
}

shinyApp(ui = ui, server = server)
