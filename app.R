#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Cribbage Quizzer"),

    # Sidebar with button to switch between "Quiz Me" and "Calculate This".  "Calculate This" will be built later.
    sidebarLayout(
        sidebarPanel(
            # Button
        ),

        # Main interface
        mainPanel(
          # Display playing cards of a cribbage hand
          # Button to randomly generate a cribbage hand and clear the entry field and the feedback text
          # Entry field for the user to type in the point total
          # Button to check user's answer.  This generates feedback text saying whether the user was right, and if not, then also the correct point total.
        )
    )
)

# Define server logic 
server <- function(input, output) {

  # Randomly generate a cribbage hand by selecting from a deck of cards without replacement
  
  # Calculate the score of the cribbage hand that was generated
  
  # Compare the calculated score to the one entered by the user and generate feedback
  
}

# Run the application 
shinyApp(ui = ui, server = server)
