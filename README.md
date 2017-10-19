Using MLServer Python services within Shiny
================

Integrating remote Microsoft Machine Learning Server (MLServer) R or Python web services within R Shiny is easy via the [mrsdeploy](https://docs.microsoft.com/en-us/machine-learning-server/r-reference/mrsdeploy/mrsdeploy-package) R package.

This blog post explains the details using a contrived Shiny example in order to emphasize:

-   Integrating Python standard and realtime services from MLServer
-   Ease of service consumption using *remote* function calls from [mrsdeploy](https://docs.microsoft.com/en-us/machine-learning-server/r-reference/mrsdeploy/mrsdeploy-package)
-   Return file artifacts generated in Python and displayed in R

> Please find the full [example source](#example-app) used within this post [here](https://github.com/swells/mlserver-shiny).

Service Integration
-------------------

All MLServer invocations require authentication. Rather than introducing a complex frontend authentication workflow, this example will simply hardcode the credentials within the `app.R` file before the Shiny `ui` and `server` contexts such that it executes on application startup. If you choose to run the example yourself, please remember to first substitute in the `{{MLSERVER_HOST}}`, `{{USERNAME}}`, and `{{PASSWORD}}` values as shown below.

MLServer supports both Azure Active Directory (Azure AD) and Active Directory (AD) authentication. As a result, one could easily envision a more robust user experience in *production* that supports a Shiny-powered UI control for a secure AD *username/password* authentication or even an hook into an Azure AD workflow within your single-page app. For the sake of simplicity, a more robust frontend authentication workflow is left as an exercise for the reader.

#### Authentication

``` r
# -- app.R --

library(shiny)
library(mrsdeploy)

mrsdeploy::remoteLogin(
  '{{MLSERVER_HOST}}',
  session = FALSE,
  username ='{{USERNAME}}',
  password = '{{PASSWORD}}'
)
```

#### Service discovery

Once authenticated, we can *discover* and get a local client reference to all the MLServer published services used in the example by `service-name` and an optional `version`. This example uses two services built in Python and already deployed to MLServer:

1.  [car-service](#car-service) version `v1.0.0`
2.  [realtime-rating-service](#realtime-rating-service) version `v3.0.1`

``` r
# -- app.R --

carService <- mrsdeploy::getService('car-service', 'v1.0.0')
realtimeService <- mrsdeploy::getService('realtime-rating-service', 'v3.0.1')
```

With the local client references populated, we can now invoke the [services](#service-consumption) within the Shiny runtime like any other function call.

Service Consumption
-------------------

Our [example application](#example-app) makes use of two services: [car-service](#car-service) and [realtime-rating-service](#realtime-rating-service). We know the [car-service](#car-service) exposes the remote function `manualTransmission(hp, wt)` to consume the service. It takes in two arguments, `hp` and `wt` of type `numeric` and returns a `data.frame`. We also know that the [realtime-rating-service](#realtime-rating-service) exposes the remote function `rating(df)` to consume the service and excepts a `data.frame` as input and returns a `data.frame` as output.

Example:

``` r
response <- carService$manualTransmission(120, 2.8)
response <- realtimeService$rating(head(attitude, n=1L))
```

Since the service invocations are abstracted in function calls, they integrate naturally with Shiny's reactive expressions. This allows us to limit what gets re-run during a reaction and use the expressions to access (as a proxy) any MLServer web service.

For example, here’s a reactive expression that makes use of our [car-service](#car-service) and [realtime-rating-service](#realtime-rating-service) from MLServer:

``` r

rating <- reactive({
   realtimeService$rating(attitude[input$row, ])$output('outputData')
})
  
manualTransmission <- reactive({
   carService$manualTransmission(input$hp, input$wt/1000)
})
```

When the expressions are ran, they will invoke both `realtimeService$rating(...)` and `carService$manualTransmission(...)` and return the results. You can use the expressions to access their respective service data in any of Shiny’s `render*` output functions by calling `rating()` and `manualTransmission()`:

``` r

output$realtimeServiceView <- renderTable(rating())
  
output$carServiceView <- renderUI({
   res <- manualTransmission()
    
   output$answer <- renderTable(res$output('answer'))

   tagList(
      tableOutput('answer'),
      img(src=paste0('data:image/png;base64,', res$artifact('image.png', dec=FALSE)))
    )
})
```

> **NOTE** For an in-depth description on how to interact with and consume web services in R using `mrsdeploy` please review the [official documentation](https://docs.microsoft.com/en-us/machine-learning-server/operationalize/how-to-consume-web-service-interact-in-r).

Service file artifacts
----------------------

In the previous section we made use of a service's ability to return a file on the response and access that file within the client:

``` r
res$artifact('image.png', dec=FALSE)
```

Files generated in the working directory during service execution can be returned inline within the response should a service author expose it as such. All file artifacts are represented in *base64* encoded format and can be plucked out of the response by *filename* using the `artifact('filename', dec=TRUE)` function.

Example, assuming a PNG file named `image.png` is generated during service execution:

``` r
res <- carService$manualTransmission(120, 2.8) # produces a file named `image.png`
print(res$output('answer'))

binaryPNG <- res$artifact('image.png') # binary - default decodes from base64
base64PNG <- res$artifact('image.png' dec=FALSE) # do not base64 decode
```

Depending on you needs you could save the `artifact('filename', dec=TRUE)` result it to a file or use it immediately within a Shiny `img` tag as was done in our [example](#example-app):

``` r
img(src=paste0('data:image/png;base64,', res$artifact('image.png', dec=FALSE)))
```

![Histogram](https://user-images.githubusercontent.com/1356351/31753316-b088e72a-b444-11e7-96d4-a1054dd31bd5.png)

Example App
-----------

``` r
#
# Copyright (C) Microsoft Corporation. All rights reserved.
#
# File: app.r
# 

library(shiny)
library(mrsdeploy)

# -----------------------------------------------------------------------------
# First authenticate, all MLServer invocations require authentication. For this
# example we simply hardcode the credentials here. AD or Azure Active Directory 
# (AAD) are both supported. A Frontend/authentication workflow is left as an 
# exercise for the reader...
#
# Add your {{USERNAME}} and {{PASSWORD}} and {{MLSERVER_HOST}} endpoint
# -----------------------------------------------------------------------------

mrsdeploy::remoteLogin(
  '{{MLSERVER_HOST}}',
  session = FALSE,
  username ='{{USERNAME}}',
  password = '{{PASSWORD}}'
)

# -----------------------------------------------------------------------------
# -- Discover/Get services used in this example:
#    1. name: `car-service` version `v1.0.0`
#    2. name: `realtime-rating-service` version `v3.0.1`
# -----------------------------------------------------------------------------

carService <- mrsdeploy::getService('car-service', 'v1.0.0')
realtimeService <- mrsdeploy::getService('realtime-rating-service', 'v3.0.1')

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
           'Price Attitude row: ', 
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
```

The above Shiny app will produce this very simple UI. Let’s summarize the behavior:

-   Selecting a row from the `Attitude Dataset` select list will re-consume the [realtime-rating-service](#realtime-rating-service) on MLServer
-   Realtime prediction result will be rendered
-   Adjusting either of the slider-controls will re-consume the [car-service](#car-service) on MLServer
-   Prediction result will be rendered and the arbitrary histogram image artifact will be painted

![View](https://user-images.githubusercontent.com/1356351/31786143-4daf202e-b4bc-11e7-9d30-3828cf17b9d6.png)

Python Services
---------------

Starting with Microsoft Machine Learning Server (MLServer) `9.3.0` full Python support was introduced including a client Python package [azureml-model-management-sdk](https://docs.microsoft.com/en-us/machine-learning-server/python-reference/azureml-model-management-sdk/azureml-model-management-sdk) containing equivalent service deployment workflow as `mrsdeploy` in R.

#### car-service

``` py
from revoscalepy import rx_lin_mod
from azureml.deploy import DeployClient
from microsoftml.datasets.datasets import get_dataset

mtcars = get_dataset('mtcars')

# -- Define the exactly same model as we did in Part 1.a --
cars_model = rx_lin_mod(formula='am ~ hp + wt', data=mtcars)

# -- Define a `code_fn` that makes a prediction using our model and test data --
def manualTransmission(hp, wt):
    import pandas as pd
    import numpy as np
    from revoscalepy import rx_predict
    from matplotlib import pyplot as plt
    
    # -- make the prediction use model `cars_model` and input data --
    new_data = pd.DataFrame({"hp":[hp], "wt":[wt]})
    answer = rx_predict(cars_model, new_data, type = 'response')
    
    # -- save arbitrary file to demonstrate the ability to return files --
    mu, sigma = 100, 15
    x = mu + sigma * np.random.randn(10000)
    hist, bins = np.histogram(x, bins=50)
    width = 0.7 * (bins[1] - bins[0])
    center = (bins[:-1] + bins[1:]) / 2
    plt.bar(center, hist, align='center', width=width)
    plt.savefig('image.png')
    
    # return prediction
    return answer

# -- authenticate against MLServer --
auth = ('{{USERNAME}}', '{{PASSWORD}}')
client = DeployClient('{{MLSERVER_HOST}}', use='MLServer', auth=auth)

# -- Publish/Deploy the `car-service`
client.service('car-service')\
   .version('v1.0.0')\
   .code_fn(manualTransmission)\
   .inputs(hp=float, wt=float)\
   .outputs(answer=pd.DataFrame)\
   .models(cars_model=cars_model)\
   .description('The car-service.')\
   .artifacts(['image.png'])\
   .deploy()
```

#### realtime-rating-service

``` py
from revoscalepy import rx_serialize_model, rx_lin_mod
from azureml.deploy import DeployClient
from microsoftml.datasets.datasets import get_dataset

attitude = get_dataset('attitude').as_df() \
   .drop('Unnamed: 0', axis = 1).astype('double')

form = "rating ~ complaints + privileges + learning + raises + critical + advance"
model = rx_lin_mod(form, attitude, method = 'regression')

s_model = rx_serialize_model(model, realtime_scoring_only=True)

# -- authenticate against MLServer --
auth = ('{{USERNAME}}', '{{PASSWORD}}')
client = DeployClient('{{MLSERVER_HOST}}', use='MLServer', auth=auth)

# -- Publish/Deploy realtime-rating-service --
client.realtime_service('realtime-rating-service') \
   .version('3.0.1') \
   .serialized_model(s_model) \
   .alias('rating') \
   .description("this is a realtime model") \
   .deploy()
```
