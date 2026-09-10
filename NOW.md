# NOW.md (optional handoff note)

Goal: Close the Windows shim/catalog pack improvement after a focused diff review.

State: Review corrections landed (shim Start failure, foreign leftover keep, no bak overwrite, SKIP_LIVE checkout banner, grep status 0/1/error). Live ~/.cursor not updated.
Evidence: windows_host 14/0; install_lifecycle 51/0 including DOCTOR_SKIP_LIVE banners; `DOCTOR_SKIP_LIVE=1` doctor → CHECKOUT CHECKS PASSED, live not verified.
Next: Optional approved `Windows/install.ps1` to migrate live `now.pre-kleos-bak` out of the catalog. Do not FORCE-install without asking.
