# Container Apps Store Microservice with DAPR

This repository was created to help users deploy a microservice-based sample application to Azure Container Apps.

Azure Container Apps is a managed serverless container offering for building and deploying modern apps at scale. It enables developers to deploy containerized apps without managing container orchestration. This sample makes use of the Distributed Application Runtime (Dapr), which is integrated deeply into the container apps platform.

Dapr is a CNCF project that helps developers overcome the inherent challenges presented by distributed applications, such as state management and service invocation. Container Apps also provides a fully-managed integration with the Kubernetes Event Driven Autoscaler (KEDA). KEDA allows your containers to autoscale based on incoming events from external services such Azure Service Bus or Redis.

### Application Architecture
![](./content/daprlab-01.png)

There are three main microservices in the solution.

**Store API** (node-app)

The node-app is an express.js API that exposes three endpoints. / will return the primary index page, /order will return details on an order (retrieved from the order service), and /inventory will return details on an inventory item (retrieved from the inventory service).

**Order Service** (python-app)

The python-app is a Python flask app that will retrieve and store the state of orders. It uses Dapr state management to store the state of the orders. When deployed in Container Apps, Dapr is configured to point to an Azure Cosmos DB to back the state.

**Inventory Service** (go-app)

The go-app is a Go mux app that will retrieve and store the state of inventory. For this sample, the inventory service  just returns back a static value.

## Setup
1. Log into Azure and open the Cloud Shell. Add the Container Apps extension and finally, register the Container Apps Provider. Note that it may take a few minutes to register the provider.
```bash
# If you were not using Cloud Shell, you would need to log in to Azure via the Azure CLI
# az login
# Set the Azure subscription you are working with if you have more than one
az account set subscription <your-subscription-id>
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App

#Change your working folder to the lab folder
cd aca-dev-day/labs/3.ACA_and_Dapr
```

2. Next, setup the following environment variables
```bash
RG="acadevdays_rg"
LOCATION="eastus"
ACA_ENV="aca-dapr"
DBNAME="orderDB"
```

## Store API
Create the Store API microservice and Dapr module.
![](./content/daprlab-storeapi-1.png)

#### 1. Deploy API Service
```bash
az containerapp up \
--name store-api \
--source ./node-service \
--environment $ACA_ENV \
--location $LOCATION \
--resource-group $RG \
--env-vars INVENTORY_SERVICE_NAME=inventory-svc ORDER_SERVICE_NAME=order-svc DAPR_HTTP_PORT=3500 \
--ingress external 
```

#### 2. Enable Dapr
```bash
az containerapp dapr enable \
    -n store-api \
    -g $RG \
    --dapr-app-id store-api \
    --dapr-app-port 3000
```

#### 3. Configure Ingress
```bash
az containerapp ingress enable \
    -n store-api \
    -g $RG \
    --type external \
    --target-port 3000 \
    --transport auto --allow-insecure 
```

## Inventory Service
Create the Inventory microservice and Dapr module.
![](./content/daprlab-inventory.png)

#### 1. Deploy Inventory Service
```bash
az containerapp up \
  --name inventory-svc \
  --source ./go-service \
  --environment $ACA_ENV \
  --location $LOCATION \
  --resource-group $RG \
  --ingress internal
```

####2. Enable Dapr
```bash
az containerapp dapr enable \
    -n inventory-svc \
    -g $RG \
    --dapr-app-id inventory-svc \
    --dapr-app-port 8050
```

## Create the Cosmos Database
With the environment deployed, the next step is to deploy an Azure Cosmos Database that is used by Orders microservices to store data. 

![](./content/daprlab-cosmos.png)

#### 1. Create Cosmos DB Account 
Take note in the new few commands that you need to provide  **your initials** for the CosmosDB account name.
```bash
az cosmosdb create --name ordersaccount-<your-initials> --resource-group $RG 
```

#### 2. Create a database of type SQL API 
```bash
az cosmosdb sql database create \
--account-name ordersaccount-<your-initials> \
--resource-group $RG \
--name ordersDB
```

#### 3. Create orders collection
```bash
az cosmosdb sql container create \
--account-name ordersaccount-<your-initials> \
--resource-group $RG \
--database-name ordersDB \
--name orders \
--partition-key-path "/partitionKey" \
--throughput 400 
```

## Deploy Dapr Component for CosmosDB
Next, create a State Management Dapr component that will be used by the Orders microservice to store information about processed orders. 

### Create the Dapr storage component

#### 1. Get the URL parameter. 
> Save this information, you'll need it to update the YAML file 
```bash
az cosmosdb show -n ordersaccount-<your-initials> -g $RG --query documentEndpoint -o tsv
```

#### 2. Get the Cosmos Database  Key.  
> Save this information, you'll need it to update the YAML file 
```bash
az cosmosdb keys list -n ordersaccount-<your-initials> -g $RG --query primaryMasterKey -o tsv
```
#### 3. Update the Dapr component YAML file 
```bash
code ./cosmosdb.yaml
```
```yaml
componentType: state.azure.cosmosdb
version: v1
metadata:
  - name: url
    value: #<REPLACE-WITH-URL>
  - name: masterKey
    value: #<REPLACE-WITH-MASTER-KEY>
  - name: database
    value: ordersDB
  - name: collection
    value: orders
scopes:
  - order-svc
```

a. Replace ```#<REPLACE-WITH-URL>``` with the output from step 1 above.

b. Replace ```#<REPLACE-WITH-MASTER-KEY>``` with the output from step 2 above.

c. Save the file and close the editor.


#### 4. Deploy docker component 
```bash
az containerapp env dapr-component set \ 
    --name aca-dapr \
    -g $RG \
    --dapr-component-name orders \
    --yaml cosmosdb.yaml
```


## Deploy the Orders Service
![](./content/daprlab-orders.png)

1. Deploy Orders Service
```bash
az containerapp up \
  --name order-svc \
  --source ./python-service \
  --environment $ACA_ENV \
  --location $LOCATION \
  --resource-group $RG \
  --ingress internal \
  --target-port 5000
```

2. Enable Dapr
```bash
az containerapp dapr enable \
    -n order-svc \
    -g $RG \
    --dapr-app-id order-svc \
    --dapr-app-port 5000
```
