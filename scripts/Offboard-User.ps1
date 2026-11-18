<#
Offboard-User.ps1  -  LAB SCRIPT for a Microsoft 365 test tenant.

Offboards a departing employee in this order:
  1. Block sign-in
  2. Reset the password to a random one nobody knows
  3. Sign the user out of all sessions (revoke refresh tokens)
  4. Optional: convert the mailbox to a shared mailbox and give the manager access
  5. Remove the user from every group (this also takes the user out of group-targeted
     Conditional Access and Intune policies)
  6. Intune devices: list them, or wipe them with -WipeDevices,
     or delete the device records with -RemoveDeviceRecords (run that after the wipe has finished)
  7. Remove all licences (last, so the mailbox can be converted first)

Examples:
  .\Offboard-User.ps1 -UserPrincipalName flee@yourtenant.onmicrosoft.com
  .\Offboard-User.ps1 -UserPrincipalName flee@yourtenant.onmicrosoft.com -ManagerUpn amy@yourtenant.onmicrosoft.com
  .\Offboard-User.ps1 -UserPrincipalName amy@yourtenant.onmicrosoft.com -WipeDevices
  .\Offboard-User.ps1 -UserPrincipalName amy@yourtenant.onmicrosoft.com -RemoveDeviceRecords

Needs: Microsoft.Graph module; for -ManagerUpn also ExchangeOnlineManagement
       (Install-Module ExchangeOnlineManagement -Scope CurrentUser)
#>

param(
    [Parameter(Mandatory = $true)] [string]$UserPrincipalName,
    [string]$ManagerUpn,
    [switch]$WipeDevices,
    [switch]$RemoveDeviceRecords,
    [string]$TenantId = "yourtenant.onmicrosoft.com"   # your lab tenant, so you do not sign in to another organization
)

$ErrorActionPreference = "Stop"

$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$safeName = $UserPrincipalName.Split("@")[0]
$logFile = Join-Path $logDir ("offboard_{0}_{1}.log" -f $safeName, (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $logFile | Out-Null

try {
    $scopes = @(
        "User.ReadWrite.All",
        "Group.ReadWrite.All",
        "Directory.ReadWrite.All",
        "Directory.AccessAsUser.All",                           # needed to reset another user's password
        "RoleManagement.ReadWrite.Directory",                   # needed for role-assignable groups
        "DeviceManagementManagedDevices.ReadWrite.All",
        "DeviceManagementManagedDevices.PrivilegedOperations.All"   # needed to wipe devices
    )
    Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome

    $user = Get-MgUser -UserId $UserPrincipalName -Property "Id,DisplayName,UserPrincipalName,AccountEnabled"
    Write-Host "Offboarding $($user.DisplayName) <$($user.UserPrincipalName)>" -ForegroundColor Cyan

    # 1. Block sign-in
    Update-MgUser -UserId $user.Id -AccountEnabled:$false
    Write-Host "[1/7] Sign-in blocked" -ForegroundColor Green

    # 2. Reset the password
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
    $random = -join (1..16 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    $passwordProfile = @{
        Password                      = "Off!" + $random + "7z"
        ForceChangePasswordNextSignIn = $true
    }
    Update-MgUser -UserId $user.Id -PasswordProfile $passwordProfile
    Write-Host "[2/7] Password reset" -ForegroundColor Green

    # 3. Sign out of all sessions
    Revoke-MgUserSignInSession -UserId $user.Id | Out-Null
    Write-Host "[3/7] All sessions revoked" -ForegroundColor Green

    # 4. Optional: mailbox to shared + manager access (must happen BEFORE the licence is removed)
    if ($ManagerUpn) {
        Connect-ExchangeOnline -ShowBanner:$false
        Set-Mailbox -Identity $user.UserPrincipalName -Type Shared
        Add-MailboxPermission -Identity $user.UserPrincipalName -User $ManagerUpn -AccessRights FullAccess -InheritanceType All | Out-Null
        Write-Host "[4/7] Mailbox converted to shared; $ManagerUpn has full access" -ForegroundColor Green
    }
    else {
        Write-Host "[4/7] Mailbox step skipped (no -ManagerUpn given)" -ForegroundColor Yellow
    }

    # 5. Remove from all groups
    $memberships = Get-MgUserMemberOf -UserId $user.Id -All |
        Where-Object { $_.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group" }
    foreach ($group in $memberships) {
        $groupName = $group.AdditionalProperties["displayName"]
        try {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
            Write-Host "      removed from group: $groupName"
        }
        catch {
            Write-Warning "Could not remove from '$groupName' (dynamic group or missing permission): $($_.Exception.Message)"
        }
    }
    Write-Host "[5/7] Group memberships removed" -ForegroundColor Green

    # 6. Intune-managed devices
    $devices = @(Get-MgDeviceManagementManagedDevice -Filter "userPrincipalName eq '$($user.UserPrincipalName)'" -All)
    if ($devices.Count -eq 0) {
        Write-Host "[6/7] No Intune-managed devices for this user" -ForegroundColor Green
    }
    elseif ($RemoveDeviceRecords) {
        foreach ($device in $devices) {
            Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id
            Write-Host "      removed Intune record: $($device.DeviceName)"
        }
        Write-Host "[6/7] Device records removed from Intune" -ForegroundColor Green
    }
    elseif ($WipeDevices) {
        foreach ($device in $devices) {
            Clear-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id
            Write-Host "      wipe sent to: $($device.DeviceName) ($($device.OperatingSystem))"
        }
        Write-Host "[6/7] Wipe sent. When Intune shows the wipe as done, run again with -RemoveDeviceRecords" -ForegroundColor Green
    }
    else {
        foreach ($device in $devices) {
            Write-Host "      found: $($device.DeviceName) ($($device.OperatingSystem)), compliance: $($device.ComplianceState)"
        }
        Write-Host "[6/7] Devices listed only. Run again with -WipeDevices to wipe them" -ForegroundColor Yellow
    }

    # 7. Remove all licences
    $licences = @(Get-MgUserLicenseDetail -UserId $user.Id)
    if ($licences.Count -gt 0) {
        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses @($licences.SkuId) | Out-Null
        Write-Host "[7/7] Licences removed: $($licences.SkuPartNumber -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "[7/7] No licences to remove" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Offboarding finished. Log file: $logFile" -ForegroundColor Cyan
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Stop-Transcript | Out-Null
}
