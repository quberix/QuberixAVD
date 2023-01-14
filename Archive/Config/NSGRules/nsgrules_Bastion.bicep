//Defines the NSG rules for a typical Bastion

var bastionSnetStandardInboundRules = [
  {
    name: 'AllowHttpsInbound'
    properties: {
      description: 'Permit access from the Internet to the Bastion service'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowGatewayManagerInbound'
    properties: {
      description: 'Permit access from the Gateway Manager to the Bastion service'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'GatewayManager'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 130
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowAzureLoadBalancerInbound'
    properties: {
      description: 'Permit access from the Azure Load Balancer to the Bastion service'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 140
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowBastionHostCommunicationInbound'
    properties: {
      description: 'Permit access from the Azure Load Balancer to the Bastion service'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRanges: [
        '8080'
        '5701'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 150
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyAllInbound'
    properties: {
      description: 'Deny all rule across all ports, addresses and protocols'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 900
      direction: 'Inbound'
    }
  }
]

var bastionSnetStandardOutboundRules = [
  {
    name: 'AllowSshRdpOutbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '22'
        '3389'
      ]
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 120
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowAzureCloudOutbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureCloud'
      access: 'Allow'
      priority: 130
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowBastionCommunicationOutbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '8080'
        '5701'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 140
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowGetSessionInformationOutbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Internet'
      access: 'Allow'
      priority: 150
      direction: 'Outbound'
    }
  }
  {
    name: 'DenyAllOutbound'
    properties: {
      description: 'Deny all rule across all ports, addresses and protocols'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 900
      direction: 'Outbound'
    }
  }
]

output inbound array = bastionSnetStandardInboundRules
output outbound array = bastionSnetStandardOutboundRules
output all array = union(bastionSnetStandardInboundRules,bastionSnetStandardOutboundRules)
