# Contributing

Thank you for using and improving CASA-Trinity's public SmartCare packages.

## How to use a package

1. Read the package `README.md` and [NOTICE.md](NOTICE.md).
2. Open SSMS against a **Train** SmartCare database.
3. Run the apply script start to finish (F5). Do not run a highlighted section.
4. Smoke-test with fake staff, then decide whether your site will promote to production.

## Issues

Open an issue when:

- A script fails on a standard SmartCare database (include SQL Server / SmartCare version if you know it, and the **error text** only).
- The README is unclear.
- You have a portable improvement (naming, Screen 46 already wired, coexistence with another Appointments trigger).

Do **not** include:

- Client names, chart IDs, or real appointment subjects
- Server names or IPs that identify your agency if that is sensitive for you
- Login names or passwords

## Pull requests

- Keep scripts **portable**: no `USE` of a customer database name, no named SQL logins, `ModifiedBy` from `SUSER_SNAME()`.
- One concern per PR (docs, apply script, undo script).
- Match the existing SQL header block (author line may stay CASA-Trinity or add a co-author).
- Test on Train. Say so in the PR.

## Code of conduct

Be respectful. This is a small public repo for behavioral-health IT peers. Harassment or PHI dumps will be removed and the account blocked.

## License

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).
