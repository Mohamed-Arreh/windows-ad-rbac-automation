# IT Department Provisioning Script
# Creates and configures an IT department in lab.local

Import-Module ActiveDirectory

$Department = "IT"
$DomainDN = "DC=lab,DC=local"
$OUPath = "OU=" + $Department + "," + $DomainDN

$GlobalGroup = "GG_" + $Department + "_Users"
$PermissionGroup = "DL_" + $Department + "_Share_Modify"

$SharePath = "C:\Shares\" + $Department
$ShareName = 'IT$'
$TestUser = "alex.morgan"

Write-Host "Department: $Department"
Write-Host "OU path: $OUPath"
Write-Host "Employee group: $GlobalGroup"
Write-Host "Permission group: $PermissionGroup"
Write-Host "Share path: $SharePath"
Write-Host "Share name: $ShareName"
Write-Host "`nChecking organizational unit..."

if (-not (Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $Department -Path $DomainDN -ProtectedFromAccidentalDeletion $true
    Write-Host "Created OU: $Department" -ForegroundColor Green
}
else {
    Write-Host "OU already exists: $Department" -ForegroundColor Yellow
}

Write-Host "`nChecking employee group..."

if (-not (Get-ADGroup -Identity $GlobalGroup -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $GlobalGroup -SamAccountName $GlobalGroup -GroupScope Global -GroupCategory Security -Path $OUPath
    Write-Host "Created employee group: $GlobalGroup" -ForegroundColor Green
}
else {
    Write-Host "Employee group already exists: $GlobalGroup" -ForegroundColor Yellow
}

Write-Host "`nChecking permission group..."

if (-not (Get-ADGroup -Identity $PermissionGroup -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $PermissionGroup -SamAccountName $PermissionGroup -GroupScope DomainLocal -GroupCategory Security -Path $OUPath
    Write-Host "Created permission group: $PermissionGroup" -ForegroundColor Green
}
else {
    Write-Host "Permission group already exists: $PermissionGroup" -ForegroundColor Yellow
}

Write-Host "`nChecking test user..."

if (-not (Get-ADUser -Identity $TestUser -ErrorAction SilentlyContinue)) {
    $Password = Read-Host "Enter a temporary password for Alex Morgan" -AsSecureString

    New-ADUser `
        -Name "Alex Morgan" `
        -GivenName "Alex" `
        -Surname "Morgan" `
        -DisplayName "Alex Morgan" `
        -SamAccountName $TestUser `
        -UserPrincipalName "$TestUser@lab.local" `
        -Department $Department `
        -Title "IT Support Technician" `
        -Path $OUPath `
        -AccountPassword $Password `
        -Enabled $true `
        -ChangePasswordAtLogon $true

    Write-Host "Created test user: $TestUser" -ForegroundColor Green
}
else {
    Write-Host "Test user already exists: $TestUser" -ForegroundColor Yellow
}

Write-Host "`nChecking employee group membership..."

$UserMembership = Get-ADGroupMember -Identity $GlobalGroup |
    Where-Object { $_.SamAccountName -eq $TestUser }

if (-not $UserMembership) {
    Add-ADGroupMember -Identity $GlobalGroup -Members $TestUser
    Write-Host "Added $TestUser to $GlobalGroup" -ForegroundColor Green
}
else {
    Write-Host "$TestUser is already a member of $GlobalGroup" -ForegroundColor Yellow
}

Write-Host "`nChecking group nesting..."

$GroupNesting = Get-ADGroupMember -Identity $PermissionGroup |
    Where-Object { $_.SamAccountName -eq $GlobalGroup }

if (-not $GroupNesting) {
    Add-ADGroupMember -Identity $PermissionGroup -Members $GlobalGroup
    Write-Host "Nested $GlobalGroup inside $PermissionGroup" -ForegroundColor Green
}
else {
    Write-Host "$GlobalGroup is already inside $PermissionGroup" -ForegroundColor Yellow
}

Write-Host "`nChecking shared folder..."

if (-not (Test-Path -Path $SharePath)) {
    New-Item -Path $SharePath -ItemType Directory | Out-Null
    Write-Host "Created folder: $SharePath" -ForegroundColor Green
}
else {
    Write-Host "Folder already exists: $SharePath" -ForegroundColor Yellow
}
Write-Host "`nChecking SMB share..."

if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
    New-SmbShare `
        -Name $ShareName `
        -Path $SharePath `
        -ChangeAccess "LAB\$PermissionGroup" `
        -FullAccess "LAB\Domain Admins" `
        -Description "$Department departmental share" |
        Out-Null

    Write-Host "Created SMB share: $ShareName" -ForegroundColor Green
}
else {
    Write-Host "SMB share already exists: $ShareName" -ForegroundColor Yellow
}

Write-Host "`nChecking NTFS permissions..."

$NtfsPermission = (Get-Acl -Path $SharePath).Access |
    Where-Object {
        $_.IdentityReference -eq "LAB\$PermissionGroup" -and
        $_.FileSystemRights -match "Modify"
    }

if (-not $NtfsPermission) {
    $NtfsRule = "LAB\" + $PermissionGroup + ":(OI)(CI)M"
    icacls $SharePath /grant $NtfsRule | Out-Null
    Write-Host "Granted NTFS Modify permission to $PermissionGroup" -ForegroundColor Green
}
else {
    Write-Host "NTFS Modify permission already exists for $PermissionGroup" -ForegroundColor Yellow
}

Write-Host "`nChecking SMB share permissions..."

$PermissionAccount = "LAB\" + $PermissionGroup
$AdminAccount = "LAB\Domain Admins"
$ShareAccess = Get-SmbShareAccess -Name $ShareName

$ChangePermission = $ShareAccess |
    Where-Object {
        $_.AccountName -eq $PermissionAccount -and
        $_.AccessRight -eq "Change" -and
        $_.AccessControlType -eq "Allow"
    }

if (-not $ChangePermission) {
    Grant-SmbShareAccess -Name $ShareName -AccountName $PermissionAccount -AccessRight Change -Force |
        Out-Null

    Write-Host "Granted SMB Change access to $PermissionGroup" -ForegroundColor Green
}
else {
    Write-Host "SMB Change access already exists for $PermissionGroup" -ForegroundColor Yellow
}

$AdminPermission = $ShareAccess |
    Where-Object {
        $_.AccountName -eq $AdminAccount -and
        $_.AccessRight -eq "Full" -and
        $_.AccessControlType -eq "Allow"
    }

if (-not $AdminPermission) {
    Grant-SmbShareAccess -Name $ShareName -AccountName $AdminAccount -AccessRight Full -Force |
        Out-Null

    Write-Host "Granted SMB Full access to Domain Admins" -ForegroundColor Green
}
else {
    Write-Host "SMB Full access already exists for Domain Admins" -ForegroundColor Yellow
}

Write-Host "`nProvisioning check completed." -ForegroundColor Cyan
Write-Host "Access chain: $TestUser -> $GlobalGroup -> $PermissionGroup -> \\$env:COMPUTERNAME\$ShareName"

