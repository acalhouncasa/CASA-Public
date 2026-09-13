# Notice

## Not a Streamline product

**SmartCare** is a product of Streamline Healthcare Solutions. CASA-Trinity is a SmartCare customer. This repository is **not** an official Streamline release, Help Center article, or Zendesk package. Streamline does not review or support these scripts.

Use vendor documentation for product questions. Use this repository only for CASA-Trinity's optional add-ons.

## Use in a live EHR

These scripts can create procedures, triggers, and configuration keys in a SmartCare database. They can block appointment saves.

- Run first on a **Train / test** database.
- Confirm the SSMS connection is the database you intend. Scripts in this repo do **not** include `USE` or a host-name guard.
- Keep a disable path (kill-switch key or DROP trigger) before you apply to production.
- Your organization is responsible for change control, backups, and user communication.

## No protected health information

Do not put client names, chart numbers, or other PHI in issues, pull requests, screenshots, or sample data. Use fake staff and test clients only.

## License

Code and documentation in this repository are under the [MIT License](LICENSE). The software is provided as-is, without warranty.
