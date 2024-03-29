# A/B Testing your ASP.NET Core apps using Azure Container Apps

This lab exercise will have you use code from an Azure sample repository. The repository contains sample code on how to host a set of revisions for your application that have slight differences, which is useful for performing A/B tests on your site to see how users will respond to changes gradually. You will use Azure App Configuration to create feature flags, then the ASP.NET Core feature flags extensions to change how your app will look or operate when features are enabled or disabled.

With Azure Container Apps, you can create multiple revisions for each of your apps. When you put these pieces together, you can ship incremental features and bifurcate traffic so you understand how the changes will impact the app's usability before committing to the change. Then, if you find the change isn't delivering the desired impact for your customers, you can easily scale the "beta" revision back out again.

* **Frontend** - A front-end web app written using ASP.NET Core Blazor Server. This web app is decorated with feature flags
* **Monitoring** - A shared project that makes it simple to configure a .NET project with Application Insights monitoring.
* You'll also see a series of Azure Bicep templates and a GitHub Actions workflow file in the **Azure** and **.github** folders, respectively.

## What you'll learn

The primary purpose of this lab is for you to learn how to deploy a Container App application and environment via GitHub Actions or Bicep. As an addition benefit, this exercise will introduce you to a variety of concepts, with links to supporting documentation throughout the tutorial.

* [Azure Container Apps](https://docs.microsoft.com/azure/container-apps/overview) for hosting your app's container images.
* [GitHub Actions](https://github.com/features/actions) for creating CI/CD workflows to deploy your apps to Azure.
* [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)
* [Azure App Configuration](https://docs.microsoft.com/azure/azure-app-configuration/overview) for setting up feature flags to control the A/B test variance.
* [Kusto](https://docs.microsoft.com/azure/data-explorer/kusto/query/) for building custom queries against the events your A/B tests generate.
* [ASP.NET Core feature flags](https://docs.microsoft.com/azure/azure-app-configuration/use-feature-flags-dotnet-core?tabs=core5x), useful for when you want to test new features or bifurcate functionality for A/B tests.

## Prerequisites

You'll need an Azure subscription and a very small set of tools and skills to get started:

1. An Azure subscription. Sign up [for free](https://azure.microsoft.com/free/).
2. A GitHub account, with access to GitHub Actions.

## Topology diagram

![Application topology map.](docs/media/topology.png)

## Setup

By the end of this lab you'll have a single container app that has two revisions in which you can divide the load and do A/B testing. You will also have a few supporting resources and an App Configuration instance, which you can use to bifurcate feature settings by revision labels.

> Note: Remember to clean up or scale back your resources to save on compute costs.

1. Fork this repository (https://github.com/Azure-Samples/dotNET-Frontend-AB-Testing-on-Azure-Container-Apps) to your own GitHub organization. You will notice that when you fork the repo, the repo has some lab instructions. Please make sure you use THESE lab instructions instead. The lab instructions you are reading now has more notes, corrections and explanations.

## OPTION 1: Deploy via GitHub Actions

**Authenticate to Azure and configure the repository with a secret**

1. Create an Azure Service Principal using the Azure CLI.

    The Azure Service Principal will be used by the Github Action to install resources into your Azure environment. **NOTE: This step is only needed if you are deploying via Github Actions**

    From within Cloud Shell:

    ```bash
    # Get the current subscription ID
    subscriptionId=$(az account show --query id --output tsv)
    # Generate a randomized Service Principal Name
    spnName="spn-acadevday-lab2-"$RANDOM
    # Create a service principal named FeatureFlagsSample
    az ad sp create-for-rbac --sdk-auth --name $spnName --role contributor --scopes /subscriptions/$subscriptionId
    ```

2. Copy the JSON written to the screen to your clipboard.

    ```json
    {
      "clientId": "<your-generated-applicationId>",
      "clientSecret": "<your-generated-clientSecret>",
      "subscriptionId": "<your-Azure-subscriptionId>",
      "tenantId": "<your-Azure-TenantId>",
      "activeDirectoryEndpointUrl": "https://login.microsoftonline.com/",
      "resourceManagerEndpointUrl": "https://brazilus.management.azure.com",
      "activeDirectoryGraphResourceId": "https://graph.windows.net/",
      "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
      "galleryEndpointUrl": "https://gallery.azure.com",
      "managementEndpointUrl": "https://management.core.windows.net"
    }
    ```

3. Create a new GitHub secret in your forked repository named **`AzureSPN`**.

Select **`Settings | Secrets and variables | Actions | New repository secret`**
Set the `Name` to `AzureSPN` then paste the JSON returned from the previous Azure CLI output into the `Secret` field.
Once you've done this you'll see the secret in your fork of the repository.

   ![The AzureSPN secret in GitHub](docs/media/secrets.png)

> Note: Never save the JSON to disk, for it will enable anyone who obtains this JSON code to create or edit resources in your Azure subscription.

4. You need to make sure your repository is prepared to run workflows. Click on the `Actions` menu item and then select the `I understand my workflows, go ahead and enable them` button. If you do not see this button, your workflows are probably already enabled.

![Providing Workflow permission.](docs/media/workflowok.png)

5. The easiest way to deploy the code is to make a commit directly to your `main` branch. Navigate to your forked repositories root `.\github\workflows\deploy.yml` file in your browser and clicking the `Edit` button.

![Editing the deploy file.](docs/media/edit-button.png)

6. Change the name of the branch to **`main`** and provide a custom resource group name for the app, and then commit the change to the `main` branch. **TIP: Make sure your resource group name has only alpha numeric characters and 14 characters max** because its name will be used as the name of all resources, like an ACR and few other resources with more restrictive name constraints.

![Pushing a change to the deploy branch to trigger a build.](docs/media/resource-group.png)

7. Scroll further down in the `deploy.yaml` file to line 48. Change the `'az deployment...'` command line to :
```bash
az deployment group create --resource-group ${{ env.RESOURCE_GROUP_NAME }} --template-file './Azure/main.bicep' --debug
```

8. Click on the **`Start Commit`** button and then on the **'Commit Changes'** button. Once you do this, click on the `Actions` tab, and you'll see that the deployment CI/CD process has already started.
>NOTE: Some users have noticed that the first time they clicked on the Actions tab, they were required to approve that workflows can run. If you see this, the workflow will not run that you just submitted. You need to go back and modify the deploy.yaml file (change resource group name) and commit the changes again.

![CI/CD process beginning.](docs/media/build-started.png)

When you click into the workflow, you'll see that there are 3 phases the CI/CD will run through:

1. `provision` - the Azure resources will be created that eventually house your app.
2. `build` - the various .NET projects are build into containers and published into the Azure Container Registry instance created during provision.
3. `deploy` - once `build` completes, the images are in ACR, so the Azure Container Apps are updated to host the newly-published container images.

![CI/CD process running.](docs/media/build-running.png)After a few minutes, all three steps in the workflow will be completed, and each box in the workflow diagram will reflect success. If anything fails, you can click into the individual process step to see the detailed log output.

> Note: if you do see any failures or issues, please submit an Issue so we can update the sample. Likewise, if you have ideas that could make it better, feel free to submit a pull request.

![CI/CD process succeeded.](docs/media/all-green.png)

With the projects deployed to Azure, you can now test the app to make sure it works.

## Option 2: Deploy via Bicep

The Github Actions from Option 1 calls the `main.bicep` file in the Azure folder. If you aren't using Github Actions though, you still need to understand how to perform the deployment with Bicep. **If you have already performed the deployment with Github Actions, skip this section.**

1. The Linux VM you are using in the Azure portal already has the Azure CLI installed, and therefore has the Bicep tools installed. However, you may want to make sure you have the latest version of Bicep installed by running the following command in your Cloud Shell window.

```bash
az bicep upgrade
```

2. By now, you should have forked the repository over to your own GitHub account. In the Cloud Shell window, clone your repo by doing `'git clone your-repo-name'.git`.

3. From within Cloud Shell, go to the folder `/dotNET-Frontend-AB-Testing-on-Azure-Container-Apps/Azure`.

4. The first thing we need to do is create a resource group in the Azure subscription. Run the following code in the Cloud Shell window. You can decide the name of your resource group and location, ie, like `eastus`. **TIP: Make sure your resource group name is alpha-numeric characters only**

```bash
RESOURCE_GROUP="<your-resource-group-name>"
LOCATION="eastus"
SUBSCRIPTION_ID="<your-Azure-subscription-id>"

az account set --subscription $SUBSCRIPTION_ID

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

5. Change to the ./Azure folder.

6. Open the file `container_app.bicep` using the Cloud Shell editor.

7. On line 4, change the repositoryImage value to `'lwazuredocker/frontend:v1'`. Save the file in the editor and close the file.

8. Once you have confirmed that the resource group has been created in (via the Azure Portal), run this command in the Cloud Shell prompt.

```bash
az deployment group create --resource-group $RESOURCE_GROUP --template-file main.bicep
```

Notice that this command create a `deployment` using the Bicep file as a template for what to create in the deployment. The deployment process will take several minutes. Take a break!

## Did you succeed in deploying the ACA application to Azure?

The objective of this lab was to deploy the ACA application to Azure. This will take quite a few minutes. If you are able to click on the `frontend` Azure Container App and see a web page, then you have succeeded. The rest of the lab is just more experimentation with ASP.Net Feature flags and Revisions with ACA.

## Taking a quick look at the source code

This code (in your repositories FeatureFlagsWithContainerApps folder) is the result of the [Add feature flags to an ASP.NET Core](https://docs.microsoft.com/azure/azure-app-configuration/quickstart-feature-flag-aspnet-core?tabs=core6x%2Ccore5x) app article, which goes a bit more in-depth into the features of Azure App Configuration, so do check those resources out for more information later. For now, take note that there's one change in this repository's code from the original sample code. In `Controllers\BetaController`, the code from the original sample uses the `FeatureGate` attribute to disable a controller's action in the case that the feature is disabled. In this repository's code, that attribute has been commented out to show you a better way of handling this.

```csharp
public class BetaController : Controller
{
    private readonly IFeatureManager _featureManager;
    private readonly TelemetryClient _telemetryClient;

    public BetaController(IFeatureManagerSnapshot featureManager, TelemetryClient telemetryClient)
    {
        _featureManager = featureManager;
        _telemetryClient = telemetryClient;
    }

    //[FeatureGate(MyFeatureFlags.Beta)]
    public IActionResult Index()
    {
        _telemetryClient.TrackEvent("Beta Page Loaded");
        return View();
    }
}
```

This particular A/B test will be testing the percentage of times the additional navigation link is clicked when it is shown; if the `FeatureGate` attribute is left in, subsequent requests to the `/beta/index` endpoint might 404. Additionally, we've added application insights custom event tracking to the `Index` controller method. This way, each hit to the URL will be tracked with a custom Application Insights event. There's a corresponding Application Insights event in the `_Layout.cshtml` view:

```csharp
<feature name="Beta">
    <li class="nav-item">
    @{
        _telemetryClient.TrackEvent("Beta Menu Shown");
    }
<a class="nav-link text-dark" asp-area="" asp-controller="Beta" asp-action="Index">Beta</a>
    </li>
    </feature>
```

This razor code will also fire an event each time the beta menu item is shown. This way, we know how many opportunities users have to click the link, *and* how many times they actually do click the link and result in a hit on the `beta/index` controller code.

### Mapping configuration to feature enablement

We know the .NET code will be deployed as a container artifact, so the best presumption we can make that we'll have to customize the deployment and to enable or disable features is environment variables. Since top-level string variables in `appsettings.json` easily map to environment variables, you can set these for a Azure Container App using either Bicep, the Azure CLI, Visual Studio, or the Azure Portal. The code below has a `RevisionLabel` variable that maps to an Azure App Configuration feature flag.

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "ApplicationMapNodeName": "Frontend",
  "AllowedHosts": "*",
  "RevisionLabel": "BetaDisabled"
}
```

In the Azure App Configuration blade, however, you'll see that the `RevisionLabel` associated with the feature's <u>enablement</u> is `BetaEnabled`, not `BetaDisabled`, which is the default in the code.

> The idea here is that you need to *enable* the feature specifically. Any value in the configuration or environment variable <u>other than</u> `BetaEnabled` will result in the Beta menu item being invisible.

![The label that enables the beta feature in Azure App Configuration.](docs/media/app-config.png)

## Try the app in Azure

The `deploy` CI/CD process (and the Bicep process) creates a series of resources in your Azure subscription. These are used primarily for hosting the project code, but there's also a few additional resources that aid with monitoring and observing how the app is running in the deployed environment.

| Resource          | Resource Type                    | Purpose                                                      |
| ----------------- | -------------------------------- | ------------------------------------------------------------ |
| appconfig`suffix` | App Configuration                | Provides distributed configurability for your cloud-native apps, and enables feature flagging and enablement. |
| `prefix`ai        | Application Insights             | Enables telemetry and inside-out analysis of your application, provides views on custom events you fire during the application's execution, exception telemetry. |
| frontend          | Azure Container App              | Houses the .NET Blazor Server app representing the frontend of the app. |
| `prefix`env       | Azure Container Apps Environment | A compute environment in which your application's containers can run and communicate with one another internally. |
| `prefix`acr       | Azure Container Registry         | Where your container images are stored and deployed from whenever you create a new container app or container app revision. |
| `prefix`logs      | Log Analytics Workspace          | All `ILogger<T>` data you log within the application ends up being stored in this space, as well as system and console data emitted by the container images. |

Once the application code is deployed, the Azure resource group into which it is deployed looks something like this.

![Azure resources once the deployment process is complete.](docs/media/resources.png)

## Add a revision that enables the Beta feature

From looking at the code, you know that setting the `RevisionLabel` environment variable (or app setting) to `BetaEnabled` results in the beta menu feature being activated (100% of the time). Now, you'll create a new Azure Container App revision, and split traffic between the two revisions so you can track how many requests you have to the new feature once customers are given an opportunity to see the new feature. After the deployment, going to the `frontend` resource in the portal, you'll see 2 revisions, one of which is active.

![Initial revision map.](docs/media/starting-revisions.png)

The one receiving 0% of the traffic is the original image - the ACA Welcome Image - that's deployed when the container apps are first created. You can uncheck that one and save it, resulting in there being 1 active revision. The one receiving 100% of the traffic is our actual app's image. NOTE: If you performed your deployment via Bicep (Option 2), you will only see 1 revision.

1. Click the `Create new revision`

2. Select a revision to base this new revision on (the one that DOESN'T use the `latest` Image tag)

3. Set a `Name / suffix`. It is suggested to use the name **'beta-enabled'** to make it easier to keep track of which revision you are looking at.

4. Select the Container Image

5. Click `Edit`

![Edit the container.](docs/media/editcontainer2.png)

6. Scroll to the bottom

![Create a new revision.](docs/media/create-revision2.png)

7. Change the `RevisionLabel` from _`BetaDisabled`_ to **`BetaEnabled`**

8. Click the `Save` button

![Change environment value.](docs/media/changevalue.png)

9. Click the `Create` button to create the revision.

![Deploy new revision.](docs/media/deployNewRevision.png)

A few moments later the new revision will be created:

![Deploy new revision.](docs/media/multiActiveRevisions.png)

Make sure to set the revisions to have 50% traffic each. Anytime you make changes in the revision window, make sure you click the **Save** button!

![New revision.](docs/media/new-revision.png)

10. In your resource group, click on the container app `frontend`. As you continue to refresh the page, you will see the menu items at the top of the page change to show the **Beta** menu.

<!-- ![Request-by-request variation in the UX.](docs/media/ab-test.png) -->

![Request-by-request variation Standard.](docs/media/ab-test-standard.png)

![Request-by-request variation Beta.](docs/media/ab-test-beta.png)

## Monitoring

1. From your resource group, click on the Application Insights resource.
2. Click on the `Events` menu item.
3. Scroll down in the Events window and click on the **View More Insights** button.
4. Scroll farther down in the window and you will see `Event Statistics`.
5. As site visitors are shown the beta menu item, events are recorded in Application Insights, and when the page resulting on their click is loaded, a separate event is recorded. Since each event is recorded individually by Application Insights, you have a snapshot of the distribution of opportunities to how many successful requests are made as a result of the menu item.

![Default events snapshot.](docs/media/default-snapshot.png)

6. From the screenshot you'll see how clicking the ellipse (to the far right of the Event Statistics chart) results in being able to customize the query. A rather complex Kusto query is shown next, but you can distill the query down to whatever minute level of detail you're after, or even use Kusto's chart-rendering capabilities to show the opportunity-versus-success telemetry for the A/B test.

![feature-flags-logs](docs/media/feature-flags-logs.png)

## Summary

This sample shows you how you can couple the awesome programmatic features and extensions to ASP.NET Core that make it a fantastic option for building cloud-native apps, that are easy to monitor and perform automated deployments of whenever changes arise. We hope this sample provides you some visibility into how you can couple various Azure services together with .NET to gradually ease in features with careful A/B testing and analysis using existing tools and APIs.

> Note: Remember to clean up or scale back your resources to save on compute costs.
