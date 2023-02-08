# Azure Container Apps - multi-container communication

The following sample shows how to use Azure Container Apps where one container app will call another container app within the container app environment.  This is possible both with or without [Dapr](https://dapr.io).  This lab will not include Dapr.  

The `nodeApp` (container-1-node) is an express.js API that will call a `/hello` endpoint.  This route will call the `dotnetApp` (container-2-dotnet) to return a message.  
  
You will be using the [`with-fqdn`](./with-fqdn) folder. 
## Deploy and Run

### Deploy via Azure CLI
To begin the deployment process, go to the 1.ACA_Intro\with-fqdn\deploy folder. See the README.md files within this folder for scripts to deploy lab files using the Azure CLI.