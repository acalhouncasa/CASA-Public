# Third-party software

Local Coder does not replace these projects. The toolkit installs them from
their official sources (winget, Open VSX, or publisher-signed files you place
in `payload\`).

| Software | Publisher | License | Official source |
|---|---|---|---|
| VSCodium | VSCodium | MIT | https://github.com/VSCodium/vscodium |
| Ollama | Ollama | MIT | https://github.com/ollama/ollama |
| Cline | saoudrizwan / Cline | Apache-2.0 | https://open-vsx.org/extension/saoudrizwan/claude-dev |
| Python | Python Software Foundation | PSF | https://www.python.org/ |
| Python extension | Microsoft (Open VSX build) | MIT | https://open-vsx.org/extension/ms-python/python |
| debugpy | Microsoft (Open VSX) | MIT | https://open-vsx.org/extension/ms-python/debugpy |
| Ruff | Astral | MIT | https://open-vsx.org/extension/charliermarsh/ruff |
| SQLTools + SQLite | mtxr | MIT | https://open-vsx.org/extension/mtxr/sqltools |
| Jupyter | Microsoft (Open VSX) | MIT | https://open-vsx.org/extension/ms-toolsai/jupyter |

Models pulled with `ollama pull` have their own licenses. Check the model page
on https://ollama.com/library before you redistribute weights to another agency.

PyPI packages listed in `templates/requirements-datasci.txt` (pandas, numpy,
scikit-learn, SQLAlchemy, Jupyter, ruff, and others) keep their upstream
licenses after `setup-datasci.ps1` installs them into `.venv`.
