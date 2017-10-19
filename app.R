library(shiny)
library(mrsdeploy)

# -----------------------------------------------------------------------------
# First authenticate, all MLServer invocations require authentication. For this
# example we simply hardcode the credentials here. AD or Azure Active Directory 
# (AAD) are both supported. A Frontend/authentication workflow is left as an 
# exercise for the reader...
#
# Add your {{USERNAME}} and {{PASSWORD}} below MLServer {{ENDPOINT}}
# -----------------------------------------------------------------------------

mrsdeploy::remoteLogin(
  '{{MLSERVER_HOST}}',
  session = FALSE,
  username ='{{USERNAME}}',
  password = '{{PASSWORD}}'
)

# -----------------------------------------------------------------------------
# -- Discover/Get services used in this example:
#    1. name: `car-service` verion `v1.0`
#    2. name: `realtime-rating-service` verion `v3.0`
# -----------------------------------------------------------------------------

carService <- getService('car-service', '1.0')
realtimeService <- getService('realtime-rating-service', '1.0')

# -----------------------------------------------------------------------------
# -- Define UI/Frontend layout
# -----------------------------------------------------------------------------

ui <- fluidPage(
  
  # Application title
  titlePanel('Microsoft Machine Learning Server'), br(),
  
  # Sidebar with a slider input for number of bins 
  sidebarLayout(
    sidebarPanel(
      selectInput(
        'row', 
        'Price Attitude row:', 
        choices = seq(1, nrow(attitude)), 
        selected = 1
      ),
      sliderInput(
        'hp',
        'Gross horsepower:',
        min = 50,
        max = 350,
        value = 120
      ),
      sliderInput(
        'wt',
        'Weight:',
        min = 1500,
        max = 5500,
        value = 2800
      )
    ),
    mainPanel(
      # -- realtime-service results --
      h3('Realtime rating service answer'),
      tableOutput('realtimeServiceView'),
      # -- car-service results --
      h3('Standard car service answer'),
      uiOutput('carServiceView')
    )
  )
)

# -----------------------------------------------------------------------------
# -- Define server logic
# -----------------------------------------------------------------------------

server <- function(input, output) {
  
  # -- remote `rating()` call to `realtime-rating-service`
  rating <- reactive({
    realtimeService$rating(attitude[input$row, ])$output('outputData')
  })
  
  # -- remote `manualTransmission()` call to `car-service`
  manualTransmission <- reactive({
    carService$manualTransmission(input$hp, input$wt/1000)
  })
  
  output$realtimeServiceView <- renderTable(rating())
  
  output$carServiceView <- renderUI({
    res <- manualTransmission()
    
    output$answer <- renderTable(res$output('answer'))
    
    tagList(
      tableOutput('answer'),
      h4('File Artifact (image)'),
      img(src=paste0('data:image/png;base64,', res$artifact('image.png', dec=FALSE)))
    )
  })
}

# -----------------------------------------------------------------------------
# -- Run the application 
# -----------------------------------------------------------------------------

shinyApp(ui = ui, server = server)
