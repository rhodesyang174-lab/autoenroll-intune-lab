# Timing Method: Baseline vs Improved

How each SOP is measured, to show whether automation makes it faster.

## Method
1. **Baseline:** run the SOP by hand (clicking in the portals), 5 times.
2. **Improved:** run it with the improvement, 5 times.
   - SOP-01 New hire: `Onboard-User.ps1` instead of manual account, licence and group setup; Autopilot instead of manual laptop setup.
   - SOP-02 Daily compliance check: saved filter on the noncompliant device report.
   - SOP-03 Lost device: steps done from one device page, using the SOP checklist.
   - SOP-04 PC replacement: Autopilot for the new device; checklist for the old one.
3. Record start and end time for each run, from ticket opened to ticket closed.
4. Compare the median of the baseline runs with the median of the improved runs. The median is used so one slow run does not distort the result.

## Log

| SOP | Run | Method | Start | End | Minutes | Notes |
|---|---|---|---|---|---|---|
| SOP-01 | 1 | Baseline | | | | |
| SOP-01 | 2 | Baseline | | | | |
| … | | | | | | |
| SOP-01 | 6 | Improved | | | | |

## Summary

| SOP | Baseline median (min) | Improved median (min) | Change |
|---|---|---|---|
| SOP-01 New hire setup | | | |
| SOP-02 Daily compliance check | | | |
| SOP-03 Lost device recovery | | | |
| SOP-04 PC lifecycle replacement | | | |
