@description('The location to deploy our resources to. Default is the location of the resource group')
param location string = resourceGroup().location

@description('The random suffix for our application resources')
param applicationName string = uniqueString(resourceGroup().id)

@description('The name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string = 'law${applicationName}'

@description('The name of the Container App Environment')
param containerEnvironmentName string = 'env${applicationName}'

@description('The name of the storage account')
param storageAccountName string = 'stor${replace(applicationName, '-', '')}'

@description('The name of the load testing service')
param loadTestServiceName string = 'loadtest${applicationName}'

var tags = {
  Environment: 'Production'
  Owner: 'larrywa'
}
var queueName = 'test-queue'
var httpAppName = 'httpscaler'
var queueAppName = 'queuereader'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2022-05-01' = {
  name: 'default'
  parent: storageAccount
}

resource storageQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-05-01' = {
  name: queueName
  parent: queueServices
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
   retentionInDays: 30
   features: {
    searchVersion: 1
   }
   sku: {
    name: 'PerGB2018'
   } 
  }
}

resource env 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: containerEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource queueReader 'Microsoft.App/containerApps@2022-03-01' = {
  name: queueAppName
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-queuereader'
          name: queueAppName
          env: [
            {
              name: 'QueueName'
              value: storageQueue.name
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'myqueuerule'
            azureQueue: {
              queueName: storageQueue.name
              queueLength: 10
              auth: [
                {
                  secretRef: 'queueconnection'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource httpApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: httpAppName
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: true
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: httpAppName
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

resource loadTester 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: loadTestServiceName
  location: location
}
