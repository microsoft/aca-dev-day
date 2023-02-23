# Setup environment for the labs

Instructions to setup the environment for Azure Container Apps (ACA) labs

>Duration 20 minutes

## Task 1: Setup Cloud Shell

In this exercise you log into your Azure Subscription and launch the Bash [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview). The Azure Cloud Shell will give you a Linux shell prompt with all the required software installed and configured.

1. Log in to your Azure Subscription.

2. [Launch Cloud Shell](https://shell.azure.com/bash)

3. When you open Cloud Shell, you are already logged in to Azure. If this is your first time logging in to Cloud shell, you will need to create a storage account.

    a. Choose Bash shell

    ![Welcome Cloud Shell](content/image-1.png)

    2. Create Cloud Storage

    ![](content/image-2.png)

    ![](content/image-3.png "Azure Cloud Shell Bash prompt")
    >![](content/idea.png) Use ***shift+insert*** to paste the commands from this document into the cloud shell terminal

4. Although you are logged in to Azure, the Cloud Shell environment won't know which Azure subscription you want to use (if you have multiple subscriptions). Run the following command in Cloud Shell.

```bash
az account set --subscription <your-subscription-id>
```

## Task 2: Clone the Git repository into your Cloud Shell environment

Within your Cloud Shell window, running the following command in order to pull down the source code for the labs:
```bash
    git clone https://github.com/microsoft/aca-dev-day.git
    ls
```
You should see an **aca-dev-day** folder in your Cloud Shell window. Change to the labs folder:
```bash
    cd aca-dev-day/labs
```
