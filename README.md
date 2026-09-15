# windows-ad-rbac-automation
PowerShell automation for Active Directory provisioning and role-based SMB access using the AGDLP model.


# Windows AD RBAC Automation Lab

A Windows Server lab demonstrating automated Active Directory provisioning and role-based access control for a departmental SMB file share.

## Project objective

The goal was to replace repetitive manual administration with a reusable PowerShell script that provisions and validates an IT department's identity and file-access structure.

The script is idempotent: it checks the current environment before making changes, allowing it to run repeatedly without duplicating existing objects.

## Lab environment

* Windows Server domain controller: `DC01`
* Active Directory domain: `lab.local`
* Domain-joined Windows client
* Active Directory Domain Services
* DNS and DHCP
* PowerShell
* SMB file sharing
* NTFS permissions

## Access-control design

The lab uses the AGDLP model:

```text
Account
   ↓
Global group
   ↓
Domain Local group
   ↓
Permission
```

Implemented access chain:

```text
alex.morgan
   ↓
GG_IT_Users
   ↓
DL_IT_Share_Modify
   ↓
\\DC01\IT$
```

`GG_IT_Users` represents the employees who belong to the IT department.
`DL_IT_Share_Modify` represents the Modify permission assigned to the IT departmental share.

This separates employee membership from resource permissions and makes access easier to manage and audit.

## Automated tasks

The PowerShell script checks, creates, or configures:

* IT organizational unit
* IT employee Global security group
* IT share Domain Local security group
* Test user account
* Employee group membership
* AGDLP group nesting
* Departmental folder
* Hidden SMB share
* SMB Change and administrative Full permissions
* NTFS Modify permission with file and folder inheritance

Passwords are not stored in the script. If the test account does not exist, PowerShell requests a temporary password as a secure string.

## Validation

Two domain-user tests were performed from the Windows client.

### Authorized test

The IT test user accessed:

```text
\\DC01\IT$
```

The user successfully created and saved `alex-access-test.txt`.

### Unauthorized test

A user who was not a member of the IT access groups attempted to open the same share and received an Access Denied response.

These tests confirmed both successful authorized access and enforcement of least-privilege restrictions.

## Script behavior

For each component, the script follows this pattern:

```text
Check whether the component exists
├── Missing: create or configure it
└── Existing: leave it unchanged and report its status
```

Status messages distinguish between newly created components and components that already satisfy the configuration.

## Repository structure

```text
windows-ad-rbac-automation/
├── README.md
└── scripts/
    └── Provision-ITDepartment.ps1
```

## Running the script

Run the script from an elevated PowerShell session on a domain controller with the Active Directory module installed:

```powershell
C:\LabScripts\Provision-ITDepartment.ps1
```

The script requires administrator privileges and the Active Directory PowerShell module.

## Skills demonstrated

* PowerShell scripting
* Idempotent administration
* Active Directory user and group management
* Organizational Unit design
* AGDLP group nesting
* Role-based access control
* SMB share administration
* Share and NTFS permission management
* Positive and negative access testing
* Technical validation and troubleshooting

## Security notes

* No passwords or credentials are stored in the repository.
* The share is hidden using the `$` suffix.
* Regular users receive Change/Modify access rather than Full Control.
* Domain administrators retain Full access.
* Unauthorized users are denied through the share-permission layer.

## Scope

This project was created in an isolated lab environment for learning and portfolio demonstration. Names, accounts, domain information, and infrastructure are fictional.
