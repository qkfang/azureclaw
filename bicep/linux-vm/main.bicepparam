using './main.bicep'

// Provide your SSH public key here or pass it at deployment time:
//   az deployment group create ... --parameters main.bicepparam sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"

param location = 'westus2'
param vmSize = 'Standard_B2as_v2'
param osDiskSizeGb = 64
param adminUsername = 'openclaw'
// sshPublicKey must be supplied at deploy time – do NOT commit real keys.
