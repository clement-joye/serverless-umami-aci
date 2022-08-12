# serverless-umami

## Introduction

This repo implements a serverless solution for web analytics using Umami analytics, Azure Functions, Flexbile PostgreSQL server and Azure Service Bus Queue.  
A Terraform script helps in deploying most of the solution, however a few manual steps are required to finish the set up.

The solution is simple:

1. Each data analytics request from users visiting the website are sent to an Azure service bus queue.
2. On a daily basis, an instance of Umami is spun up via Azure Container instance, and all the messages on the bus are forwarded to it in order to be processed.
3. Once all the data is processed, the Umami instance is spun down.

For the purpose of this demo, an Azure Static Web App is used with Gatsby, but any web framework (or none) is fine. The most important is to make sure that it includes the tracker script `gatsby-swa/static/umami.js` with the proper **root url** configured so the requests are sent to the Azure function API.

## Prerequisites

Prior knowledge of the following are recommended:
Azure platform,
Terraform.

The deployment without Terraform is possible as well, but not covered here.

In order to start off, you will need to have the following:

- Terraform installed locally
- An Azure subscription with admin rights
Node.js >= ~12
npm v6 or yarn
Docker
Powershell (including az cli)

## Deployment / Installation


### Terraform

The whole infrastructure is deployed via Terraform. Prior to running the script, make sure to login via Azure cli, and select the right tenant/subscription.

Update `.\terraform\terraform.tfvars` with your respective information. 

*NB: The reason why there is `location` and `alternate_location` is because some services were not all available in my region, so I had to use two of them instead. Please refer to the [documentation](https://azure.microsoft.com/en-us/global-infrastructure/services/) for more info regarding products availability for your regions.*  

Then using the command-line: 

> cd terraform  
> terraform plan -out=plan  
> terraform apply plan  

After a few minutes, everything should be deployed. Refer to the `pitfall` section in case the deployment fails.

*NB: Once the deployment and set up of your database is done, you can stop the Azure Flexible PostgreSQL server along with the Umami ACI, so you don't get billed for it.*

----

### Umami

For local development:
We need to build an image of Umami that allows us t oset the timestamp for page views/ events.
You can build your own local image or use clementjoye/timestamp-enabled-umami:latest  

Then: 

> cd umami  
> docker-compose up -d  

Login to Umami with the default credentials (admin/umami)
- Create website
- Retrieve the website-id

For the deployed environment:

- Connect to your ACI
- Login to Umami with the default credentials (admin/umami)
- Create website
- Retrieve the website-id

Refer to Umami [documentation](https://umami.is/docs/add-a-website) for more info.

---

### Gatsby

Add your website-ids to your `.\gatsby-swa\.env.development` and `.\gatsby-swa\.env.production` respectively along with the root url of your Azure function api. In our case, `http://<static_web_app_url>/api`.  
This will allow the tracker to know which target website to track and where to send the request.   

For local development:

> cd gatsby-swa  
> npm i  
> gatsby develop  

To deploy it to Azure, use the `./github/workflows\your_web_app_hostname.yml`, then:
- Retrieve the publish profile of your Static Web app.
- Create a github secret `AZURE_STATIC_WEB_APPS_API_TOKEN_YOUR_WEB_APP_HOSTNAME` and set the token previuosly retrieved as value.
- Rename the workflow `your_web_app_hostname.yml` with the hostname of your static web app.

If you encounter any difficulties, refer to the multiple [documentation](https://docs.microsoft.com/en-gb/azure/static-web-apps/publish-gatsby?WT.mc_id=staticwebapps-github-chnoring) available.

---

### Flexible PostgreSQL server

The database for our postgresql server needs to be set up to work with Umami.  
With docker-compose this is done automatically at initialization, but we will have to run the script manually on our deployed instance.  
You can refer to the [documentation](https://docs.microsoft.com/en-us/cli/azure/postgres/flexible-server?view=azure-cli-latest) for more info on the commands below if needed.

1. Login to Azure portal and open a cloud shell.
2. Upload `umami/sql/schema.postgresql.sql` to your local storage
3. Run the following commands with your respective info:
> az postgres flexible-server execute -n "<server_hostname>" -u "<username>" -p "<password>" -d "umami" --file-path "<root_file_path>/schema.postgresql.sql"  
> az postgres flexible-server connect -n "<server_hostname>" -u "<username>" -d "<database_name>" --interactive   
> \dt

After running `\dt` the list of tables should be displayed in the console, which means that you have successfully set it up.

---

### Azure functions

For local development:
- Make sure that the local.settings.json file is updated appropriately.
Then via command line:
> func start

For deployment to Azure:
- You can use the command line or the VS Code extension for that. Refer to the [documentation](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=csharp) for more info.
- Make sure to deploy both Azure Function Apps appropriately (PowerShell and JavaScript) to their respective Azure resource (i.e. `fa-<your_project_name>-ps-prod` and `fa-<your_project_name>-js-prod`)

## Working locally 

- There is not emulator at the moment, so the deployed Service bus queue in Azure will have to be used instead.
- To run the azure function api, Azure storage emulator needs to be running.
https://docs.microsoft.com/en-us/azure/storage/common/storage-use-emulator

For each Azure Function app, make sure that the `local.settings.json` files are updated with their respective data.

- Run gatsby (port 8000)
  > cd gatsby-swa  
  > gatsby develop  

- Run azure function api (port 7071)
  > cd gatsby-swa/api  
  > func start

- Run time-triggered azure function api (port 7072)
  > cd azure-functions/javascript  
  > func start

- Run umami/postgresql (port 3000)
  > docker-compose up -d

*NB: For local development, the `./azure-functions/powershell` does not need to be run as they relate only to deployed Azure resources, however if you want to perform some tests against those, just make sure to have the right configuration in the `local.settings.json`.*


## Deployed environment

Just make sure that all the steps above have been done, and there should be nothing else to do. By default the time trigger for the Azure function to forward the data from the queue to Umami is set like the following: 0 0 1 * * *, i.e every day at 1am.

## Pitfalls

Terraform: 

- Running the terrraform script on a turned off flexible PostgreSQL server throws a 500 from Terraform.  
The flexible PostgreSQL server must be started before hand.
- If the script fails retrieving the `azurerm_function_app_host_keys` this is a known bug from with Terraform.  Go to Azure portal and create an access key manually. This should generate all the default keys. Then re run the terraform script again.

## Issues / Suggestions
Please file issues or suggestions on the issues page on github, or even better, submit a pull request. Feedback is always welcome!

## Publication
The following [Medium post](https://clementjoye.medium.com/serverless-architecture-4-umami-analytics-in-a-serverless-architecture-with-azure-container-39354723c077) is related to this GitHub repo.

## License
Copyright © 2022-present Clément Joye

MIT