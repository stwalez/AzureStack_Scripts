### Prerequisites

### Login Method 1
	# Register an Azure Resource Manager environment that targets your Azure Stack Hub instance. Get your Azure Resource Manager endpoint value from your service provider.
    Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint "https://adminmanagement.local.azurestack.external" `
      -AzureKeyVaultDnsSuffix adminvault.local.azurestack.external `
      -AzureKeyVaultServiceEndpointResourceId https://adminvault.local.azurestack.external

    # Set your tenant name.
    $AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackAdmin").ActiveDirectoryAuthority.TrimEnd('/')
    $AADTenantName = "<myDirectoryTenantName>.onmicrosoft.com"
    $TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

    # After signing in to your environment, Azure Stack Hub cmdlets
    # can be easily targeted at your Azure Stack Hub instance.
    Add-AzureRmAccount -EnvironmentName "AzureStackAdmin" -TenantId $TenantId


### Login Method 2
	#Login to an Azure-linked Azure stack admin
	Add-AzureRmAccount

	#Switch Context to Azure stack
	Get-AzureRmContext -ListAvailable | Where-Object Environment -like AzureStackAdmin | Select-AzureRmContext

## Create the following variables

$customer_name = "Company"
$rg_name = "ASDK-01"
$location = "local"
$customer_onmicrosoft_domain_name = "<myDirectoryTenantName>.onmicrosoft.com"
$customer_global_admin = "admin@<myDirectoryTenantName>.onmicrosoft.com"

#Compute Quota variables
$compute_quota_name = "$customer_name-Comp01"

### Fill the Compute values below
$vmcount = 2
$vmcores = 4
$avsetcount = 2
$vmss = 2
$smd_plussnapshots = 1024
$pmd_plussnapshots = 0

#Network Quota variables
$network_quota_name = "$customer_name-Net01"

### Fill the Network values below
$vnet_count = 1
$vgw_count = 0
$net_con_count = 0
$pub_ips_count = 1
$nics_count = 2
$lb_count = 1
$nsg_count = 2

#Storage Quota variables
$storage_quota_name = "$customer_name-Stor01"

### Fill the Storage values below
$blob_storage_size = 1024
$storage_account_count = 1

#Plan variables
$plan_display_name = "$customer_name-plan"
$plan_resource_name = $plan_display_name.ToLower()
$plan_desc = "Iaas Provisioning for $customer_name"

#Offer variables
$offer_display_name = "$customer_name-offer"
$offer_resource_name = $offer_display_name.ToLower()
$offer_desc = "Offer for $customer_name"

#User subscription variables
$customer_tenantId = (Get-AzsDirectoryTenant -Name $customer_onmicrosoft_domain_name).TenantId
$user_subscription_display_name = "$customer_name-Azs01-Sub01"


#Create Quotas
$compute_quota = New-AzsComputeQuota -Name $compute_quota_name -AvailabilitySetCount $avsetcount -CoresCount $vmcores -VmScaleSetCount $vmss `
                    -VirtualMachineCount $vmcount -StandardManagedDiskAndSnapshotSize $smd_plussnapshots -PremiumManagedDiskAndSnapshotSize $pmd_plussnapshots


$network_quota  = New-AzsNetworkQuota -Name $network_quota_name -MaxNicsPerSubscription $nics_count -MaxPublicIpsPerSubscription $pub_ips_count `
					-MaxVirtualNetworkGatewayConnectionsPerSubscription $net_con_count -MaxVnetsPerSubscription $vnet_count -MaxVirtualNetworkGatewaysPerSubscription $vgw_count -MaxSecurityGroupsPerSubscription $nsg_count -MaxLoadBalancersPerSubscription $lb_count


$storage_quota = New-AzsStorageQuota -Name $storage_quota_name -CapacityInGb $blob_storage_size -NumberOfStorageAccounts $storage_account_count

#Link Quotas in an array
$quota_ids = $compute_quota.Id, $network_quota.id ,$storage_quota.Id

#Create a Plan
$new_plan = New-AzsPlan -Name $plan_resource_name -ResourceGroupName $rg_name -DisplayName $plan_display_name -QuotaIds $quota_ids -Location $location `
            -Description $plan_desc
			
#Create an Offer
$new_offer = New-AzsOffer -Name $offer_resource_name -ResourceGroupName $rg_name -DisplayName $offer_display_name -BasePlanIds $new_plan.Id -Description $offer_desc

#Create a User Subscription
$new_user_subscription = New-AzsUserSubscription -Owner $customer_global_admin -OfferId $new_offer.Id `
                            -TenantId $customer_tenantId -DisplayName $user_subscription_display_name
#Verify New User subscription
$new_user_subscription



## Remove the Subscription, Offer, Plan and Quotas
#Remove User Subscription
Remove-AzsUserSubscription -SubscriptionId $new_user_subscription.SubscriptionId -Force

# Remove Offer
Start-Sleep -Seconds 60
Remove-AzsOffer -Name $new_offer.Name -ResourceGroupName $rg_name -Force

# Remove Plan
Start-Sleep -Seconds 30
Remove-AzsPlan -Name $new_plan.Name -ResourceGroupName $rg_name -Force

# Remove Respective Quotas
Remove-AzsComputeQuota -Name $compute_quota.Name -Force
Remove-AzsNetworkQuota -Name $network_quota.Name -Force
Remove-AzsStorageQuota -Name $storage_quota.Name -Force