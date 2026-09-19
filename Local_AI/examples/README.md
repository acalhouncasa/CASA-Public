# Synthetic demo (not PHI)

Training numbers only. No client names, chart IDs, or dates of birth.

`setup-datasci.ps1` loads `monthly_encounters.csv` into `data\local.sqlite` table `monthly_encounters` if that table is missing.

```powershell
.\.venv\Scripts\python.exe examples\load_demo.py
.\.venv\Scripts\python.exe -c "import sqlite3; print(sqlite3.connect(r'data\local.sqlite').execute('select site_code, month, encounters from monthly_encounters').fetchall())"
```

Ask Cline: “Plot encounters by month for SITE-A from data/local.sqlite using the venv. Save the figure under data\.”

Do not replace this CSV with a real export if you will zip or commit the kit.
