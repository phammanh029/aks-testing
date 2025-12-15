# aks-testing

# How to run
1. az login
2. `export TF_VAR_azure_subscription_id=$(az account show --query id -o tsv)`
3. terraform init
4. terraform plan
5. terraform apply