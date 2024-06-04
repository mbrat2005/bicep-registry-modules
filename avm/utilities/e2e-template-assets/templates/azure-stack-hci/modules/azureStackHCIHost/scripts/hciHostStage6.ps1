[CmdletBinding()]
param (
  [Parameter()]
  [String]
  $resourceGroupName,

  [Parameter()]
  [String]
  $subscriptionId,

  [Parameter()]
  [String]
  $tenantId,

  [Parameter()]
  [String]
  $location = 'eastus',

  [Parameter()]
  [String]
  $accountName,

  [Parameter()]
  [String]
  $adminUsername,

  [Parameter()]
  [String]
  $adminPw
)

Function log {
  Param (
    [string]$message,
    [string]$logPath = 'C:\temp\hciHostDeploy.log'
  )

  If (!(Test-Path -Path C:\temp)) {
    New-Item -Path C:\temp -ItemType Directory
  }

  Write-Host $message
  Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
}

$ErrorActionPreference = 'Stop'

# export or re-import local administrator credential
If (!(Test-Path -Path 'C:\temp\hciHostDeployAdminCred.xml')) {
  log 'Exporting local administrator credential (for re-use if script is re-run)...'
  $adminCred = [pscredential]::new($adminUsername, (ConvertTo-SecureString -AsPlainText -Force $adminPw))
  $adminCred | Export-Clixml -Path 'C:\temp\hciHostDeployAdminCred.xml'
} Else {
  log 'Re-importing local administrator credential...'
  $adminCred = Import-Clixml -Path 'C:\temp\hciHostDeployAdminCred.xml'
}

# get an access token for the VM MSI, which has been granted rights and will be used for the HCI Arc Initialization
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
  -Headers @{Metadata = 'true' } `
  -UseBasicParsing
$content = $response.Content | ConvertFrom-Json
$t = $content.access_token

# pre-create AD objects
log 'Pre-creating AD objects...'
$deployUserCred = [pscredential]::new('deployUser', (ConvertTo-SecureString -AsPlainText -Force $adminPw))

If (!(Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) { Register-PSRepository -Default }
If (!(Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction SilentlyContinue)) { Install-PackageProvider -Name NuGet -Confirm:$false -Force }
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module AsHciADArtifactsPreCreationTool
New-HciAdObjectsPreCreation -AzureStackLCMUserCredential $deployUserCred -AsHciOUName 'ou=hci,dc=hci,dc=local'

# initialize arc on hci nodes
log 'Initializing Azure Arc on HCI nodes...'
$cred = [pscredential]::new('administrator', (ConvertTo-SecureString -AsPlainText -Force $adminPw))

# wait for VMs to reach 'Running' state
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ((Get-VM | Where-Object State -NE 'Running') -and $stopwatch.Elapsed.TotalMinutes -lt 15) {
  log "Waiting for HCI node VMs to reach 'Running' state. Current state: $((Get-VM) | Select-Object Name,State)..."
  Start-Sleep -Seconds 30
}

If ($stopwatch.Elapsed.TotalMinutes -ge 15) {
  log "HCI node VMs did not reach 'Running' state within 15 minutes. Exiting..."
  Write-Error "HCI node VMs did not reach 'Running' state within 15 minutes. Exiting..."
  Exit 1
}

log "Creating PSSessions to HCI nodes [$((Get-VM).Name -join ',')]..."
try {
  $sessions = New-PSSession -VMName (Get-VM).Name -Credential $cred -ErrorAction Stop

  if ($sessions.Count -eq 2 -and $sessions.State -eq 'Opened') {
    log "PSSessions to HCI nodes [$((Get-VM).Name -join ',')] created successfully."
  } else {
    log "Failed to create PSSessions to HCI nodes [$((Get-VM).Name -join ',')]. Exiting..."
    Write-Error "Failed to create PSSessions to HCI nodes [$((Get-VM).Name -join ',')]. Exiting..."
    Exit 1
  }
} catch {
  log "Failed to create PSSessions to HCI nodes [$((Get-VM).Name -join ',')]. $_ Exiting..."
  Write-Error "Failed to create PSSessions to HCI nodes [$((Get-VM).Name -join ',')]. $_ Exiting..."
  Exit 1
}

# name net adapters
log 'Renaming network adapters on HCI nodes...'
Invoke-Command $sessions {
  $ErrorActionPreference = 'Stop'

  Get-NetAdapter | Where-Object { $_.Name -like 'Ethernet*' } | ForEach-Object {
    $adapter = $_
    $newAdapterName = Get-NetAdapterAdvancedProperty -RegistryKeyword HyperVNetworkAdapterName -Name $adapter.Name | Select-Object -ExpandProperty DisplayValue

    If ($adapter.InterfaceAlias -ne $newAdapterName) {
      Write-Host "Renaming network adapter '$adapter.InterfaceAlias' to '$newAdapterName'..."
      Rename-NetAdapter -Name $adapter.Name -NewName $newAdapterName
    }
  }
}

## test node internet connection - required for Azure Arc initialization
$testNodeInternetConnection = Invoke-Command $sessions[0] {
  [bool](Invoke-RestMethod ipinfo.io -UseBasicParsing)
}

If (!$testNodeInternetConnection) {
  log "Node '$($sessions[0].ComputerName)' does not have internet connection. Check RRAS NAT configuration. Exiting..."
  Write-Error "Node '$($sessions[0].ComputerName)' does not have internet connection. Check RRAS NAT configuration. Exiting..."
  Exit 1
}

## create jobs for each node to initialize Azure Arc
$arcInitializationJobs = Invoke-Command $sessions {
  $ErrorActionPreference = 'Stop'

  $t = $args[0]
  $subscriptionId = $args[1]
  $resourceGroupName = $args[2]
  $tenantId = $args[3]
  $location = $args[4]
  $accountName = $args[5]

  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
  If (!(Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) { Register-PSRepository -Default }
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module Az.Resources, AzsHCI.ARCinstaller -Force
  Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted
  Invoke-AzStackHciArcInitialization -SubscriptionID $subscriptionId -ResourceGroup $resourceGroupName -TenantID $tenantId -Cloud AzureCloud -AccountID $accountName -ArmAccessToken $t -Region $location
} -AsJob -ArgumentList $t, $subscriptionId, $resourceGroupName, $tenantId, $location, $accountName

log 'Waiting up to 30 minutes for Azure Arc initialization to complete on nodes...'

$arcInitializationJobs | Wait-Job -Timeout 1800

# check for failed arc initialization jobs
$arcInitializationJobs | ForEach-Object {
  $job = $_
  Get-Job -Id $job.Id -IncludeChildJob | Receive-Job -ErrorAction SilentlyContinue | ForEach-Object {
    If ($_.Exception) {
      log "Azure Arc initialization failed on node '$($job.Location)' with error: $($_.Exception.Message)"
      Exit 1
    } Else {
      log "Job output: $_"
    }
  }
}
