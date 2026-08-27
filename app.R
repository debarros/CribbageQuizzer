# Cribbage Quizzer -- a Shiny app for drilling cribbage hand scoring.
#
# Scoring and deck logic live in R/, which Shiny auto-sources because that
# directory sits next to this file. Do NOT source() those files here.
#
# This file is the view layer only: it renders cards and feedback and calls
# into score_hand() / describe_score(). Keep scoring rules out of it.

library(shiny)

CARD_CSS <- "
.cq-cards { display: flex; align-items: flex-end; gap: 10px; flex-wrap: wrap;
            margin: 8px 0 22px; }
.cq-card { width: 62px; height: 88px; border: 1px solid #b9c0c8; border-radius: 8px;
           background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.15);
           display: flex; flex-direction: column; align-items: center;
           justify-content: center; line-height: 1.1; }
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
"

# Let Enter in the answer field stand in for clicking "Check answer".
#
# Shiny debounces keystrokes by 250ms before sending a value to the server, so
# an Enter pressed straight after typing would otherwise check the PREVIOUS
# value. Firing a change event first flushes the current value immediately
# (Shiny sends change events without the rate policy), and because both
# messages queue on the same websocket in order, the server sees the new
# number before it sees the button click.
ENTER_JS <- "
$(document).on('keydown', '#guess', function(e) {
  if (e.key === 'Enter') {
    e.preventDefault();
    $(this).trigger('change');
    $('#check').click();
  }
});
"

# Render one card as a rounded tile, red for hearts and diamonds.
card_tag <- function(card) {
  div(
    class = paste("cq-card", if (card$suit %in% c("H", "D")) "cq-red" else "cq-black"),
    span(class = "cq-rank", RANKS[card$rank]),
    span(class = "cq-suit", unname(SUIT_SYMBOLS[card$suit]))
  )
}

# The four hand cards, then a divider, then the starter under its label.
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

ui <- fluidPage(
  tags$head(
    tags$style(HTML(CARD_CSS)),
    tags$script(HTML(ENTER_JS))
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
          "Calculate This lets you enter a specific hand and see how it scores. Not built yet.")
      )
    )
  )
)

server <- function(input, output, session) {
  deck <- new_deck()

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

    scored <- score_hand(layout()$hand, layout()$starter)

    if (identical(as.integer(guess), scored$total)) {
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
}

shinyApp(ui = ui, server = server)
