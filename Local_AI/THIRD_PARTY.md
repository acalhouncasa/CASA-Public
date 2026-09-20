# Third-party software

Talon does not replace these projects. The kit installs them from
their official sources (winget or publisher-signed installers you place in
`payload\`).

| Software | Publisher | License | Official source |
|---|---|---|---|
| VSCodium | VSCodium | MIT | https://github.com/VSCodium/vscodium |
| Ollama | Ollama | MIT | https://github.com/ollama/ollama |
| Cline | saoudrizwan / Cline | Apache-2.0 | https://open-vsx.org/extension/saoudrizwan/claude-dev |
| Python extension | Microsoft (Open VSX) | MIT | https://open-vsx.org/extension/ms-python/python |
| Ruff | Astral | MIT | https://open-vsx.org/extension/charliermarsh/ruff |
| SQLTools + SQLite | mtxr | MIT | https://open-vsx.org/extension/mtxr/sqltools |
| SQLTools MSSQL | mtxr | MIT | https://open-vsx.org/extension/mtxr/sqltools-driver-mssql |
| Jupyter | Microsoft (Open VSX) | MIT | https://open-vsx.org/extension/ms-toolsai/jupyter |

Models pulled with `ollama pull` have their own licenses (check the model page
on https://ollama.com/library before distributing weights to another agency).
