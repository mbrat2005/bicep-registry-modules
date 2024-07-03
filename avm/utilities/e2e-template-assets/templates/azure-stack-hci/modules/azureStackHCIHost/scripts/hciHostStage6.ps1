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
  $location,

  [Parameter()]
  [String]
  $accountName,

  [Parameter()]
  [String]
  $adminUsername,

  [Parameter()]
  [String]
  $adminPw,

  [Parameter()]
  [String]
  $arcGatewayId,

  [Parameter()]
  [String]
  $domainOUPath = 'OU=HCI,DC=HCI,DC=local',

  [Parameter()]
  [string]
  $proxyServerEndpoint, #http://[Proxy_Server_Address]:[Proxy_Port],

  [parameter()]
  [string]
  $proxyBypassString #"localhost;127.0.0.1;*.contoso.com;node1;node2;192.168.1.*;s-cluster"
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
# we do this to support re-run of the template. If deployed, the HCI node password will be set to the password provided in the template, but future re-runs will generate a new password.
If (!(Test-Path -Path 'C:\temp\hciHostDeployAdminCred.xml')) {
  log "Exporting local '$($adminUsername)' credential (for re-use if script is re-run)..."
  $adminCred = [pscredential]::new($adminUsername, (ConvertTo-SecureString -AsPlainText -Force $adminPw))
  $adminCred | Export-Clixml -Path 'C:\temp\hciHostDeployAdminCred.xml'
} Else {
  log "Re-importing local '$($adminUsername)' credential..."
  $adminCredOld = Import-Clixml -Path 'C:\temp\hciHostDeployAdminCred.xml'

  $newCredFileName = 'hciHostDeployAdminCred_{0}.xml' -f (Get-Date -Format 'yyyyMMddHHmmss')
  log "Renaming the old credential file to '$newCredFileName' prevent overwriting..."
  Rename-Item -Path 'C:\temp\hciHostDeployAdminCred.xml' -NewName $newCredFileName

  log "Exporting local '$($adminUsername)' credential (for re-use if script is re-run)..."
  $adminCred = [pscredential]::new($adminUsername, (ConvertTo-SecureString -AsPlainText -Force $adminPw))
  $adminCred | Export-Clixml -Path 'C:\temp\hciHostDeployAdminCred.xml'
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
New-HciAdObjectsPreCreation -AzureStackLCMUserCredential $deployUserCred -AsHciOUName $domainOUPath

## set the LCM deployUser password to the adminPw value - this aligns the password with the KeyVault during re-runs
log 'Setting deployUser password...'
Set-AdAccountPassword -Identity 'deployUser' -NewPassword (ConvertTo-SecureString -AsPlainText -Force $adminPw) -Reset -Confirm:$false

# initialize arc on hci nodes
log 'Initializing Azure Arc on HCI nodes...'

# wait for VMs to reach 'Running' state
log 'Checking that VMs are running...'
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
  $VMs = Get-VM
  If ($adminCredOld) {
    log 'Using old local administrator credential from exported CliXML...'
    $localAdminCred = $adminCredOld
  } Else {
    log 'Using new local administrator credential from parameter input...'
    $localAdminCred = $adminCred
  }
  $sessions = New-PSSession -VMName $VMs.Name -Credential $localAdminCred -ErrorAction Stop

  log "Created '$(($sessions | Where-Object State -EQ 'Opened').Count)' PSSessions to HCI nodes [$($VMs.Name -join ',')]."
} catch {
  If ($_ -like '*The credential is invalid*') {
    log 'Failed to create PSSessions with "The credential is invalid" error. This is likely due to the password not matching the local administrator password on the HCI nodes. Retrying with the older passwords...'

    $credFiles = Get-ChildItem -Path 'C:\temp\*' -Include 'hciHostDeployAdminCred*.xml' -Exclude 'hciHostDeployAdminCred.xml'

    If ($credFiles.count -eq 0) {
      log 'No old credential files found. Exiting...'
      Write-Error 'No old credential files found. Exiting...'
      Exit 1
    }

    :retryCreds ForEach ($credFile in $credFiles) {
      log "Attempting login with credential file '$($credFile.name)'..."
      $localAdminCred = Import-Clixml -Path $credFile.FullName

      try {
        $sessions = New-PSSession -VMName $VMs.Name -Credential $localAdminCred -ErrorAction Stop

        If (($sessions | Where-Object State -EQ 'Opened').count -eq $VMs.Count) {
          log "Created '$(($sessions | Where-Object State -EQ 'Opened').Count)' PSSessions to HCI nodes [$($VMs.Name -join ',')]."
          break retryCreds
        }
      } catch {
        log "Failed to create PSSessions with credential file '$($credFile.name)'. Error: $_"
        continue
      } finally {
        If (($sessions | Where-Object State -EQ 'Opened').count -eq $VMs.Count) {
          log "Created '$(($sessions | Where-Object State -EQ 'Opened').Count)' PSSessions to HCI nodes [$($VMs.Name -join ',')]."
          $adminCredOld = $localAdminCred
        }
      }

    }
  } else {
    log "Failed to create PSSessions to HCI nodes [$($VMs.Name -join ',')]. $sessions $_ Exiting..."
    Write-Error "Failed to create PSSessions to HCI nodes [$($VMs.Name -join ',')]. $sessions $_ Exiting..."
    Exit 1
  }
}

# update local admin password to match the adminPw value
If ($adminCredOld) {
  log 'Updating local administrator password to match the adminPw value...'
  Invoke-Command -VMName (Get-VM).Name -Credential $adminCredOld {
    $ErrorActionPreference = 'Stop'

    $adminPw = $args[0]
    $adminUsername = $args[1]

    Write-Host "$($env:computerName):Setting local administrator password to match the adminPw value..."
    $adminCred = [pscredential]::new($adminUsername, (ConvertTo-SecureString -AsPlainText -Force $adminPw))
    Set-LocalUser -Name $adminUsername -Password $adminCred.Password -Confirm:$false
  } -ArgumentList $adminPw, $adminUsername
} Else {
  log "Password for '$($adminUsername)' should already match the adminPw value..."
}

# disable IPv6 on all HCI nodes
log 'Disabling IPv6 on HCI nodes...'
Invoke-Command -VMName (Get-VM).Name -Credential $adminCred {
  reg add hklm\system\currentcontrolset\services\tcpip6\parameters /v DisabledComponents /t REG_DWORD /d 0xFF /f
}

# set proxy settings if provided
if (![string]::IsNullOrEmpty($proxyServerEndpoint) -and ![string]::IsNullOrEmpty($proxyBypassString)) {
  log 'Both -proxyServerEndpoiint and -proxyBypassString passed, setting proxy settings...'
  log "Proxy Server Endpoint: $proxyServerEndpoint"
  log "Proxy Bypass String: $proxyBypassString"

  If ($proxyBypassString -eq 'GENERATE_PROXY_BYPASS_DYNAMICALLY') {
    log 'Generating proxy bypass string dynamically...'
    $proxyBypassString = '127.0.0.1;localhost;172.20.0.*;*.hci.local;hcicluster'
    For ($i = 1; $i -le (Get-VM).count; $i++) {
      $proxyBypassString += ";hcinode$i"
    }
  }

  $proxyConfigLogs = Invoke-Command -VMName (Get-VM).Name -Credential $adminCred {
    $ErrorActionPreference = 'Stop'

    $proxyServerEndpoint = $args[0]
    $proxyBypassString = $args[1]

    ## install winInetProxy module
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    If (!(Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) { Register-PSRepository -Default }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module WinInetProxy -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted

    ## set WinInet proxy settings
    Set-WinInetProxy -ProxyServer $proxyServerEndpoint -ProxyBypass $proxyBypassString -ProxySettingsPerUser 0

    ## set winhttp proxy settings
    Set-WinhttpProxy -ProxyServer $proxyServerEndpoint -BypassList $proxyBypassString

    ## set proxy environment variables
    $proxyBypassStringEnv = $proxyBypassString.replace(';', ',').replace('*', '').replace('172.20.0.*', '172.20.0.0/24')
    $proxyBypassStringEnv += ',.svc'

    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxyServerEndpoint, 'Machine')
    [Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxyServerEndpoint, 'Machine')
    [Environment]::SetEnvironmentVariable('NO_PROXY', $proxyBypassStringEnv, 'Machine')

    Write-Output "[$($env:COMPUTERNAME)] WinInetProxy Settings: $(Get-WinhttpProxy -Advanced)"
    Write-Output "[$($env:COMPUTERNAME)] WinhttpProxy Settings: $(Get-WinhttpProxy -Default)"
    Write-Output "[$($env:COMPUTERNAME)] Environment Variables: $(Get-ChildItem -Path env:*PROXY* | ConvertTo-Json -Compress)"

  } -ArgumentList $proxyServerEndpoint, $proxyBypassString

  $proxyConfigLogs | ForEach-Object {
    log $_
  }
} Else {
  log "Skipping proxy settings because both -proxyServerEndpoint and -proxyBypassString were not passed... (proxyServerEndpoint: '$proxyServerEndpoint', proxyBypassString:'$proxyBypassString')"
}

## test node internet connection - required for Azure Arc initialization
$firstVM = Get-VM | Select-Object -First 1
log "Testing node internet connection on VM '$($firstVM.Name)'..."
$testNodeInternetConnection = Invoke-Command -VMName $firstVM.Name -Credential $adminCred {
  [bool](Invoke-RestMethod ipinfo.io -UseBasicParsing)
}

If (!$testNodeInternetConnection) {
  log "Node '$($firstVM.name)' does not have internet connection. Check RRAS NAT configuration. Exiting..."
  Write-Error "Node '$($firstVM.name)' does not have internet connection. Check RRAS NAT configuration. Exiting..."
  Exit 1
} Else {
  log "Node '$($firstVM.name)' has internet connection. Curl IPInfo: '$($testNodeInternetConnection)'"
}

## create jobs for each node to initialize Azure Arc
log "Creating Azure Arc initialization jobs for HCI nodes [$((Get-VM).Name -join ',')]..."
$arcInitializationJobs = Invoke-Command -VMName (Get-VM).Name -Credential $adminCred {
  $ErrorActionPreference = 'Stop'

  $t = $args[0]
  $subscriptionId = $args[1]
  $resourceGroupName = $args[2]
  $tenantId = $args[3]
  $location = $args[4]
  $accountName = $args[5]
  $arcGatewayId = $args[6]
  $proxyServerEndpoint = $args[7]

  $optionalParameters = @{}

  If ($arcGatewayId) {
    $optionalParameters += @{
      'arcGatewayId' = $arcGatewayId
    }
  }
  If ($proxyServerEndpoint) {
    $optionalParameters += @{
      'proxy' = $proxyServerEndpoint
    }
  }

  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
  If (!(Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) { Register-PSRepository -Default }
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module Az.Resources, AzsHCI.ARCinstaller
  Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted

  try {
    Invoke-AzStackHciArcInitialization -SubscriptionID $subscriptionId -ResourceGroup $resourceGroupName -TenantID $tenantId -Cloud AzureCloud -AccountID $accountName -ArmAccessToken $t -Region $location @optionalParameters
  } catch {
    Write-Error $_
  }
} -AsJob -ArgumentList $t, $subscriptionId, $resourceGroupName, $tenantId, $location, $accountName, $arcGatewayId, $proxyServerEndpoint

log 'Waiting up to 30 minutes for Azure Arc initialization to complete on nodes...'

$arcInitializationJobs | Wait-Job -Timeout 1800

# check for failed arc initialization jobs
log 'Checking status of Azure Arc initialization jobs...'
$arcInitializationJobs | ForEach-Object {
  $job = $_
  Get-Job -Id $job.Id -IncludeChildJob | Receive-Job -ErrorAction SilentlyContinue | ForEach-Object {
    If ($_.Exception -or $_.state -eq 'Failed') {
      log "Azure Arc initialization failed on node '$($job.Location)' with error: $($_.Exception.Message)"
      Exit 1
    } Else {
      log "[$($job.ComputerName)] Job output: '$($_ | ConvertTo-Json -Compress)'"
    }
  }
}