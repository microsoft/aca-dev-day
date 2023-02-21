# Azure Container Apps - Multi-Container Communication

The following sample shows how to use Azure Container Apps where one container app will call another container app within the container app environment.  This is possible both with or without [Dapr](https://dapr.io).  This lab will not include Dapr.  

The `nodeApp` (container-1-node) is an express.js API that will call a `/hello` endpoint.  This route will call the `dotnetApp` (container-2-dotnet) to return a message.  
  
You will be using the [`with-fqdn`](./with-fqdn) folder. 
# Deploy and Run

## Calling with FQDN

You can call the dotnet-app from the node-app by calling it's FQDN. Even though we use the FQDN, **calls within the environment will stay within the environment and network traffic will not leave**. The code snippet below is a sample of what the Python code would look like (do not copy/paste)

```js
const dotnetFQDN = process.env.DOTNET_FQDN;
// ...
var data = await axios.get(`http://${dotnetFQDN}`);
res.send(`${JSON.stringify(data.data)}`);
```

## Deploy with the Azure CLI
Run the following code from your Cloud Shell environment.
```bash
# Setup your parameters
RESOURCE_GROUP="<resource-group-name>"
LOCATION="eastus"
ENVIRONMENT="lab1-env"
LOG_WORKSPACE="logs-for-lab1"
SUBSCRIPTION_ID="<your-Azure-subscription-id>"

# If you are using Cloud Shell, you don't need to log in to Azure,
# Cloud Shell automatically logs you in. Skip this step when using Cloud
# Shell
az login

# Although you may be logged in, if the login is associated with multiple
# Azure subscriptions, the Cloud Shell window won't know which subscription to
# use. Set the account you are going to use
az account set --subscription $SUBSCRIPTION_ID

# Add the container apps extension
az extension add \
  --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.0-py2.py3-none-any.whl

# Make sure you upgrade to the latest containerapp extention
az extension add --name containerapp --upgrade

# Make sure the Microsoft.App namespace is registered
az provider register --namespace Microsoft.App

# Register the provider for Log Analytics
az provider register --namespace Microsoft.OperationalInsights

# Create a resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create a log analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_WORKSPACE

# Get the log analytics workspace client ID and secret to use next
LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_WORKSPACE --out tsv`
LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_WORKSPACE --out tsv`

# Create a container app environment
az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
  --location $LOCATION

# Deploy the container-2-dotnet dotnet-app. Note that the ingress is internal
# meaning you can't reach this container app from outside the environment
az containerapp create \
  --name dotnet-app \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image 'ghcr.io/azure-samples/container-apps-connect-multiple-apps/dotnet:main' \
  --target-port 80 \
  --ingress 'internal'

# Get the FQDN of THE dotnet-app so that the Node
# front end knows where to call
DOTNET_FQDN=$(az containerapp show \
  --resource-group $RESOURCE_GROUP \
  --name dotnet-app \
  --query properties.configuration.ingress.fqdn -o tsv)

# Deploy the container-1-node node-app. Notice the ingress is external meaning
# you can call this container app from outside. Note that although this last 
# command may run quickly in the Cloud Shell, it may still take a few minutes
# before you can hit the front-end endpoint
az containerapp create \
  --name node-app \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image 'ghcr.io/azure-samples/container-apps-connect-multiple-apps/node:main' \
  --target-port 3000 \
  --ingress 'external' \
  --env-var DOTNET_FQDN=$DOTNET_FQDN \
  --query configuration.ingress.fqdn
```

### Run the application in the Azure Portal
1. If you don't already have the Azure portal open, log in to the Azure portal now.
2. Find the name of your resource group and click on the name.
3. In the resource group, click on the Container App named **'node-app'**.
 ![Alt text](./content/node-app.png) 

 4. When you click on 'node-app', you will be taken to the Overview page of the container app. You need to click on the **Application URL** which will take you into the front end node app, through the ingress to the container app UI.
 ![Alt text](./content/app-url.png)

5. You should now see the node app UI. Click on the **Say Hello to dotnetApp button**.

 ![Alt text](./content/node-app-ui.png)

 6. If your fully qualified domain name has been entered correctly into your environment variables, you should see the UI of the .Net 6 container app.

 ![Alt text](./content/dot-net-app-ui.png)