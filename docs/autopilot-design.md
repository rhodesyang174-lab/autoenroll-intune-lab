# Autopilot Zero-Touch Deployment: Design

How a new Windows 11 laptop goes from out of the box to a ready, managed company device without IT touching it. The lab uses Hyper-V virtual machines in place of physical laptops.

> **Status:** This part is documented as a design and build plan. The screenshots in this repo cover the tenant, users, groups, Conditional Access, compliance, app protection and PowerShell steps.

---

## Goal
- An employee unboxes a laptop, connects to the internet and signs in with their work account.
- The device joins Entra ID, enrolls in Intune, receives policies and installs three required apps.
- The employee becomes the device's **primary user**, and the device appears in Intune as **corporate-owned** and **compliant**.

## Lab layout
| Item | Value |
|---|---|
| Hypervisor | Hyper-V on Windows 11 |
| Virtual machine | Generation 2, Secure Boot on, virtual TPM on, 4 GB RAM, 64 GB disk |
| OS | Windows 11 (out-of-box experience, not yet set up) |
| Users | 25 test users, grouped by department |
| Required apps | Microsoft 365 Apps, Company Portal, Microsoft Edge |

## Build steps
| # | Step | Where | Why |
|---|---|---|---|
| 1 | Create the VM with a virtual TPM and boot it to the first setup screen | Hyper-V Manager | Windows 11 needs TPM 2.0; Autopilot uses it to identify the device |
| 2 | Capture the hardware hash: `Shift+F10`, then `Install-Script Get-WindowsAutopilotInfo` and `Get-WindowsAutopilotInfo -Online` | VM command prompt | The hash is how Intune recognizes this device as a company device |
| 3 | Confirm the device appears in Windows Autopilot devices | Intune → Devices → Enrollment → Windows Autopilot → Devices | |
| 4 | Create a device group for Autopilot devices | Entra → Groups | The profile is assigned to a group |
| 5 | Create the deployment profile: User-Driven, Microsoft Entra joined, user account type Standard, skip privacy and licence pages | Intune → Windows Autopilot → Deployment profiles | Standard users cannot change system settings |
| 6 | Enable the Enrollment Status Page and require the three apps | Intune → Enrollment → Enrollment Status Page | The user cannot reach the desktop until required apps are installed |
| 7 | Assign the three apps as **Required** to the device group | Intune → Apps → Windows | |
| 8 | Reset the VM, sign in with a test user at the first screen | VM | This is what the employee does |
| 9 | Check the result | Intune → Devices → Windows | Primary user = the test user, ownership = Corporate, compliance = Compliant |

## How it connects to the rest of the lab
- The compliance policy (README step 6) checks the new device.
- The Conditional Access policy (README step 8) lets it reach Office 365 only once it is compliant.
- SOP-01 (new hire) and SOP-04 (PC replacement) both use this flow.

## Troubleshooting order
1. **Network:** Can the device reach the internet during setup?
2. **Registration:** Is the hardware hash in Autopilot devices, and is the device in the group the profile is assigned to?
3. **Profile:** Does the device show the profile as Assigned?
4. **Licence:** Does the user have an Intune licence?
5. **Enrollment Status Page:** Which app or policy is it stuck on, and what is the error code?
