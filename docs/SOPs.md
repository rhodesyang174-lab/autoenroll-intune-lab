# Standard Operating Procedures

Four core IT support workflows for the lab company. Each SOP lists the steps in order, where each step is done, and the step that must not be skipped (marked **Critical**).

Portals used:
- **M365 admin center:** admin.microsoft.com
- **Entra admin center:** entra.microsoft.com
- **Intune admin center:** intune.microsoft.com
- **ServiceNow:** the service desk instance

---

## SOP-01: New hire setup

**Trigger:** HR sends the new hire's details (name, department, manager, start date, access needed).
**Goal:** On day one, the employee can sign in, use Outlook and Teams, and work on a compliant laptop.

| # | Step | Where | Notes |
|---|---|---|---|
| 1 | Open a request ticket with the HR details | ServiceNow | One ticket per new hire |
| 2 | Create the account, assign the licence, add the department groups | `Onboard-User.ps1`, or M365 admin center → Users → Add a user | Groups bring in the Intune and Conditional Access policies |
| 3 | Prepare the laptop: register it for Autopilot | Intune → Devices → Enrollment → Windows Autopilot | See [autopilot-design.md](autopilot-design.md) |
| 4 | **Critical:** Day one, the employee signs in, changes the temporary password and registers MFA | Employee's laptop and phone (Microsoft Authenticator) | Without MFA, the MFA Conditional Access policy blocks sign-in |
| 5 | Check: laptop compliant, Outlook and Teams work, app protection active on the phone | Intune → Devices; quick test with the employee | |
| 6 | Close the ticket and record the time taken | ServiceNow | |

## SOP-02: Daily compliance check

**Trigger:** Every morning.
**Goal:** No user is suddenly blocked from email because their device fell out of compliance.

| # | Step | Where | Notes |
|---|---|---|---|
| 1 | Open the list of non-compliant devices | Intune → Devices → Monitor → Noncompliant devices | |
| 2 | Open each device and find the failing setting | Device → Device compliance | BitLocker off, OS too old, antivirus off, firewall off |
| 3 | Fix what can be fixed remotely: sync, push updates | Intune → device → Sync | |
| 4 | **Critical:** For anything not fixed remotely, contact the user and open a ticket | ServiceNow | Otherwise Conditional Access will block the user without warning |
| 5 | Log the count, causes and outcomes | Daily log | The same cause repeating → open a problem record to find the root cause |

## SOP-03: Lost device recovery

**Trigger:** An employee reports a lost or stolen laptop or phone.
**Goal:** Company data is protected within minutes, and the employee is back at work quickly.

| # | Step | Where | Notes |
|---|---|---|---|
| 1 | **Critical:** Verify the caller's identity, then open a high-priority ticket | ServiceNow | Call back on the registered number; attackers impersonate employees |
| 2 | Remote lock the device | Intune → device → Remote lock | |
| 3 | Revoke all sessions and reset the password | Entra → Users → Revoke sessions; M365 admin center → Reset password | Blocking new sign-ins alone does not end existing sessions |
| 4 | Company device: Wipe. Personal phone: remove company data only | Intune → Wipe; Apps → App selective wipe | |
| 5 | Record the serial number and notify the security team | Asset record, ticket | BitLocker means the disk cannot be read without the key |
| 6 | Issue a replacement (SOP-01 steps 3–5) and close the ticket | | |

## SOP-04: PC lifecycle replacement

**Trigger:** A laptop reaches end of life or fails.
**Goal:** The employee moves to a new laptop with no lost files, and the old one is safely retired.

| # | Step | Where | Notes |
|---|---|---|---|
| 1 | Open a request ticket and book a time with the employee | ServiceNow | |
| 2 | **Critical:** Confirm all files are synced to OneDrive | Employee's old laptop | Skipping this loses the employee's files |
| 3 | New laptop through Autopilot; employee signs in; check apps and compliance | See [autopilot-design.md](autopilot-design.md) | |
| 4 | Old laptop: Wipe, then delete it from Intune and from Autopilot devices | Intune → Wipe → Delete; Windows Autopilot → Devices → Delete | Otherwise it re-enrolls as a company device |
| 5 | Update the asset record | Asset record | Serial number, new owner, old device reused or disposed |
| 6 | Close the ticket and record the time taken | ServiceNow | |

---

Time taken for each run is recorded with the method in [timing-method.md](timing-method.md). Problems hit along the way go in [failures.md](failures.md).
