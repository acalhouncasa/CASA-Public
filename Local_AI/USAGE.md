# Getting started

**Talon 1.4.6** · Local AI

Talon is a coding agent that stays on this workstation. The file explorer is on the left. Cline is on the right and must remain on **Ollama**. Do not create a Cline account.

---

## Highlights

- The **Talon** kit is always the first Explorer root. It starts collapsed so project and PHI files stay in front.
- Attach work with **Talon Connect** or **File → Add Folder to Workspace**. Those folders appear beside the kit.
- **File → Open Folder** and **Open Workspace from File** are not on the File menu. **Open File** stays. Use Add Folder to Workspace or Connect.
- Python uses this kit’s `.venv`. SQLTools starts with `data\local.sqlite`.
- Maps and lessons are written under `memory\` on this disk. Treat that folder as PHI.
- Talon waits for Ollama before the editor is useful. If Cline is not on Ollama, Talon resets it and reloads. Do not paste a cloud API key.

---

## Folders

Keep the kit separate from extracts.

| Explorer root | Purpose |
|---------------|---------|
| **Talon** | This kit: Python environment, memory, and scripts. Not a dump of extracts. |
| **Project** | SQL, notebooks, and scripts for one job. |
| **PHI** | Local extracts, CSVs, and SQLite files that may contain PHI. |

Example:

```text
C:\Talon\                 kit
D:\TalonProjects\Ops\     project
D:\TalonPHI\Extracts\     PHI
```

If code and PHI already live in one agency folder, connect that folder once. Three roots are not required.

**Connect** (desktop or Start Menu) is the usual path. **File → Add Folder to Workspace** and **Ctrl+K Ctrl+O** do the same thing. **File → Open Folder** is removed so it cannot replace the kit. Do not Trust a OneDrive, Desktop, or Downloads path for PHI.

---

## The editor

| Area | What you should see |
|------|---------------------|
| Left | Explorer. Talon is collapsed. Open files from Project or PHI. |
| Center | The file you are editing. This page on first launch. |
| Right | Cline. Provider is Ollama at `http://127.0.0.1:11434`. |
| Title bar | `Talon — local — 2 folders — Ollama up` |
| Status bar | Python is `.venv\Scripts\python.exe` |
| Database icon | SQLTools. **Local SQLite** plus anything you connected. |

Command Palette starters (Ctrl+Shift+P):

- **Talon: Starter — read memory index**
- **Talon: Starter — map this folder**
- **Talon: Starter — list SQL tables**

---

## Daily use

1. Start **Talon** from the desktop or Start Menu. Do not open stock VSCodium.
2. If Explorer shows only the kit, run **Talon Connect** or Add Folder to Workspace.
3. Keep Cline on the right. An empty pane is still this window’s agent. Do not open a cloud chat.
4. Back up `memory\` with **Backup.cmd** to a local disk or USB. Not OneDrive.

The first reply after a cold start can take a minute while the local model loads.

---

## If something is wrong

| Symptom | Action |
|---------|--------|
| Only the Talon root is listed | Talon Connect, or File → Add Folder to Workspace |
| Cline asks to create an account | Close Talon. Run `.\run.ps1` from this kit. |
| Python is not the venv | Status bar interpreter → `.venv\Scripts\python.exe` |
| SQLTools is empty | Connect a SQLite file or local SQL Server, or use `data\local.sqlite` |
| First Cline reply is slow | Wait. Launch warms `qwen3-coder:30b` in the background. |
| “Ollama is not running” page | Start Ollama from the Start Menu, or wait. Do not pick a cloud provider. |
| Cline shows OpenAI / ClinePass / an API key box | Close the prompt. Talon resets Cline to Ollama. If it comes back, close Talon and run `Start Talon.cmd`. |
| Need a copy of lessons | `Backup.cmd` to a local folder. The zip is PHI. |

Further reading: [CONNECT.md](CONNECT.md), [LEARN.md](LEARN.md), [HIPAA.md](HIPAA.md).
