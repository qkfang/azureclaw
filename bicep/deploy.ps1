
az login --tenant 285f1bcc-8795-4823-b35e-c6f15d78e70b

az group create --name 'rg-azclaw' --location 'australiaeast'

az deployment group create --name 'az-claw-deploy' --resource-group 'rg-azclaw' --template-file './main.bicep' --parameters './main.bicepparam'

az deployment group create --name 'az-claw-deploy' --resource-group 'rg-azclaw' --template-file './main.bicep' --parameters './main.bicepparam' --mode Complete
