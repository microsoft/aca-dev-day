# Calling with FQDN

You can call the dotnet-app from the node-app by calling it's FQDN. Even though we use the FQDN, **calls within the environment will stay within the environment and network traffic will not leave**. Code snippet (do not run)

```js
const dotnetFQDN = process.env.DOTNET_FQDN;
// ...
var data = await axios.get(`http://${dotnetFQDN}`);
res.send(`${JSON.stringify(data.data)}`);
```

## Deploy with CLI

```bash
# Login to the CLI
RESOURCE_GROUP="aca-lab1-rg"
LOCATION="eastus"
ENVIRONMENT="lab1-env"

az login

# Add the container apps extension
az extension add \
  --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.0-py2.py3-none-any.whl

# Make sure the Microsoft.Web namespace is registered
az provider register --namespace Microsoft.Web

# Create a resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create a log analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOCATION

# Get the log analytics workspace client ID and secret to use next
LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n 'logs-for-lab1' --out tsv`
LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n 'logs-for-lab1' --out tsv`

# Create a container app environment
az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
  --location $LOCATION

# Deploy the container-2-dotnet dotnet-app
az containerapp create \
  --name dotnet-app \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image 'ghcr.io/azure-samples/container-apps-connect-multiple-apps/dotnet:main' \
  --target-port 80 \
  --ingress 'internal'

DOTNET_FQDN=$(az containerapp show \
  --resource-group $RESOURCE_GROUP \
  --name dotnet-app \
  --query configuration.ingress.fqdn -o tsv)

# Deploy the container-1-node node-app
az containerapp create \
  --name node-app \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image 'ghcr.io/azure-samples/container-apps-connect-multiple-apps/node:main' \
  --target-port 3000 \
  --ingress 'external' \
  --environment-variables DOTNET_FQDN=$DOTNET_FQDN \
  --query configuration.ingress.fqdn
```

