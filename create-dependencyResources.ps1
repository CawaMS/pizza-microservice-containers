#Run this script to update your container apps. Assuming steps in README are followed so:
# 1) Storage and Service bus dependencies, App Insights and Log Analytics workspaces are created.
# 2) dapr component files are configured

#Switch parameter
Param(
    [switch]$noAzureLogin
)

#Environment variables
$SUBSCRIPTION_ID=""
$RESOURCE_GROUP=""
$LOCATION=""
$SERVICEBUS_NAME=""
$VNET_NAME=""
$STORAGE_NAME=""
$LOGANALYTICS_WORKSPACE_NAME=""
$APPLICATIONINSIGHTS_NAME=""


#Connnect to an Azure subscription
if(!$noAzureLogin)
{
    az login
}
az account set --s $SUBSCRIPTION_ID

#Create resource group if doesn't exist
$rgCheck = az group exists --name $RESOURCE_GROUP
if ($rgCheck -eq "false")
{
    Write-Output "Creating resource group $RESOURCE_GROUP ..."
    az group create --name $RESOURCE_GROUP --location $LOCATION
}
else
{
    Write-Output "$RESOURCE_GROUP exists, skip creation"
}

#Create an Azure Service Bus with Standard sku or above. Create a Topic called order
az servicebus namespace create --name $SERVICEBUS_NAME --resource-group $RESOURCE_GROUP --sku Standard
az servicebus topic create --name "order" --namespace-name $SERVICEBUS_NAME --resource-group $RESOURCE_GROUP

##Create a VNET and a subnet within it 
##az network vnet create --name $VNET_NAME --resource-group $RESOURCE_GROUP --address-prefix 10.0.0.0/16  --subnet-name infrasubnet --subnet-prefix 10.0.0.0/23 --service-endpoints "Microsoft.Storage"
az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefixes 10.0.0.0/23 --name infrasubnet --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME  --service-endpoints "Microsoft.Storage"

#Create an Azure Storage account. Create a new blob container.
az storage account create --name $STORAGE_NAME --resource-group $RESOURCE_GROUP
az storage container create --name "pizzaorders" --account-name $STORAGE_NAME --public-access container
az storage account update --resource-group $RESOURCE_GROUP --name $STORAGE_NAME --default-action Deny
az storage account network-rule add --account-name $STORAGE_NAME --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --subnet infrasubnet

#Create Log Analytics workspace
az monitor log-analytics workspace create --resource-group $RESOURCE_GROUP --workspace-name $LOGANALYTICS_WORKSPACE_NAME
$LOGANALYTICS_JSON=az monitor log-analytics workspace list --resource-group $RESOURCE_GROUP --query "[?name=='$LOGANALYTICS_WORKSPACE_NAME']" | ConvertFrom-Json
$LOGANALYTICS_WORKSPACE_ID=$LOGANALYTICS_JSON.Id

#Create Application Insights
az extension add -n application-insights
az monitor app-insights component create --app $APPLICATIONINSIGHTS_NAME --location $LOCATION --resource-group $RESOURCE_GROUP --workspace $LOGANALYTICS_WORKSPACE_ID


