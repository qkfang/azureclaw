// ---------------------------------------------------------------------------
// OpenClaw on Azure Linux VM – Bicep template
// Deploys: Resource Group networking (VNet, subnets, NSG), an Ubuntu 24.04
// VM with no public IP, and Azure Bastion (Standard SKU with tunneling) for
// secure SSH access.
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = resourceGroup().location

// --- Naming ------------------------------------------------------------------
@description('Virtual network name.')
param vnetName string = 'vnet-openclaw'

@description('VM subnet name.')
param vmSubnetName string = 'snet-openclaw-vm'

@description('Network security group name.')
param nsgName string = 'nsg-openclaw-vm'

@description('Virtual machine name.')
param vmName string = 'vm-openclaw'

@description('Azure Bastion host name.')
param bastionName string = 'bas-openclaw'

@description('Bastion public IP name.')
param bastionPipName string = 'pip-openclaw-bastion'

// --- Networking --------------------------------------------------------------
@description('VNet address space.')
param vnetPrefix string = '10.40.0.0/16'

@description('VM subnet prefix.')
param vmSubnetPrefix string = '10.40.2.0/24'

@description('Bastion subnet prefix (must be at least /26).')
param bastionSubnetPrefix string = '10.40.1.0/26'

// --- VM ----------------------------------------------------------------------
@description('VM size SKU.')
param vmSize string = 'Standard_B2as_v2'

@description('OS disk size in GB.')
param osDiskSizeGb int = 64

@description('Admin username for the VM.')
param adminUsername string = 'openclaw'

@description('SSH public key for VM authentication.')
@secure()
param sshPublicKey string

// =============================================================================
// Network Security Group
// =============================================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSshFromBastionSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyInternetSsh'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyVnetSsh'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// =============================================================================
// Virtual Network + Subnets
// =============================================================================
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet' // required name for Bastion
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// =============================================================================
// Network Interface (no public IP)
// =============================================================================
resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Ubuntu 24.04 LTS Virtual Machine
// =============================================================================
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGb
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// =============================================================================
// Azure Bastion (Standard SKU with tunneling)
// =============================================================================
resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionPip.id
          }
          subnet: {
            id: vnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================
output vmId string = vm.id
output vmName string = vm.name
output bastionName string = bastion.name
output adminUsername string = adminUsername
