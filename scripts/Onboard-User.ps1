<#
Onboard-User.ps1  -  LAB SCRIPT for a Microsoft 365 test tenant.

Creates a new employee account, assigns a Microsoft 365 Business Premium licence,
and adds the user to security groups (which also brings the user into any Intune
and Conditional Access policies assigned to those groups).

Example:
  .\Onboard-User.ps1 -FirstName Frank -LastName Lee -Department Sales -Groups "Sales Team","Intune Test Users"

Needs: the Microsoft.Graph PowerShell module (Install-Module Microsoft.Graph -Scope CurrentUser)
#>

param(
    [Parameter(Mandatory = $true)] [string]$FirstName,
    [Parameter(Mandatory = $true)] [string]$LastName,
    [string]$Department = "Sales",
    [string[]]$Groups = @("Sales Team"),
    [string]$SkuPartNumber = "SPB",      # SPB = Microsoft 365 Business Premium
    [string]$UsageLocation = "CA",       # a usage location is required before a licence can be assigned
    [string]$TenantId = "yourtenant.onmicrosoft.com"   # your lab tenant, so you do not sign in to another organization
)

$ErrorActionPreference = "Stop"

# Keep a log of everything this script does (audit trail)
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir ("onboard_{0}{1}_{2}.log" -f $FirstName, $LastName, (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $logFile | Out-Null

try {
    # 1. Sign in to Microsoft Graph with only the permissions this script needs
    $scopes = @(
        "User.ReadWrite.All",
        "Group.ReadWrite.All",
        "Directory.ReadWrite.All",
        "RoleManagement.ReadWrite.Directory"   # needed to add members to role-assignable groups
    )
    Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome

    # 2. Build the username from the tenant's default domain, e.g. flee@yourtenant.onmicrosoft.com
    $domain = (Get-MgDomain | Where-Object { $_.IsDefault }).Id
    $alias  = ($FirstName.Substring(0, 1) + $LastName).ToLower()
    $upn    = "$alias@$domain"

    $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'"
    if ($existing) { throw "User $upn already exists. Nothing was changed." }

    # 3. Temporary password: upper case, lower case, digits and a symbol; must be changed at first sign-in
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
    $random = -join (1..10 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    $tempPassword = "Tmp!" + $random + "9a"

    # 4. Create the account
    $passwordProfile = @{
        Password                      = $tempPassword
        ForceChangePasswordNextSignIn = $true
    }
    $user = New-MgUser -DisplayName "$FirstName $LastName" `
                       -GivenName $FirstName `
                       -Surname $LastName `
                       -UserPrincipalName $upn `
                       -MailNickname $alias `
                       -Department $Department `
                       -UsageLocation $UsageLocation `
                       -PasswordProfile $passwordProfile `
                       -AccountEnabled
    Write-Host "[1/3] Account created: $upn" -ForegroundColor Green

    # 5. Assign the licence
    $sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber }
    if (-not $sku) { throw "Licence $SkuPartNumber was not found in this tenant." }
    Set-MgUserLicense -UserId $user.Id -AddLicenses @(@{ SkuId = $sku.SkuId }) -RemoveLicenses @() | Out-Null
    Write-Host "[2/3] Licence assigned: $SkuPartNumber" -ForegroundColor Green

    # 6. Add to groups
    foreach ($name in $Groups) {
        $group = Get-MgGroup -Filter "displayName eq '$name'" | Select-Object -First 1
        if (-not $group) {
            Write-Warning "Group '$name' was not found - skipped."
            continue
        }
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id
        Write-Host "[3/3] Added to group: $name" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Done. Username: $upn" -ForegroundColor Cyan
    Write-Host "Temporary password (LAB ONLY - in real work, send it to the manager through a secure channel): $tempPassword" -ForegroundColor Yellow
    Write-Host "Log file: $logFile"
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Stop-Transcript | Out-Null
}
