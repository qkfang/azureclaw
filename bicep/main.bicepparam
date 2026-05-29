using './main.bicep'

// Supply adminPassword at deploy time – do NOT commit real passwords.
//   az deployment group create ... --parameters main.bicepparam adminPassword='<YourStrongPassword>'

param location = 'australiaeast'
param vmSize = 'Standard_D4s_v5'
param adminUsername = 'clawadmin'
param adminPassword = 'YourStr0ng!Passw0rd'
// adminPassword must be supplied at deploy time.
