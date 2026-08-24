# 2026-08-24 - Windows Server license expiry caused planned host shutdowns

## Status

Partially mitigated. License-expiry shutdowns were confirmed from Windows event evidence. Long-term remediation requires an organization-authorized Windows Server license and a security review of any unapproved activation tooling.

## Scope and impact

A Windows Server Hyper-V host shut down during normal operation. Monitoring reported host unavailability and guest VM restarts while the host recovered.

## Confirmed evidence

Windows System Event ID 1074 identified `wlms.exe` as the process that initiated planned shutdowns. The event message stated that the Windows license period had expired.

This distinguishes those shutdowns from a crash or power loss: the shutdown was initiated by Windows licensing enforcement.

## Root cause

The confirmed shutdowns occurred because the Windows Server installation reached license expiry.

## Important boundary

Earlier Kernel-Power and unexpected-shutdown events were observed before the first confirmed license-enforcement event. They remain a separate investigation; the license finding must not be used to close power, hardware, or operating-system fault analysis prematurely.

## Response

1. Restored host and guest availability.
2. Preserved System event evidence before changing licensing state.
3. Verified the operating-system edition and activation state.
4. Documented that production systems must use an authorized Retail, MAK, or organization KMS licensing path.
5. Added a follow-up to rotate privileged credentials and review any unapproved activation software or persistence mechanisms.

## Verification

After remediation, verify the Windows license state with `slmgr.vbs /dlv` and `slmgr.vbs /xpr`, then observe the host for renewed Event ID 1074 and unexpected restart events.

## Lessons learned

- Windows licensing is an availability dependency for server workloads.
- Event ID 1074 provides decisive evidence for planned shutdowns and should be captured before remediation.
- Guest agent alerts describe the blast radius; they are not necessarily the root cause.
- Separate confirmed causes from concurrent, unresolved infrastructure signals.
- Public incident documentation must omit host identifiers, product keys, credentials, and activation endpoints.
