const vscode = require("vscode");
const path = require("path");
const fs = require("fs");

function kitRoot() {
  return process.env.TALON_KIT || "";
}

function workspaceFile() {
  const kit = kitRoot();
  return kit ? path.join(kit, "ide-data", "Talon.code-workspace") : "";
}

function kitIsOpen() {
  const kit = kitRoot();
  if (!kit) {
    return true;
  }
  const want = path.normalize(kit).toLowerCase();
  const folders = vscode.workspace.workspaceFolders || [];
  return folders.some((folder) => path.normalize(folder.uri.fsPath).toLowerCase() === want);
}

async function reopenKit() {
  const ws = workspaceFile();
  if (!ws || !fs.existsSync(ws)) {
    vscode.window.showErrorMessage("Talon workspace file is missing. Run Connect.cmd or run.ps1.");
    return;
  }
  await vscode.commands.executeCommand("vscode.openFolder", vscode.Uri.file(ws), false);
}

async function enforceKit() {
  if (kitIsOpen()) {
    return;
  }
  const choice = await vscode.window.showWarningMessage(
    "This window dropped the Talon kit. File → Open Folder removes Python, memory, and Connect. Reopen Talon?",
    { modal: true },
    "Reopen Talon"
  );
  if (choice === "Reopen Talon") {
    await reopenKit();
  }
}

async function openStarter(fileName) {
  const kit = kitRoot();
  const file = path.join(kit, ".cline", "workflows", fileName);
  if (!fs.existsSync(file)) {
    vscode.window.showErrorMessage("Starter file missing: " + fileName);
    return;
  }
  const text = fs.readFileSync(file, "utf8").replace(/^---[\s\S]*?---\s*/, "");
  await vscode.env.clipboard.writeText(text.trim());
  const doc = await vscode.workspace.openTextDocument(file);
  await vscode.window.showTextDocument(doc, { preview: true, preserveFocus: true });
  try {
    await vscode.commands.executeCommand("cline.plusButtonClicked");
  } catch (_) {
    try {
      await vscode.commands.executeCommand("cline.focusChatInput");
    } catch (_) {
      /* Cline command names vary by version */
    }
  }
  vscode.window.showInformationMessage("Starter copied. Paste it into Cline on the right (Ctrl+V).");
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand("talon.reopenWorkspace", reopenKit),
    vscode.commands.registerCommand("talon.warnOpenFolder", async () => {
      const choice = await vscode.window.showInformationMessage(
        "Use Talon Connect to attach a folder. File → Open Folder drops the kit.",
        "Reopen Talon",
        "OK"
      );
      if (choice === "Reopen Talon") {
        await reopenKit();
      }
    }),
    vscode.commands.registerCommand("talon.starterMapFolder", () => openStarter("map-this-folder.md")),
    vscode.commands.registerCommand("talon.starterListSql", () => openStarter("list-sql-tables.md")),
    vscode.commands.registerCommand("talon.starterMemory", () => openStarter("read-memory-index.md")),
    vscode.workspace.onDidChangeWorkspaceFolders(() => {
      enforceKit();
    })
  );
  enforceKit();
}

function deactivate() {}

module.exports = { activate, deactivate };
