const vscode = require("vscode");
const path = require("path");
const fs = require("fs");

let kit = "";
let busy = false;
let openedGuide = false;

function resolveKit(context) {
  const fromEnv = process.env.TALON_KIT;
  if (fromEnv && fs.existsSync(fromEnv)) {
    return path.normalize(fromEnv);
  }
  const parent = path.dirname(context.extensionPath);
  const leaf = path.basename(parent).toLowerCase();
  if (leaf === "ide-extensions" || leaf === "extensions") {
    return path.normalize(path.dirname(parent));
  }
  return "";
}

function norm(p) {
  return path.normalize(p || "").toLowerCase();
}

function workspaceFile() {
  return kit ? path.join(kit, "ide-data", "Talon.code-workspace") : "";
}

function sourcesFile() {
  return path.join(kit, "ide-data", "sources.json");
}

function kitIsOpen() {
  if (!kit) {
    return true;
  }
  const want = norm(kit);
  return (vscode.workspace.workspaceFolders || []).some((folder) => norm(folder.uri.fsPath) === want);
}

function looksCloud(p) {
  const n = String(p || "").toLowerCase();
  return n.includes("\\onedrive\\") || n.includes("\\onedrive -") || n.includes("/onedrive/");
}

function guessRole(folderPath, name) {
  const blob = `${name || ""} ${folderPath || ""}`.toLowerCase();
  if (blob.includes("phi")) {
    return "phi";
  }
  return "project";
}

function folderLabel(folderPath, name, role) {
  if (name && (name.startsWith("PHI:") || name.startsWith("Project:"))) {
    return name;
  }
  const leaf = name || path.basename(folderPath);
  if (role === "phi") {
    return `PHI: ${leaf}`;
  }
  if (role === "project") {
    return `Project: ${leaf}`;
  }
  return leaf;
}

function loadSources() {
  const file = sourcesFile();
  if (!fs.existsSync(file)) {
    return {
      folders: [],
      databases: [
        {
          name: "Local SQLite",
          kind: "sqlite",
          path: path.join(kit, "data", "local.sqlite"),
        },
      ],
    };
  }
  try {
    const loaded = JSON.parse(fs.readFileSync(file, "utf8"));
    if (loaded && typeof loaded === "object") {
      if (!Array.isArray(loaded.folders)) {
        loaded.folders = [];
      }
      if (!Array.isArray(loaded.databases)) {
        loaded.databases = [];
      }
      return loaded;
    }
  } catch (_) {
    /* rewrite below */
  }
  return { folders: [], databases: [] };
}

function saveSources(sources) {
  const ide = path.join(kit, "ide-data");
  fs.mkdirSync(ide, { recursive: true });
  fs.writeFileSync(path.join(ide, "sources.json"), JSON.stringify(sources, null, 2), "utf8");
}

function rewriteWorkspace(sources) {
  const folders = [{ name: "Talon", path: kit.replace(/\\/g, "/") }];
  const seen = new Set([norm(kit)]);
  for (const item of sources.folders || []) {
    const raw = item && item.path;
    if (!raw) {
      continue;
    }
    const key = norm(raw);
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    folders.push({
      name: item.name || path.basename(raw),
      path: String(raw).replace(/\\/g, "/"),
    });
  }
  const extra = Math.max(0, folders.length - 1);
  const extraText = extra === 0 ? "kit only" : extra === 1 ? "1 folder" : `${extra} folders`;
  const workspace = {
    folders,
    settings: {
      "window.title": "Talon — local — " + extraText + " — ${rootName}${separator}${activeEditorShort}",
      "explorer.autoReveal": false,
    },
  };
  fs.writeFileSync(workspaceFile(), JSON.stringify(workspace, null, 2), "utf8");
}

function syncFromOpenFolders() {
  if (!kit) {
    return [];
  }
  const sources = loadSources();
  const previous = new Map();
  for (const item of sources.folders || []) {
    if (item && item.path) {
      previous.set(norm(item.path), item);
    }
  }
  const next = [];
  const seen = new Set();
  const added = [];
  const kitN = norm(kit);
  for (const wf of vscode.workspace.workspaceFolders || []) {
    const folderPath = wf.uri.fsPath;
    const key = norm(folderPath);
    if (key === kitN || seen.has(key)) {
      continue;
    }
    seen.add(key);
    if (previous.has(key)) {
      next.push(previous.get(key));
    } else {
      const role = guessRole(folderPath, wf.name);
      const entry = {
        name: folderLabel(folderPath, wf.name, role),
        path: folderPath,
        role,
      };
      next.push(entry);
      added.push(folderPath);
    }
  }
  sources.folders = next;
  saveSources(sources);
  rewriteWorkspace(sources);
  return added;
}

async function reopenKit() {
  const ws = workspaceFile();
  if (!ws || !fs.existsSync(ws)) {
    vscode.window.showErrorMessage("Talon workspace file is missing. Run Connect.cmd or run.ps1.");
    return;
  }
  await vscode.commands.executeCommand("vscode.openFolder", vscode.Uri.file(ws), false);
}

function writeStatus(extra) {
  if (!kit) {
    return;
  }
  const payload = Object.assign(
    {
      activated: true,
      kit,
      time: new Date().toISOString(),
    },
    extra || {}
  );
  try {
    const dest = path.join(kit, "ide-data", "guard-status.json");
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, JSON.stringify(payload, null, 2), "utf8");
  } catch (_) {
    /* status is diagnostics only */
  }
}

function isNotesTab(tab) {
  const label = String(tab.label || "");
  if (/getting started/i.test(label)) {
    return false;
  }
  if (/release notes|what.?s new|walkthrough|welcome/i.test(label)) {
    return true;
  }
  const input = tab.input;
  if (!input) {
    return false;
  }
  const uri = input.uri;
  if (uri && /release|walkthrough|welcome/i.test(String(uri.scheme) + String(uri.path))) {
    return true;
  }
  const viewType = input.viewType || "";
  if (/release|walkthrough|welcome/i.test(String(viewType))) {
    return true;
  }
  if (input instanceof vscode.TabInputText) {
    const file = String(input.uri.fsPath || "").toLowerCase();
    if (file.endsWith("usage.md")) {
      return true;
    }
  }
  return false;
}

async function closeVendorNotes() {
  let closed = 0;
  for (const group of vscode.window.tabGroups.all) {
    for (const tab of group.tabs) {
      if (!isNotesTab(tab)) {
        continue;
      }
      try {
        await vscode.window.tabGroups.close(tab, true);
        closed += 1;
      } catch (_) {
        /* tab already gone */
      }
    }
  }
  return closed;
}

async function openGettingStarted() {
  if (openedGuide) {
    return;
  }
  openedGuide = true;
  const htmlPath = path.join(__dirname, "getting-started.html");
  const html = fs.existsSync(htmlPath)
    ? fs.readFileSync(htmlPath, "utf8")
    : "<h1>Getting started</h1><p>Talon Local AI</p>";
  const panel = vscode.window.createWebviewPanel(
    "talon.gettingStarted",
    "Getting started",
    vscode.ViewColumn.One,
    { enableScripts: false, retainContextWhenHidden: true }
  );
  panel.webview.html = html;
}

async function collapseTalonRoot() {
  if (!kitIsOpen()) {
    return;
  }
  try {
    await vscode.commands.executeCommand("workbench.view.explorer");
    await vscode.commands.executeCommand("list.collapseAll");
  } catch (_) {
    try {
      await vscode.commands.executeCommand("workbench.files.action.collapseExplorerFolders");
    } catch (_) {
      return;
    }
  }
  const kitN = norm(kit);
  for (const folder of vscode.workspace.workspaceFolders || []) {
    if (norm(folder.uri.fsPath) === kitN) {
      continue;
    }
    try {
      await vscode.commands.executeCommand("revealInExplorer", folder.uri);
    } catch (_) {
      /* explorer may not be ready */
    }
  }
}

async function enforceKit() {
  if (busy || !kit) {
    return;
  }
  busy = true;
  try {
    if (kitIsOpen()) {
      syncFromOpenFolders();
      await collapseTalonRoot();
      return;
    }
    const extras = (vscode.workspace.workspaceFolders || [])
      .map((folder) => folder.uri.fsPath)
      .filter((p) => norm(p) !== norm(kit));
    const added = syncFromOpenFolders();
    const cloud = extras.filter(looksCloud);
    if (cloud.length) {
      vscode.window.showWarningMessage(
        "That folder looks like OneDrive or a synced path. It was added to Talon anyway. Prefer a local disk for PHI."
      );
    } else if (added.length) {
      vscode.window.showInformationMessage(
        "Talon kept the kit open and added the folder to this workspace. Use File → Add Folder to Workspace next time."
      );
    }
    await reopenKit();
  } finally {
    busy = false;
  }
}

async function addFolderToWorkspace() {
  await vscode.commands.executeCommand("workbench.action.addRootFolder");
}

async function openStarter(fileName) {
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
  kit = resolveKit(context);
  writeStatus({ phase: "activate" });
  context.subscriptions.push(
    vscode.commands.registerCommand("talon.reopenWorkspace", reopenKit),
    vscode.commands.registerCommand("talon.addFolder", addFolderToWorkspace),
    vscode.commands.registerCommand("talon.warnOpenFolder", addFolderToWorkspace),
    vscode.commands.registerCommand("talon.starterMapFolder", () => openStarter("map-this-folder.md")),
    vscode.commands.registerCommand("talon.starterListSql", () => openStarter("list-sql-tables.md")),
    vscode.commands.registerCommand("talon.starterMemory", () => openStarter("read-memory-index.md")),
    vscode.workspace.onDidChangeWorkspaceFolders(() => {
      enforceKit();
    })
  );
  enforceKit();
  const settle = async (phase) => {
    const closed = await closeVendorNotes();
    await openGettingStarted();
    await collapseTalonRoot();
    writeStatus({
      phase,
      closedNotes: closed,
      openedGuide: "webview",
      folderCount: (vscode.workspace.workspaceFolders || []).length,
      workspaceFile: !!(vscode.workspace.workspaceFile && /talon\.code-workspace/i.test(vscode.workspace.workspaceFile.fsPath || "")),
    });
  };
  settle("immediate");
  setTimeout(() => settle("500ms"), 500);
  setTimeout(() => settle("1600ms"), 1600);
  setTimeout(() => collapseTalonRoot(), 4000);
}

function deactivate() {}

module.exports = { activate, deactivate };
