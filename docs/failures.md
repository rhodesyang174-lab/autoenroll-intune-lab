# Failures and Fixes

Problems I hit while building this lab, what caused them, and how I fixed them. Each one is something a help desk can meet in real work.

---

### 1. PowerShell sign-in went to the wrong organization (AADSTS50105)
- **Symptom:** `Connect-MgGraph` failed with AADSTS50105: the signed-in user is not assigned to a role for the application.
- **Cause:** Windows signed me in silently with my school account (Web Account Manager), so the script tried to connect to the school's tenant, not the lab tenant.
- **Fix:** Added `-TenantId` to `Connect-MgGraph` so the script always targets the lab tenant, and chose "Work or school account" and the lab admin in the sign-in window.
- **Lesson:** Always pin the tenant in admin scripts. On a shared or personal PC, the cached account may not be the one you expect.

### 2. Conditional Access policy did not block the test user
- **Symptom:** After creating the "require compliant device" policy, the test user could still open Outlook on the web.
- **Cause 1:** The browser still had the user's earlier session. Conditional Access is evaluated at sign-in, so an existing session is not re-checked straight away.
- **Cause 2:** The grant was set to "Grant access" with no control ticked, which adds no requirement.
- **Fix:** Tested in a new InPrivate window, ticked "Require device to be marked as compliant", and confirmed the policy was On, not Report-only. To confirm the policy was being applied to the user, I also tested it with a "Block access" grant.
- **Lesson:** Test Conditional Access in a fresh private window, and read the sign-in log (Conditional Access tab) to see which policy applied and why.

### 3. Message trace showed no results
- **Symptom:** A test email could not be found in Message trace.
- **Cause:** Message trace times are in UTC. Kitchener is 4–5 hours behind, so my time range missed the message.
- **Fix:** Widened the time range and searched again; the message showed as Delivered.
- **Lesson:** When a user says "I sent it at 3 pm", convert to UTC or search a wider window.

### 4. "Save copies of org data" was greyed out in the app protection policy
- **Symptom:** The setting could not be changed.
- **Cause:** It depends on "Send org data to other apps". It only becomes available when that setting is not "All apps".
- **Fix:** Set "Send org data to other apps" to "Policy managed apps", then set "Save copies of org data" to Block.
- **Lesson:** In Intune, a greyed-out setting usually depends on another setting above it.

### 5. Conditional Access could not be created while security defaults were on
- **Symptom:** Conditional Access policies could not be turned on.
- **Cause:** Security defaults and Conditional Access cannot be used together.
- **Fix:** Turned off security defaults (Entra → Overview → Properties → Manage security defaults), then created the MFA policy, first in Report-only.
- **Lesson:** Replace security defaults with an equivalent MFA policy straight away, so there is no gap.

### 6. Scripts would not run
- **Symptom:** PowerShell refused to run the downloaded `.ps1` files.
- **Cause:** The execution policy and the "downloaded from the internet" mark on the files.
- **Fix:** `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then `Unblock-File` on each script.
- **Lesson:** Change the policy only for the current user, not the whole machine.

### 7. Sign-in errors met during MFA testing
| Code | Meaning | What the help desk does |
|---|---|---|
| 50055 | Password expired | User resets the password (or the help desk does) |
| 50072 | User must register MFA | Walk the user through Microsoft Authenticator setup |
| 50140 | "Stay signed in?" prompt interrupted sign-in | Normal; not an error for the user |
| 53000 | Device not compliant | Check the device in Intune and fix the failing setting |
| 53003 | Blocked by Conditional Access | Check which policy applied in the sign-in log |
