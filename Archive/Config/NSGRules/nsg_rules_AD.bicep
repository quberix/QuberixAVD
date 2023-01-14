//Defines the NSG rules for a typical VM based Ad server

var adSnetStandardInboundRules = [
  {
    name: 'AllowRPCEndpointMapperInbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '135'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowLDAPInbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '389'
        '636'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 130
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowGlobalCatalogueInbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRanges: [
        '3268'
        '3269'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 140
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowKerberosInbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '88'
        '464'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 150
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowDNSInbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '53'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 160
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowSMBInbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '445'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 170
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowW32TimeInbound'
    properties: {
      protocol: 'UDP'
      sourcePortRange: '*'
      destinationPortRange: '123'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 180
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowRDPInbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 200
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

var adSnetStandardOutboundRules = [
  {
    name: 'AllowRDPOutbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 200
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowKMSOutbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '1688'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 210
      direction: 'Outbound'
    }
  }
]

output inbound array = adSnetStandardInboundRules
output outbound array = adSnetStandardOutboundRules
