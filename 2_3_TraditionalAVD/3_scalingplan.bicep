
// Deploys a traditional AVD soltion based on the image genersated in step 2.2
// this will build a number of hosts, add them to the domain and then create and add them to the host pool
// it will also create a scheduler to scale the solution up and down.

targetScope = 'subscription'

//Parameters
@allowed([
  'dev'
  'prod'
])
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@maxLength(4)
@description('Product Short Name e.g. QBX - no more than 4 characters')
param productShortName string

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  Product: productShortName
}

@description('The name of the resource group to create for the common image builder components')
param hostPoolRG string = toUpper('${productShortName}-RG-AVD-STD-${localenv}')

//LAW Resource Group name
@description ('The name of the Log Analytics Workspace Resource Group')
param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

//LAW workspace
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

//Host Pool parameters
@description('The name of the host pool')
param hostPoolName string = toLower('${productShortName}-HP-${localenv}')

@description('The name of the host pools scaling plan')
param hostPoolScalingPlanName string = toLower('${productShortName}-HP-SP-${localenv}')

@description('The friendly name of the host pool scaling plan')
param hostPoolScalingPlanFriendlyName string = '${productShortName}-ScalingPlan-${localenv}'

@description('The type of the host pool to deploy')
param hostPoolType string = 'Pooled'

@description('Whether to enable the scaling plan by default or not')
param enableScalingPlan bool = true

//Remember schedules use Percentages rather than host/user counts - so 20 will be 20% of the host pools maximum capacity
//This example is for a 5 day week, 9-5, 20% ramp up (from 8), 60% peak, ramp down to 10% (from 5pm), 90% off peak (from 8pm)
//Autoscale will also override a number og hostpool settings such as the local-balancing algorithm
//For more information please see this: https://learn.microsoft.com/en-us/azure/virtual-desktop/autoscale-scenarios
@description('An example weekday schedule.  This can be repeated for multiple schedules.')
param hostPoolSchedules array = [
  {
    name: 'weekdays_schedule'
    daysOfWeek: [
      'Monday'
      'Tuesday'
      'Wednesday'
      'Thursday'
      'Friday'
    ]
    rampUpStartTime: {
        hour: 8
        minute: 0
    }
    peakStartTime: {
        hour: 9
        minute: 0
    }
    rampDownStartTime: {
        hour: 17
        minute: 0
    }
    offPeakStartTime: {
        hour: 18
        minute: 0
    }
    rampUpLoadBalancingAlgorithm: 'BreadthFirst' //Load balance across available hosts (ramp up time)
    rampUpMinimumHostsPct: 20       //This is the minimum number of hosts to be running at any time (during ramp up).  So if 10 hosts, 2 will be on (20%) at all times
    rampUpCapacityThresholdPct: 80  //This is the capacity of the host pool that will trigger the ramp up.  So 2 hosts with 5/users per host, at 6 users, another host will be started
    peakLoadBalancingAlgorithm: 'BreadthFirst'  //Local balance across available hosts (peak time)
    rampDownLoadBalancingAlgorithm: 'DepthFirst'  //Fill existing hosts to capacity before moving on to next host (ramp down time) - consolidation
    rampDownMinimumHostsPct: 0   //This is the minimum number of hosts to be running at any time (during ramp down).  In this case ramp down to Zero (i.e. zero during offpeak)
    rampDownCapacityThresholdPct: 90  //This is the capacity of the host pool that will trigger the ramp down.  So 2 hosts with 5/users per host, at 9 users, another host will be started (a high threshold to prevent additional hosts starting unneccessarily)
    rampDownForceLogoffUsers: false //This will force users to log off when the host pool is scaled down if set to true (if false, relies on user logoff or GPO logging them out)
    rampDownWaitTimeMinutes: 30  //How long the user is given before they are kicked out of the session
    rampDownNotificationMessage: 'You will be logged off in 30 min. Make sure to save your work.'  //The message the user will get
    rampDownStopHostsWhen: 'ZeroSessions'  //When to stop a host.  In this case when there are no users connected (zero sessions)
    offPeakLoadBalancingAlgorithm: 'DepthFirst'  //Fill existing hosts to capacity before moving on to next host (ramp down time) - consolidation

  }
  {
    name: 'weekend_schedule' //The weekend schedule will set everything to OFF and force logged on users to log off
    daysOfWeek: [
      'Saturday'
      'Sunday'
    ]
    rampUpStartTime: {
      hour: 0
      minute: 0
    }
    peakStartTime: {
        hour: 0
        minute: 1
    }
    rampDownStartTime: {
        hour: 0
        minute: 2
    }
    offPeakStartTime: {
        hour: 1
        minute: 0 
    }
    rampUpLoadBalancingAlgorithm: 'DepthFirst'
    rampUpMinimumHostsPct: 0      
    rampUpCapacityThresholdPct: 100
    peakLoadBalancingAlgorithm: 'DepthFirst'
    rampDownLoadBalancingAlgorithm: 'DepthFirst'
    rampDownMinimumHostsPct: 0
    rampDownCapacityThresholdPct: 100
    rampDownForceLogoffUsers: true
    rampDownWaitTimeMinutes: 30
    rampDownNotificationMessage: 'You will be logged off in 30 min. Make sure to save your work.'
    rampDownStopHostsWhen: 'ZeroSessions'
    offPeakLoadBalancingAlgorithm: 'DepthFirst'
  }
]

//RESOURCES
//Pull in the RG
resource RGAVDSTD 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hostPoolRG
}

//Retrieve the CORE Log Analytics workspace
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LAWorkspaceName
  scope: resourceGroup(RGLAW)
}

//Get the existing host pool
resource DesktopHostPool 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' existing = {
  name: hostPoolName
  scope: RGAVDSTD
}

//Create the Scaling Plan
module DesktopScalingPlan '../MSResourceModules/modules/Microsoft.DesktopVirtualization/scalingplans/deploy.bicep' = {
  name: 'DesktopScalingPlan'
  scope: RGAVDSTD
  params: {
    name: hostPoolScalingPlanName
    location: location
    tags: tags
    diagnosticWorkspaceId: LAWorkspace.id
    friendlyName: hostPoolScalingPlanFriendlyName
    hostPoolType: hostPoolType
    hostPoolReferences: [
      {
        hostPoolArmPath: DesktopHostPool.id
        scalingPlanEnabled: enableScalingPlan
      }
    ]
    timeZone: 'UTC'
    schedules: hostPoolSchedules
  }
}
