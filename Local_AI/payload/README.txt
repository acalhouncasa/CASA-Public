Place vendor-signed installers here for offline or air-gapped machines.

Do not rename these files after download. setup.ps1 looks for:

  VSCodiumUserSetup-*.exe   (from VSCodium GitHub / winget)
  OllamaSetup.exe           (from Ollama GitHub / winget)
  *.vsix                    (Cline from Open VSX: saoudrizwan.claude-dev)

These binaries stay as separate, publisher-signed files on purpose.
Do not wrap them inside a packed self-extracting EXE — that is what
makes Windows Defender and SmartScreen treat a kit like malware.

Get them with:

  winget download -e --id VSCodium.VSCodium -d payload
  winget download -e --id Ollama.Ollama -d payload

Or run Pack-ShareKit.ps1 -DownloadPayload
