# Help Desk Lab: Microsoft 365, Entra ID and Intune

A hands-on lab covering the day-to-day work of an IT support team: managing users and access in Microsoft 365 and Entra ID, protecting devices and company data with Intune and Conditional Access, and automating onboarding and offboarding with PowerShell.

- **Environment:** Microsoft 365 Business Premium trial tenant, a Windows 11 PC and an iPhone.
- **All accounts are test accounts.** Personal details and tenant identifiers (account names, domains, IDs, IP addresses, passwords) are redacted in the screenshots.
- Companion project: [ServiceNow service desk lab](https://github.com/rhodesyang174-lab/network-lifecycle-lab)

The storyline: a small company. IT creates an employee's account on day one, secures sign-in and devices, protects company data on phones, and removes access on the last day.

## Repository contents
| Path | What it is |
|---|---|
| `README.md` | The build, step by step, with screenshots |
| [`scripts/`](scripts) | PowerShell onboarding and offboarding scripts |
| [`docs/SOPs.md`](docs/SOPs.md) | Procedures for 4 core workflows: new hire, daily compliance check, lost device, PC replacement |
| [`docs/autopilot-design.md`](docs/autopilot-design.md) | Autopilot zero-touch deployment design for the Hyper-V devices |
| [`docs/timing-method.md`](docs/timing-method.md) | How each SOP is timed, baseline vs improved |
| [`docs/failures.md`](docs/failures.md) | Problems hit during the build, causes and fixes |

---

## 1. Users, licences and groups
Created test users, assigned Microsoft 365 Business Premium licences, and added users to a security group. Groups drive everything else: policies are assigned to groups, so adding a user to a group brings in the right access.

![Active users](images/01-active-users.png)
![Security group members](images/02-security-group-members.png)

## 2. Least privilege for the help desk
Gave a user the **Helpdesk Administrator** role: enough to reset passwords for non-admin users, but not to change licences or other admins.

![Helpdesk Administrator role](images/03-helpdesk-admin-role.png)

## 3. Conditional Access: require MFA, test before enforcing
Replaced security defaults with a Conditional Access policy that requires MFA. I ran it in **Report-only** first and checked the sign-in log to see what it would do, then switched it **On**.

![Grant: require MFA](images/04-ca-mfa-grant.png)
![Report-only result in the sign-in log](images/05-ca-mfa-report-only-result.png)
![Policy switched on](images/06-ca-mfa-policy-on.png)

## 4. Offboarding by hand
Blocked sign-in for a departing user and removed the licence. (Later automated, see step 9.)

![Block sign-in](images/07-manual-offboarding-block-sign-in.png)
![Licence removed](images/08-manual-offboarding-licence-removed.png)

## 5. Exchange Online: shared mailbox and message trace
Created an **IT Support** shared mailbox (no licence needed) for two members, and used **Message trace** to confirm that a test email was delivered. This is the first check when someone says "I didn't get the email".

![Shared mailbox members](images/09-shared-mailbox-members.png)
![Message trace: Delivered](images/10-message-trace-delivered.png)

## 6. Intune: Windows compliance policy
A compliance policy that requires BitLocker, firewall, antivirus, Defender antimalware and a minimum Windows version (10.0.22631), assigned to a test group. A compliance policy only checks devices and marks them compliant or not. Blocking is done by Conditional Access (step 8).

![Compliance policy](images/11-intune-compliance-policy.png)
![Compliance policy assignment](images/12-intune-compliance-assignment.png)

## 7. Intune: app protection on a personal phone
An iOS app protection policy for Outlook and Teams: no backups of company data, no "save as", copy and paste only between managed apps, and a PIN to open the app. The phone was **not** enrolled. Only company data inside the apps is managed, which suits employees using their own phones.

Tested on my iPhone: Outlook required a PIN, and text copied from a company email could not be pasted into a personal notes app.

![App protection summary](images/13-app-protection-summary.png)
![Data protection settings](images/14-app-protection-data-settings.png)
![PIN required](images/15-iphone-pin-required.png)
![Paste blocked](images/16-iphone-paste-blocked.png)

## 8. Conditional Access: only compliant devices reach Office 365
A second policy for the test group: on Windows, Office 365 requires a device marked as compliant. My admin account was excluded so I could not lock myself out. My test PC isn't enrolled in Intune, so it can never be marked compliant. When the policy at first seemed not to apply, I tested in a fresh InPrivate window and with a "Block access" grant to confirm it was applied to the test user, and the sign-in was blocked (see [failures.md](docs/failures.md), item 2).

![Require compliant device](images/17-ca-require-compliant-device.png)
![Sign-in blocked](images/18-ca-sign-in-blocked.png)

## 9. Onboarding and offboarding with PowerShell
Two scripts using Microsoft Graph PowerShell (see [scripts](scripts)):
- **Onboarding:** create the account → assign the licence → add to groups (which brings in the Intune and Conditional Access policies).
- **Offboarding:** block sign-in → reset the password → revoke all sessions → (optional) convert the mailbox to shared for the manager → remove all group memberships → wipe Intune devices → remove the licence last.

Every run is logged.

![Onboarding script](images/19-powershell-onboarding.png)
![New user licensed](images/20-onboarded-user-licensed.png)
![Offboarding script](images/21-powershell-offboarding.png)
![User blocked after offboarding](images/22-offboarded-user-blocked.png)

## 10. Autopilot zero-touch deployment (design)
New devices are Hyper-V virtual machines that go from the first setup screen to a managed company device with no IT hands-on: the hardware hash is registered in Intune, a User-Driven deployment profile joins the device to Entra ID, and the Enrollment Status Page holds the user until three required apps are installed. In Intune the device then shows its primary user, corporate ownership and compliance state. Full design, build steps and troubleshooting order: [autopilot-design.md](docs/autopilot-design.md).

## 11. Standard operating procedures
Step-by-step procedures for the four workflows a small IT team runs most: [SOPs.md](docs/SOPs.md).
- **SOP-01** New hire setup
- **SOP-02** Daily compliance check
- **SOP-03** Lost device recovery
- **SOP-04** PC lifecycle replacement

Each procedure is timed, manual baseline vs improved (scripts, Autopilot, checklists), using [timing-method.md](docs/timing-method.md). Problems met during the build are recorded in [failures.md](docs/failures.md).

---

## Scripts

| Script | What it does |
|---|---|
| [`scripts/Onboard-User.ps1`](scripts/Onboard-User.ps1) | Creates a user, assigns a licence, adds groups |
| [`scripts/Offboard-User.ps1`](scripts/Offboard-User.ps1) | Blocks sign-in, resets the password, revokes sessions, optionally converts the mailbox to shared, removes groups, wipes devices, removes licences |

Requirements: Windows PowerShell 5.1 or PowerShell 7, and the Microsoft Graph module:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Examples (lab tenant only):
```powershell
.\Onboard-User.ps1 -FirstName Frank -LastName Lee -Groups "Sales Team","Intune Test Users" -TenantId yourtenant.onmicrosoft.com
.\Offboard-User.ps1 -UserPrincipalName flee@yourtenant.onmicrosoft.com -TenantId yourtenant.onmicrosoft.com
```

---

## What I learned
- **Groups are the control point.** Licences, Intune policies and Conditional Access are all assigned to groups, so onboarding and offboarding mostly mean adding a user to, or removing them from, the right groups.
- **Test before enforcing.** Report-only mode and the sign-in logs show who a Conditional Access policy would affect before it blocks anyone. Always exclude an admin account.
- **Compliance needs Conditional Access to have teeth.** Intune decides whether a device is compliant; Conditional Access decides whether that device gets in.
- **Offboarding order matters.** Block sign-in and revoke sessions first; remove the licence last, so the mailbox can be handed over first.
