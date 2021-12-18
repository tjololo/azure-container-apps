while getopts n:e: flag
do
    case "${flag}" in
        n) name=${OPTARG};;
        e) env=${OPTARG};;
    esac
done

if [ -z "$name" ] || [ -z "$env" ]; then
    echo "Missing arguments"
    echo "Usage ./provision-infra.sh -n <name> -e <environment>"
    exit 1
fi

az group delete --resource-group ${name}-${env}-rg