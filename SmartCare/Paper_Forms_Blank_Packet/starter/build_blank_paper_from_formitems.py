"""
Module: build_blank_paper_from_formitems.py

Build a blank HTML (and optional PDF) paper packet from SmartCare FormItems.

Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-02
Last Modified: 2026-10-02
AI Assistant: Talon

Connection (env only — no credential files in this pack):
  SC_SQL_SERVER, SC_SQL_DATABASE, SC_SQL_USER, SC_SQL_PASSWORD

Usage:
  python build_blank_paper_from_formitems.py --document-code-id 12345 --out ./out
  python build_blank_paper_from_formitems.py --document-code-id 12345 --out ./out --pdf

Dependencies:
  pyodbc; playwright (optional, for --pdf)

License: MIT
"""

from __future__ import annotations

import argparse
import html
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

ITEM_TYPE = {
    5360: "multiselect",
    5361: "textbox",
    5362: "checkbox",
    5363: "textarea",
    5364: "search",
    5365: "radio",
    5366: "integer",
    5367: "date",
    5368: "datetime",
    5369: "time",
    5370: "decimal",
    5372: "dropdown",
    5374: "label",
    5375: "ssn",
    5376: "currency",
    5377: "button",
    5378: "anchor",
    5379: "phone",
}

BLANK_INPUT = {
    "textbox",
    "textarea",
    "phone",
    "integer",
    "decimal",
    "currency",
    "ssn",
    "date",
    "datetime",
    "time",
    "search",
}

SKIP_GROUP = re.compile(r"^(sec\d+|content|clientinfo|select)$", re.I)
SKIP_LABEL = re.compile(r"^[_.\s]+$")
TALL_LABEL = re.compile(
    r"comment|explain|describe|narrative|additional|history",
    re.I,
)
ADDRESS_GROUP = re.compile(r"^address$", re.I)


def _env(name: str) -> str:
    val = (os.environ.get(name) or "").strip()
    if not val:
        raise SystemExit(f"Missing env {name}")
    return val


def connect():
    import pyodbc

    server = _env("SC_SQL_SERVER")
    database = _env("SC_SQL_DATABASE")
    user = _env("SC_SQL_USER")
    password = _env("SC_SQL_PASSWORD")
    last = None
    for driver in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"):
        try:
            return pyodbc.connect(
                f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
                f"UID={user};PWD={password};Encrypt=yes;TrustServerCertificate=yes",
                timeout=60,
            )
        except Exception as exc:  # noqa: BLE001
            last = exc
    raise SystemExit(f"pyodbc connect failed: {last}")


def strip_html(text: str | None) -> str:
    if not text:
        return ""
    text = re.sub(r"<br\s*/?>", " ", str(text), flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def clean_label(text: str | None) -> str:
    text = strip_html(text)
    if not text or SKIP_LABEL.match(text):
        return ""
    if text in {"0", "1"}:
        return ""
    return text


def esc(text: str) -> str:
    return html.escape(text)


def checkbox() -> str:
    return '<span class="mark">&#9744;</span>'


def radio() -> str:
    return '<span class="mark">&#9675;</span>'


def bar(text: str) -> str:
    return f'<div class="bar">{esc(text)}</div>'


def note(text: str) -> str:
    return f'<p class="note">{esc(text)}</p>'


def cell(label: str, hint: str = "", tall: bool = False) -> str:
    extra = " tall" if tall else ""
    hint_html = (
        f'<div class="hint">{esc(hint)}</div>' if hint else '<div class="write"></div>'
    )
    return (
        f'<div class="cell{extra}"><div class="lab">{esc(label)}</div>'
        f"{hint_html}</div>"
    )


def yn_row(question: str, options: list[str] | None = None) -> str:
    opts = options or ["Yes", "No"]
    marks = "".join(f"<label>{radio()} {esc(opt)}</label>" for opt in opts)
    return (
        f'<div class="ynrow"><div class="q">{esc(question)}</div>'
        f'<div class="yn">{marks}</div></div>'
    )


def check_grid(items: list[str], cols: int = 3) -> str:
    cells = "".join(f'<div class="cg">{checkbox()} {esc(item)}</div>' for item in items)
    cls = {2: "cols2", 4: "cols4"}.get(cols, "cols3")
    return f'<div class="checkgrid {cls}">{cells}</div>'


def id_strip() -> str:
    cells = [
        ("Client name", ""),
        ("Date of birth", "mm/dd/yyyy"),
        ("Chart #", ""),
        ("Form date", "mm/dd/yyyy"),
        ("Staff", ""),
    ]
    tds = "".join(
        f'<td><div class="lab">{esc(lab)}</div><div class="hint">{esc(hint)}</div></td>'
        for lab, hint in cells
    )
    return f'<table class="idstrip"><tr>{tds}</tr></table>'


def signature_block() -> str:
    return (
        '<div class="signbox">'
        '<div class="row2">'
        f'{cell("Signature", "")}{cell("Date", "mm/dd/yyyy")}'
        "</div>"
        '<div class="row2">'
        f'{cell("Printed name", "")}{cell("Credentials", "")}'
        "</div>"
        "</div>"
    )


CSS = """
@page { size: letter; margin: 0.55in 0.6in 0.7in 0.6in; }
body { font-family: Calibri, Arial, sans-serif; font-size: 10.5pt; color: #0A2540; }
h1 { font-size: 16pt; margin: 0 0 8px 0; }
.header { display: flex; gap: 12px; align-items: flex-start; margin-bottom: 10px; }
.header img { height: 42px; }
.bar { background: #D6E0EA; color: #0A2540; font-weight: 700; padding: 4px 8px;
       margin: 14px 0 8px 0; border-left: 4px solid #1E5A8C; }
.idstrip { width: 100%; border-collapse: collapse; margin: 8px 0 12px 0; }
.idstrip td { border: 1px solid #B8BFC7; padding: 6px; width: 20%; vertical-align: top; }
.lab { font-size: 8.5pt; color: #6B7280; }
.hint { color: #B8BFC7; min-height: 1.1em; }
.write { min-height: 1.2em; border-bottom: 1px solid #B8BFC7; }
.cell { border: 1px solid #B8BFC7; padding: 6px; margin: 4px 0; break-inside: avoid; }
.cell.tall .write { min-height: 3.2em; }
.row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.ynrow { display: flex; justify-content: space-between; gap: 12px; margin: 4px 0;
         break-inside: avoid; align-items: center; }
.yn { white-space: nowrap; }
.yn label { margin-left: 10px; }
.note { margin: 4px 0 8px 0; color: #374151; }
.checkgrid { display: grid; gap: 4px 10px; margin: 4px 0 8px 0; }
.checkgrid.cols2 { grid-template-columns: 1fr 1fr; }
.checkgrid.cols3 { grid-template-columns: 1fr 1fr 1fr; }
.checkgrid.cols4 { grid-template-columns: 1fr 1fr 1fr 1fr; }
.cg { break-inside: avoid; }
.mark { font-size: 12pt; }
.signbox { margin-top: 16px; break-inside: avoid; }
.tab { page-break-before: auto; }
.footer { font-size: 8pt; color: #6B7280; }
"""


def load_document(conn, document_code_id: int) -> dict:
    cur = conn.cursor()
    cur.execute(
        """
SET NOCOUNT ON;
SELECT DocumentCodeId, DocumentName, FormCollectionId, RequiresSignature
FROM dbo.DocumentCodes
WHERE DocumentCodeId = ? AND ISNULL(RecordDeleted, N'N') = N'N';
        """,
        document_code_id,
    )
    row = cur.fetchone()
    if not row:
        raise SystemExit(f"DocumentCodeId {document_code_id} not found")
    cols = [d[0] for d in cur.description]
    return dict(zip(cols, row))


def load_tabs(conn, document_code_id: int, form_collection_id) -> list[dict]:
    cur = conn.cursor()
    if form_collection_id:
        cur.execute(
            """
SET NOCOUNT ON;
SELECT f.FormId, f.FormName, f.TableName, fcf.FormOrder
FROM dbo.DocumentCodes AS dc
INNER JOIN dbo.FormCollectionForms AS fcf
    ON fcf.FormCollectionId = dc.FormCollectionId
   AND ISNULL(fcf.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.Forms AS f
    ON f.FormId = fcf.FormId AND ISNULL(f.RecordDeleted, N'N') = N'N'
WHERE dc.DocumentCodeId = ? AND ISNULL(dc.RecordDeleted, N'N') = N'N'
ORDER BY fcf.FormOrder, f.FormId;
            """,
            document_code_id,
        )
    else:
        cur.execute(
            """
SET NOCOUNT ON;
SELECT f.FormId, f.FormName, f.TableName, 10 AS FormOrder
FROM dbo.DocumentCodes AS dc
INNER JOIN dbo.Forms AS f
    ON ISNULL(f.RecordDeleted, N'N') = N'N'
   AND ISNULL(f.Active, N'Y') = N'Y'
   AND LEN(ISNULL(f.TableName, N'')) > 8
   AND CHARINDEX(f.TableName, CAST(dc.TableList AS NVARCHAR(MAX))) > 0
WHERE dc.DocumentCodeId = ? AND ISNULL(dc.RecordDeleted, N'N') = N'N'
ORDER BY f.FormId;
            """,
            document_code_id,
        )
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def load_items(conn, form_ids: list[int]) -> dict[int, list[dict]]:
    if not form_ids:
        return {}
    placeholders = ",".join(str(int(i)) for i in form_ids)
    sql = f"""
SET NOCOUNT ON;
SELECT
    F.FormId, F.FormName, FS.FormSectionId, FS.SortOrder AS SectionSort,
    FS.SectionLabel,
    FSG.FormSectionGroupId, FSG.SortOrder AS GroupSort,
    FSG.GroupName, FSG.GridType,
    FI.FormItemId, FI.SortOrder AS ItemSort, FI.ItemLabel, FI.ItemType,
    FI.ItemColumnName, FI.GlobalCodeCategory
FROM dbo.Forms AS F
INNER JOIN dbo.FormSections AS FS
    ON FS.FormId = F.FormId AND ISNULL(FS.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.FormSectionGroups AS FSG
    ON FSG.FormSectionId = FS.FormSectionId AND ISNULL(FSG.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.FormItems AS FI
    ON FI.FormSectionGroupId = FSG.FormSectionGroupId
   AND ISNULL(FI.RecordDeleted, N'N') = N'N'
   AND ISNULL(FI.Active, N'Y') = N'Y'
WHERE F.FormId IN ({placeholders})
  AND ISNULL(F.RecordDeleted, N'N') = N'N'
ORDER BY F.FormId, FS.SortOrder, FSG.SortOrder, FI.SortOrder;
"""
    cur = conn.cursor()
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    items: dict[int, list[dict]] = defaultdict(list)
    for row in cur.fetchall():
        rec = dict(zip(cols, row))
        items[int(rec["FormId"])].append(rec)
    return items


def load_radio_options(conn, form_ids: list[int]) -> dict[int, list[str]]:
    """Best-effort radio labels; empty if your schema differs."""
    if not form_ids:
        return {}
    placeholders = ",".join(str(int(i)) for i in form_ids)
    sql = f"""
SET NOCOUNT ON;
SELECT FI.FormItemId, ISNULL(R.RadioButtonOptionLabel, R.RadioButtonLabel) AS OptLabel
FROM dbo.FormItems AS FI
INNER JOIN dbo.FormSectionGroups AS FSG
    ON FSG.FormSectionGroupId = FI.FormSectionGroupId
INNER JOIN dbo.FormSections AS FS ON FS.FormSectionId = FSG.FormSectionId
INNER JOIN dbo.FormRadioButtonOptions AS R
    ON R.FormItemId = FI.FormItemId AND ISNULL(R.RecordDeleted, N'N') = N'N'
WHERE FS.FormId IN ({placeholders})
  AND FI.ItemType = 5365
  AND ISNULL(FI.RecordDeleted, N'N') = N'N'
ORDER BY FI.FormItemId, R.SortOrder;
"""
    out: dict[int, list[str]] = defaultdict(list)
    try:
        cur = conn.cursor()
        cur.execute(sql)
        for form_item_id, opt in cur.fetchall():
            label = clean_label(opt)
            if label:
                out[int(form_item_id)].append(label)
    except Exception:  # noqa: BLE001
        # Table name varies by version; starter still works with Yes/No defaults.
        return {}
    return out


def render_section_items(
    rows: list[dict],
    radios: dict[int, list[str]],
    section_label: str,
    tab_name: str,
) -> str:
    parts: list[str] = []
    checks: list[str] = []
    i = 0
    while i < len(rows):
        rec = rows[i]
        group = (rec.get("GroupName") or "").strip()
        if SKIP_GROUP.match(group or ""):
            i += 1
            continue

        itype = ITEM_TYPE.get(int(rec["ItemType"] or 0), "textbox")
        label = clean_label(rec.get("ItemLabel"))
        nxt = rows[i + 1] if i + 1 < len(rows) else None

        # 5374 note paired with next control that has no label
        if itype == "label" and nxt:
            same_group = int(nxt["FormSectionGroupId"]) == int(rec["FormSectionGroupId"])
            nxt_label = clean_label(nxt.get("ItemLabel"))
            nxt_type = ITEM_TYPE.get(int(nxt["ItemType"] or 0), "")
            if same_group and not nxt_label and nxt_type in BLANK_INPUT | {"radio", "dropdown", "checkbox"}:
                if ADDRESS_GROUP.match(group or "") and label:
                    parts.append(cell(label, "mm/dd/yyyy" if "date" in label.lower() else ""))
                    i += 1
                    continue
                # fall through: use this label on next item
                if label:
                    nxt = dict(nxt)
                    nxt["ItemLabel"] = label
                    rows[i + 1] = nxt
                i += 1
                continue

        if itype == "label":
            if ADDRESS_GROUP.match(group or "") and label:
                parts.append(cell(label))
            elif label:
                parts.append(note(label))
            i += 1
            continue

        if itype == "checkbox":
            if label:
                checks.append(label)
            i += 1
            continue

        if checks:
            parts.append(check_grid(checks))
            checks.clear()

        if itype in {"radio", "dropdown"}:
            opts = radios.get(int(rec["FormItemId"]), [])
            q = label or clean_label(rec.get("ItemColumnName")) or "Select"
            if opts:
                parts.append(yn_row(q, opts[:8]))
            else:
                parts.append(yn_row(q))
            i += 1
            continue

        if itype in BLANK_INPUT:
            tall = bool(TALL_LABEL.search(label or ""))
            hint = "mm/dd/yyyy" if itype in {"date", "datetime"} else ""
            parts.append(cell(label or " ", hint, tall=tall))
            i += 1
            continue

        # button / anchor / unknown — skip
        i += 1

    if checks:
        parts.append(check_grid(checks))

    # Optional: only show section bar when it is not identical noise
    head = ""
    sec = clean_label(section_label)
    if sec and sec.lower() != (tab_name or "").lower():
        head = bar(sec)
    elif sec and sec.lower() == (tab_name or "").lower():
        # same name as tab — still show once as section context
        head = bar(sec)

    return head + "".join(parts)


def render_form(form_name: str, items: list[dict], radios: dict[int, list[str]]) -> str:
    by_section: dict[tuple, list[dict]] = defaultdict(list)
    section_meta: dict[tuple, str] = {}
    for rec in items:
        key = (int(rec["SectionSort"] or 0), int(rec["FormSectionId"]))
        by_section[key].append(rec)
        section_meta[key] = rec.get("SectionLabel") or ""

    chunks = [f'<section class="tab">{bar(form_name)}']
    for key in sorted(by_section.keys()):
        chunks.append(
            render_section_items(
                by_section[key],
                radios,
                section_meta[key],
                form_name,
            )
        )
    chunks.append("</section>")
    return "".join(chunks)


def build_html(
    title: str,
    tabs: list[dict],
    items_by_form: dict[int, list[dict]],
    radios: dict[int, list[str]],
    *,
    logo: Path | None,
    add_signature: bool,
) -> str:
    logo_html = ""
    if logo and logo.is_file():
        # Embed as file:// for local Playwright; agencies can swap to data URI if needed
        logo_html = f'<img src="{logo.as_uri()}" alt="" />'

    body_parts = [
        f'<div class="header">{logo_html}<div><h1>{esc(title)}</h1>'
        f"<div>Blank paper packet (from FormItems)</div></div></div>",
        id_strip(),
    ]
    for tab in tabs:
        fid = int(tab["FormId"])
        body_parts.append(
            render_form(
                clean_label(tab.get("FormName")) or f"Form {fid}",
                items_by_form.get(fid, []),
                radios,
            )
        )
    if add_signature:
        body_parts.append('<section class="tab">' + bar("Signature") + signature_block() + "</section>")

    return (
        "<!DOCTYPE html><html><head><meta charset='utf-8'/>"
        f"<title>{esc(title)}</title><style>{CSS}</style></head><body>"
        + "".join(body_parts)
        + "</body></html>"
    )


def write_pdf(html_path: Path, pdf_path: Path) -> None:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(html_path.resolve().as_uri(), wait_until="load")
        page.pdf(
            path=str(pdf_path),
            format="Letter",
            print_background=True,
            display_header_footer=True,
            header_template="<span></span>",
            footer_template=(
                '<div style="font-size:8pt;width:100%;text-align:center;color:#6B7280;">'
                '<span class="pageNumber"></span> / <span class="totalPages"></span></div>'
            ),
            margin={"top": "0.55in", "bottom": "0.7in", "left": "0.6in", "right": "0.6in"},
        )
        browser.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Blank paper packet from SmartCare FormItems")
    parser.add_argument("--document-code-id", type=int, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--title", default="")
    parser.add_argument("--logo", type=Path, default=None)
    parser.add_argument("--pdf", action="store_true")
    parser.add_argument("--no-signature", action="store_true")
    args = parser.parse_args(argv)

    conn = connect()
    doc = load_document(conn, args.document_code_id)
    tabs = load_tabs(conn, args.document_code_id, doc.get("FormCollectionId"))
    if not tabs:
        raise SystemExit("No Forms found for this DocumentCodeId (collection or TableList)")

    form_ids = [int(t["FormId"]) for t in tabs]
    items_by_form = load_items(conn, form_ids)
    radios = load_radio_options(conn, form_ids)
    conn.close()

    title = args.title.strip() or clean_label(doc.get("DocumentName")) or "Paper form"
    requires_sig = str(doc.get("RequiresSignature") or "").upper() == "Y"
    add_signature = requires_sig and not args.no_signature

    args.out.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r"[^\w\-]+", "_", title).strip("_")[:80] or "paper_form"
    html_path = args.out / f"{args.document_code_id}_{safe}_paper_form.html"
    html_path.write_text(
        build_html(
            title,
            tabs,
            items_by_form,
            radios,
            logo=args.logo,
            add_signature=add_signature,
        ),
        encoding="utf-8",
    )
    print(f"Wrote {html_path}")

    if args.pdf:
        pdf_path = html_path.with_suffix(".pdf")
        try:
            write_pdf(html_path, pdf_path)
            print(f"Wrote {pdf_path}")
        except Exception as exc:  # noqa: BLE001
            print(f"PDF failed ({exc}). HTML is ready to print from a browser.", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
