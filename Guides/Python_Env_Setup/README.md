# Python environment setup (Windows, generic)

Recreate a **local** virtual environment on each PC. Do not copy someone else’s `venv` folder.

**Do not** commit credentials or PHI into the repo.

## Steps

1. Install a supported Python 3.x from python.org (check “Add to PATH”).
2. Clone or open your project folder.
3. Create a venv:

```powershell
cd C:\path\to\your\project
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

4. Point your editor at `.\.venv\Scripts\python.exe`.

## Verify

```powershell
.\.venv\Scripts\python.exe -c "import sys; print(sys.executable)"
```

## Notes

- Package lists belong in `requirements.txt` (or lock files). The venv itself stays machine-local.
- Browser automation (Playwright, etc.) is optional and project-specific.
