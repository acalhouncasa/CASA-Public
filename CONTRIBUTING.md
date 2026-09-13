# Contributing

Thank you for using and improving material published by CASA-Trinity.

## How to use published items

1. Read the item’s `README.md` and [NOTICE.md](NOTICE.md).
2. Prefer a test environment before production when the item changes a live system.
3. Follow that item’s steps end to end (for SQL packages: F5 the whole file).

## Issues

Open an issue when:

- A published script or doc fails or is unclear.
- You have a portable improvement that helps other sites.

Do **not** include:

- Client names, chart IDs, or real clinical content
- Login names, passwords, or connection strings
- Internal CASA paths or private-repo dumps

## Pull requests

- Keep contributions **portable** and free of customer-specific secrets.
- One concern per PR.
- Say how you tested (test environment when applicable).

For SmartCare SQL packages: no `USE` of a customer database name, no named SQL logins, `ModifiedBy` from `SUSER_SNAME()` where applicable.

## Code of conduct

Be respectful. Harassment or PHI dumps will be removed and the account blocked.

## License

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).
