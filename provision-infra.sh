while getopts l:n:e: flag
do
    case "${flag}" in
        l) location=${OPTARG};;
        n) name=${OPTARG};;
        e) env=${OPTARG};;
    esac
done

if [ -z "$location" ] || [ -z "$name" ] || [ -z "$env" ]; then
    echo "Missing arguments"
    echo "Usage ./provision-infra.sh -l <location> -n <name> -e <environment>"
    exit 1
fi

RESOURCE_GROUP="${name}-${env}-rg"
LOG_ANALYTICS_WORKSPACE="${name}-${env}-logs"
CONTAINER_APPS_ENV="${name}-${env}-env"
APP_NAME="${name}-${env}"

if [ $(az group exists --name $RESOURCE_GROUP) == false ]; then
    az group create --name $RESOURCE_GROUP --location $location
fi

LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'` &> /dev/null

if [ -z "$LOG_ANALYTICS_WORKSPACE_CLIENT_ID" ]; then 
    az monitor log-analytics workspace create \
        --resource-group $RESOURCE_GROUP \
        --workspace-name $LOG_ANALYTICS_WORKSPACE

    LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`
fi

LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`

CONTAINER_ENV=`az containerapp env show --name ${CONTAINER_APPS_ENV} --resource-group ${RESOURCE_GROUP} --query name -o tsv 2> /dev/null | tr -d '[:space:]'`

if [ -z "$CONTAINER_ENV" ]; then
    az containerapp env create \
    --name $CONTAINER_APPS_ENV \
    --resource-group $RESOURCE_GROUP \
    --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
    --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
    --location "$location" &> /dev/null
fi

CONTAINER_NAME=`az containerapp show --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --query name -o tsv 2> /dev/null | tr -d '[:space:]'`
echo "Test ${APP_NAME}"
if [ -z "$CONTAINER_NAME" ]; then
    az containerapp create \
    --image ghcr.io/tjololo/hello-go-web:v1.1.0 \
    --name ${APP_NAME} \
    --target-port 8080 \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINER_APPS_ENV \
    --min-replicas 0 \
    --ingress 'external' \
    --query configuration.ingress.fqdn
else
    az containerapp update \
    --image ghcr.io/tjololo/hello-go-web:v1.1.0 \
    --name ${APP_NAME} \
    --target-port 8080 \
    --resource-group $RESOURCE_GROUP \
    --min-replicas 0 \
    --ingress 'external' \
    --query configuration.ingress.fqdn
fi
