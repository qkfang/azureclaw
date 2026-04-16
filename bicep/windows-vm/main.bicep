// ---------------------------------------------------------------------------
// OpenClaw on Azure Windows 11 VM – Bicep template
// Deploys: a Windows 11 Pro VM with a public IP and NSG allowing RDP.
// After deployment, use the companion PowerShell script (via az vm run-command
// or RDP) to install dependencies and OpenClaw.
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = resourceGroup().location

// --- Naming ------------------------------------------------------------------
@description('Virtual machine name.')
param vmName string = 'win11-openclaw-vm'

@description('Network security group name.')
param nsgName string = 'nsg-openclaw-win'

@description('Virtual network name.')
param vnetName string = 'vnet-openclaw-win'

@description('Subnet name.')
param subnetName string = 'snet-openclaw-win'

@description('Public IP name.')
param publicIpName string = 'pip-openclaw-win'

// --- Networking --------------------------------------------------------------
@description('VNet address space.')
param vnetPrefix string = '10.50.0.0/16'

@description('Subnet prefix.')
param subnetPrefix string = '10.50.1.0/24'

// --- VM ----------------------------------------------------------------------
@description('VM size SKU.')
param vmSize string = 'Standard_B2s'

@description('Admin username.')
param adminUsername string

@description('Admin password (must meet Azure complexity requirements).')
@secure()
param adminPassword string

// =============================================================================
// Network Security Group – allow RDP
// =============================================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// =============================================================================
// Virtual Network + Subnet
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
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Public IP
// =============================================================================
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// =============================================================================
// Network Interface
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
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Windows 11 Pro Virtual Machine
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
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
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
// Outputs
// =============================================================================
output vmName string = vm.name
output publicIpAddress string = publicIp.properties.ipAddress
output adminUsername string = adminUsername
