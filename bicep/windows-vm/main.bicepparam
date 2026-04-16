using './main.bicep'

// Supply adminPassword at deploy time – do NOT commit real passwords.
//   az deployment group create ... --parameters main.bicepparam adminPassword='<YourStrongPassword>'

param location = 'westus2'
param vmSize = 'Standard_B2s'
param adminUsername = 'clawadmin'
// adminPassword must be supplied at deploy time.
