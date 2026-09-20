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

let ollamaPanel = null;
let ollamaWasDown = false;
let clineLockBusy = false;
let lastClineReload = 0;

function clineHome() {
  return kit ? path.join(kit, "ide-data", "cline-home") : "";
}

function providersPath() {
  return path.join(clineHome(), "data", "settings", "providers.json");
}

function globalSettingsPath() {
  return path.join(clineHome(), "data", "settings", "global-settings.json");
}

function globalStatePath() {
  return path.join(clineHome(), "data", "globalState.json");
}

function readJson(file, fallback) {
  try {
    if (!fs.existsSync(file)) {
      return fallback;
    }
    const loaded = JSON.parse(fs.readFileSync(file, "utf8"));
    return loaded && typeof loaded === "object" ? loaded : fallback;
  } catch (_) {
    return fallback;
  }
}

function writeJson(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(data, null, 2), "utf8");
}

function ollamaUp() {
  return new Promise((resolve) => {
    const http = require("http");
    const req = http.get("http://127.0.0.1:11434/api/tags", { timeout: 2000 }, (res) => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    req.on("error", () => resolve(false));
    req.on("timeout", () => {
      req.destroy();
      resolve(false);
    });
  });
}

function currentOllamaModel() {
  const providers = readJson(providersPath(), {});
  const model =
    providers.providers &&
    providers.providers.ollama &&
    providers.providers.ollama.settings &&
    providers.providers.ollama.settings.model;
  return model || "qwen3-coder:30b";
}

function providersDrift(data) {
  if (!data || typeof data !== "object") {
    return false;
  }
  const last = String(data.lastUsedProvider || "").toLowerCase();
  if (last && last !== "ollama") {
    return true;
  }
  const providers = data.providers;
  if (!providers || typeof providers !== "object") {
    return false;
  }
  for (const key of Object.keys(providers)) {
    if (key.toLowerCase() !== "ollama") {
      return true;
    }
    const settings = (providers[key] && providers[key].settings) || {};
    if (settings.provider && String(settings.provider).toLowerCase() !== "ollama") {
      return true;
    }
    if (settings.apiKey || settings.openAiApiKey || settings.anthropicApiKey || settings.openRouterApiKey) {
      return true;
    }
  }
  return false;
}

function settingsDrift(data) {
  if (!data || typeof data !== "object") {
    return false;
  }
  for (const key of ["planModeApiProvider", "actModeApiProvider", "apiProvider"]) {
    const value = String(data[key] || "").toLowerCase();
    if (value && value !== "ollama") {
      return true;
    }
  }
  return false;
}

function writeOllamaProviders(model) {
  const now = new Date().toISOString();
  writeJson(providersPath(), {
    version: 1,
    modes: {},
    lastUsedProvider: "ollama",
    providers: {
      ollama: {
        settings: {
          provider: "ollama",
          model,
          baseUrl: "http://127.0.0.1:11434",
        },
        updatedAt: now,
        tokenSource: "localcoder",
      },
    },
  });
}

function forceOllamaSettings(file, model) {
  const data = readJson(file, {});
  data.planModeApiProvider = "ollama";
  data.actModeApiProvider = "ollama";
  data.apiProvider = "ollama";
  data.ollamaBaseUrl = "http://127.0.0.1:11434";
  data.planModeOllamaModelId = model;
  data.actModeOllamaModelId = model;
  delete data.apiKey;
  delete data.openAiApiKey;
  delete data.anthropicApiKey;
  delete data.openRouterApiKey;
  delete data.clineApiKey;
  writeJson(file, data);
}

function lockClineToOllama(reason) {
  if (clineLockBusy || !kit) {
    return false;
  }
  clineLockBusy = true;
  let reverted = false;
  try {
    const model = currentOllamaModel();
    const providers = readJson(providersPath(), {});
    if (providersDrift(providers)) {
      writeOllamaProviders(model);
      reverted = true;
    }
    if (settingsDrift(readJson(globalSettingsPath(), {}))) {
      forceOllamaSettings(globalSettingsPath(), model);
      reverted = true;
    }
    if (settingsDrift(readJson(globalStatePath(), {}))) {
      forceOllamaSettings(globalStatePath(), model);
      reverted = true;
    }
    if (reverted) {
      writeStatus({ phase: "cline-lock", reason, resetTo: "ollama" });
    }
  } finally {
    clineLockBusy = false;
  }
  return reverted;
}

async function showOllamaDown() {
  if (ollamaPanel) {
    ollamaPanel.reveal(vscode.ViewColumn.One);
    return;
  }
  const htmlPath = path.join(__dirname, "ollama-down.html");
  const html = fs.existsSync(htmlPath)
    ? fs.readFileSync(htmlPath, "utf8")
    : "<h1>Ollama is not running</h1><p>Do not pick a cloud provider.</p>";
  ollamaPanel = vscode.window.createWebviewPanel(
    "talon.ollamaDown",
    "Ollama is not running",
    vscode.ViewColumn.One,
    { enableScripts: false, retainContextWhenHidden: true }
  );
  ollamaPanel.webview.html = html;
  ollamaPanel.onDidDispose(() => {
    ollamaPanel = null;
  });
}

async function enforceOllamaGate() {
  const up = await ollamaUp();
  if (!up) {
    ollamaWasDown = true;
    await showOllamaDown();
    return false;
  }
  if (ollamaPanel) {
    ollamaPanel.dispose();
    ollamaPanel = null;
  }
  if (ollamaWasDown) {
    ollamaWasDown = false;
    vscode.window.showInformationMessage("Ollama is up. Cline must stay on the local model.");
  }
  return true;
}

async function enforceClineLock(reason) {
  const reverted = lockClineToOllama(reason);
  if (!reverted) {
    return;
  }
  const now = Date.now();
  if (now - lastClineReload < 20000) {
    vscode.window.showErrorMessage(
      "Talon reset Cline to Ollama. Cloud models are not allowed. Do not paste an API key."
    );
    return;
  }
  lastClineReload = now;
  vscode.window.showErrorMessage(
    "Talon reset Cline to Ollama. Cloud models are not allowed. Reloading so Cline drops the cloud provider."
  );
  await vscode.commands.executeCommand("workbench.action.reloadWindow");
}

function watchClineHome(context) {
  const dir = path.join(clineHome(), "data", "settings");
  if (!fs.existsSync(dir)) {
    return;
  }
  try {
    const watcher = fs.watch(dir, () => {
      enforceClineLock("watch");
    });
    context.subscriptions.push({ dispose: () => watcher.close() });
  } catch (_) {
    /* first launch may not have the folder yet */
  }
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
  watchClineHome(context);
  const lockTimer = setInterval(() => {
    enforceClineLock("poll");
    enforceOllamaGate();
  }, 3000);
  context.subscriptions.push({ dispose: () => clearInterval(lockTimer) });
  enforceKit();
  enforceClineLock("activate");
  const settle = async (phase) => {
    const closed = await closeVendorNotes();
    const ollamaReady = await enforceOllamaGate();
    if (ollamaReady) {
      await openGettingStarted();
    }
    await collapseTalonRoot();
    writeStatus({
      phase,
      closedNotes: closed,
      openedGuide: ollamaReady ? "webview" : "ollama-down",
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
