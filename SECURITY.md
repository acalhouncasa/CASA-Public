# Security policy

Treat every issue, screenshot, and pull request as **public**. Do not attach dumps or screen captures that show real clients or other protected information.

## Reporting a vulnerability

If something in this repository could leak data, bypass a control, or be unsafe to run as published:

1. Do **not** open a public issue with exploit detail or PHI.
2. Use GitHub **Private vulnerability reporting** on this repository (Security tab), or contact the maintainer through the GitHub profile for [acalhouncasa](https://github.com/acalhouncasa).
3. Include the file name and steps that stay free of PHI.

## What we will not accept

- Credentials or connection strings
- Production backups
- Client or patient identifiers

## Operational safety

Before applying a change from this repo:

- Confirm you are connected to the intended system.
- **Do not test in Prod.**
- Know the disable or undo path for that package (see its folder README).
