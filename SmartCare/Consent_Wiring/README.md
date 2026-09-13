# Consent wiring (method)

How consent documents usually hang together in SmartCare (high level):

| Piece | Role |
|-------|------|
| `DocumentCodes` | Consent document definition |
| Screens / banners | Where staff open it |
| Signature / versioning | Signed document versions |
| Revoke / replace | Site policy + product screens |

**Do not test in Prod.**

## What this pack does not include

Legal consent text, state-specific forms, or agency DocumentCode ids. Publish only after legal/compliance review for your site.

Prefer vendor guides for product UI. Keep custom wiring scripts private unless they are fully anonymized.
