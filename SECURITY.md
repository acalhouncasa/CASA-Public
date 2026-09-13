# Security policy

## This is public EHR-adjacent SQL

Treat every issue, screenshot, and pull request as **public**. Do not attach database dumps, appointment lists, or screen captures that show real clients or staff calendars from production.

## Reporting a vulnerability

If a script in this repository could leak data, bypass a clinical control, or be unsafe to run as published:

1. Do **not** open a public issue with exploit detail or PHI.
2. Use GitHub **Private vulnerability reporting** on this repository (Security tab), or email the maintainer through the GitHub profile for [acalhouncasa](https://github.com/acalhouncasa).
3. Include the file name, environment type (Train vs Prod), and steps that stay free of PHI.

## What we will not accept

- Credentials, connection strings, or SQL logins
- Production backups
- Client or patient identifiers

## Operational safety

Before applying SQL from this repo:

- Confirm you are connected to the intended SmartCare database in SSMS.
- Prefer Train, then production under your change process.
- Know the kill-switch or DROP script for that package.
