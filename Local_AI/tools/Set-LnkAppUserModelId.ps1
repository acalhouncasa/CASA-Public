#requires -Version 5.1
<#
.SYNOPSIS
  Set System.AppUserModel.ID on a .lnk so the taskbar uses that shortcut's icon.

.NOTES
  Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
  Created: 2026-10-26
  Last Modified: 2026-10-26
  AI Assistant: Talon
  License: UNLICENSED
#>
param(
    [Parameter(Mandatory = $true)][string]$ShortcutPath,
    [Parameter(Mandatory = $true)][string]$AppUserModelId
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $ShortcutPath)) {
    throw "Shortcut not found: $ShortcutPath"
}

$code = @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class LnkAppId {
  [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IShellLinkW {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
    void GetIDList(out IntPtr ppidl);
    void SetIDList(IntPtr pidl);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cchMaxName);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cchMaxPath);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cchMaxPath);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
    void GetHotkey(out short pwHotkey);
    void SetHotkey(short wHotkey);
    void GetShowCmd(out int piShowCmd);
    void SetShowCmd(int iShowCmd);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cchIconPath, out int piIcon);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
    void Resolve(IntPtr hwnd, uint fFlags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
  }

  [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPropertyStore {
    void GetCount(out uint cProps);
    void GetAt(uint iProp, out PropertyKey pkey);
    void GetValue(ref PropertyKey key, out PropVariant pv);
    void SetValue(ref PropertyKey key, ref PropVariant pv);
    void Commit();
  }

  [StructLayout(LayoutKind.Sequential, Pack = 4)]
  struct PropertyKey {
    public Guid fmtid;
    public uint pid;
  }

  [StructLayout(LayoutKind.Sequential)]
  struct PropVariant {
    public ushort vt;
    public ushort wReserved1;
    public ushort wReserved2;
    public ushort wReserved3;
    public IntPtr pszVal;
  }

  [DllImport("ole32.dll")]
  static extern int PropVariantClear(ref PropVariant pvar);

  public static void Set(string lnkPath, string appId) {
    var clsid = new Guid("00021401-0000-0000-C000-000000000046"); // ShellLink
    var type = Type.GetTypeFromCLSID(clsid);
    object link = Activator.CreateInstance(type);
    var persist = (IPersistFile)link;
    // STGM_READWRITE (2) — STGM_READ (0) causes STG_E_ACCESSDENIED on Commit.
    persist.Load(lnkPath, 2);
    var store = (IPropertyStore)link;
    var key = new PropertyKey {
      fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
      pid = 5 // System.AppUserModel.ID
    };
    var pv = new PropVariant {
      vt = 31, // VT_LPWSTR
      pszVal = Marshal.StringToCoTaskMemUni(appId)
    };
    try {
      store.SetValue(ref key, ref pv);
      store.Commit();
      persist.Save(lnkPath, true);
    } finally {
      PropVariantClear(ref pv);
    }
    Marshal.ReleaseComObject(link);
  }
}
"@

if (-not ("LnkAppId" -as [type])) {
    Add-Type -TypeDefinition $code -ReferencedAssemblies System.dll -ErrorAction Stop
}
[LnkAppId]::Set($ShortcutPath, $AppUserModelId)
Write-Host "AppUserModelID=$AppUserModelId -> $ShortcutPath"
