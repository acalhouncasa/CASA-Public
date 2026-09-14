"""
Module: generate_dfa_sql.py

Author: CASA-Trinity (public starter)
Created: 2026-09-14
Last Modified: 2026-09-14

Description:
    Emit numbered SmartCare SSMS scripts from a DFA FORM_SPEC.json.
    Portable identity rules: no stolen IDENTITY_INSERT ids, new FormCollection
    per greenfield form, GUID-based reruns, nullable custom columns,
    radio VARCHAR(20), dropdown INT, textarea 5363.

Usage:
    python generate_dfa_sql.py --spec path/to/FORM_SPEC.json

Inputs:
    FORM_SPEC.json (see form_spec.schema.json)

Outputs:
    <form>/SQL/01_precheck.sql
    <form>/SQL/02_globalcodes.sql (only if picklists)
    <form>/SQL/03_apply_form.sql
    <form>/SQL/04_postcheck.sql
    <form>/RUN_STEPS.md
    Spec is rewritten when missing GUIDs are filled.

License: MIT
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import uuid
from datetime import date
from pathlib import Path
from typing import Any

ITEM_TEXTBOX = 5361
ITEM_CHECKBOX = 5362
ITEM_TEXTAREA = 5363
ITEM_RADIO = 5365
ITEM_INTEGER = 5366
ITEM_DATE = 5367
ITEM_DROPDOWN = 5372
ITEM_LABEL = 5374
ITEM_IMAGE = 5380
ITEM_MULTISELECT = 5360

NO_COLUMN_TYPES = {ITEM_LABEL, ITEM_IMAGE}
TABLE_NAME_RE = re.compile(r"^CustomDocument[A-Za-z0-9]+$")
COLUMN_NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,127}$")
TODAY = date.today().isoformat()


def esc(value: str) -> str:
    return (value or "").replace("'", "''")


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return f"N'{esc(value)}'"


def sql_int_or_null(value: Any) -> str:
    if value is None:
        return "NULL"
    return str(int(value))


def dfa_flag_sql(spec: dict[str, Any], key: str, default: str | None) -> str:
    """Y/N DocumentCodes flag. default None emits SQL NULL."""
    if key in spec:
        raw = spec.get(key)
    else:
        raw = default
    if raw is None:
        return "NULL"
    val = str(raw).strip().upper()
    if val in ("", "NULL"):
        return "NULL"
    if val not in ("Y", "N"):
        raise ValueError(f"{key} must be Y, N, or null; got {raw!r}")
    return f"N'{val}'"


def dfa_flag_sql_keys(spec: dict[str, Any], keys: tuple[str, ...], default: str | None) -> str:
    for key in keys:
        if key in spec:
            return dfa_flag_sql(spec, key, default)
    return dfa_flag_sql(spec, keys[0], default)


def new_guid_upper() -> str:
    return str(uuid.uuid4()).upper()


def new_guid_lower() -> str:
    return str(uuid.uuid4()).lower()


def sql_header(filename: str, purpose: str, mutates: bool, database: str) -> str:
    mut = "Y" if mutates else "N (read-only SELECT / PRINT)"
    return f"""/*======================================================================================================================
File: {filename}
Author: CASA-Trinity (public starter)
Created: {TODAY}
Last Modified: {TODAY}
Purpose:
 {purpose}

Usage:
 Select database [{database}] in SSMS (USE is in this file) and F5 the whole file.
 Do not test in Prod.
 Mutates: {mut}
 Paste messages / result grids back if you use an AI agent.

License: MIT
======================================================================================================================*/

USE [{database}];
"""


def iter_groups(spec: dict[str, Any]):
    for section in spec["sections"]:
        for group in section["groups"]:
            yield section, group


def iter_fields(spec: dict[str, Any]):
    for section, group in iter_groups(spec):
        for field in group["fields"]:
            yield section, group, field


def is_data_field(field: dict[str, Any]) -> bool:
    return int(field["item_type"]) not in NO_COLUMN_TYPES


def defaults_for_field(field: dict[str, Any]) -> None:
    t = int(field["item_type"])
    if field.get("item_width") is None:
        field["item_width"] = 600 if t == ITEM_TEXTAREA else (50 if t == ITEM_CHECKBOX else 200)
    if field.get("maximum_length") is None:
        if t == ITEM_TEXTAREA:
            field["maximum_length"] = 8000
        elif t == ITEM_CHECKBOX:
            field["maximum_length"] = 1
        elif t in (ITEM_RADIO, ITEM_DROPDOWN):
            field["maximum_length"] = 20
        else:
            field["maximum_length"] = 256
    # Do not default MultilineEditFieldHeight (UAT: leave NULL).


def sql_type_for_field(field: dict[str, Any]) -> str:
    t = int(field["item_type"])
    if t == ITEM_TEXTAREA:
        n = int(field.get("maximum_length") or 8000)
        return f"VARCHAR({n})"
    if t == ITEM_TEXTBOX and (field.get("multiline_edit_field_height") or 0) > 0:
        return "VARCHAR(MAX)"
    if t == ITEM_TEXTBOX:
        n = int(field.get("maximum_length") or 256)
        return f"VARCHAR({n})"
    if t == ITEM_CHECKBOX:
        return "TYPE_YORN"
    if t == ITEM_RADIO:
        return "VARCHAR(20)"
    if t in (ITEM_INTEGER, ITEM_DROPDOWN):
        return "INT"
    if t == ITEM_DATE:
        return "DATE"
    if t == ITEM_MULTISELECT:
        return "VARCHAR(MAX)"
    return "VARCHAR(256)"


def grid_header_sql(field: dict[str, Any], group: dict[str, Any]) -> str:
    if group.get("grid_type") != "G":
        return "NULL"
    header = (field.get("grid_header") or "").strip()
    if not header:
        header = re.sub(r"<[^>]+>", "", field.get("label") or "").strip()
    return sql_str(header) if header else "NULL"


def grid_width_sql(field: dict[str, Any], group: dict[str, Any]) -> str:
    if group.get("grid_type") != "G":
        return "NULL"
    w = field.get("grid_column_width") or field.get("item_width") or 200
    return str(int(w))


def item_column_name(field: dict[str, Any]) -> str | None:
    t = int(field["item_type"])
    if t in NO_COLUMN_TYPES:
        name = (field.get("column_name") or "").strip()
        return name or None
    name = (field.get("column_name") or "").strip()
    if not name:
        raise ValueError(f"Data field {field.get('label')!r} needs column_name")
    return name


def enable_checkbox_columns(spec: dict[str, Any]) -> list[tuple[str, str]]:
    """Section header enable checkboxes (FormSections.SectionEnableCheckBox*). Not FormItems."""
    cols: list[tuple[str, str]] = []
    seen: set[str] = set()
    for section in spec["sections"]:
        if (section.get("section_enable_checkbox") or "").upper() != "Y":
            continue
        name = (section.get("section_enable_checkbox_column_name") or "").strip()
        if not name or name in seen:
            continue
        seen.add(name)
        cols.append((name, "TYPE_YORN"))
    return cols


def section_enable_sql(section: dict[str, Any]) -> tuple[str, str, str]:
    if (section.get("section_enable_checkbox") or "").upper() == "Y":
        return (
            "N'Y'",
            sql_str(section.get("section_enable_checkbox_text")),
            sql_str(section.get("section_enable_checkbox_column_name")),
        )
    return "NULL", "NULL", "NULL"


def main_table_columns(spec: dict[str, Any]) -> list[tuple[str, str]]:
    seen: set[str] = set()
    cols: list[tuple[str, str]] = []
    for name, sql_type in enable_checkbox_columns(spec):
        seen.add(name)
        cols.append((name, sql_type))
    for _s, group, field in iter_fields(spec):
        if group.get("grid_type") == "G":
            continue
        if not is_data_field(field):
            continue
        name = item_column_name(field)
        if name in seen:
            continue
        seen.add(name)
        cols.append((name, sql_type_for_field(field)))
    return cols


def grid_table_columns(group: dict[str, Any]) -> list[tuple[str, str]]:
    seen: set[str] = set()
    cols: list[tuple[str, str]] = []
    for field in group["fields"]:
        if not is_data_field(field):
            continue
        name = item_column_name(field)
        if name in seen:
            continue
        seen.add(name)
        cols.append((name, sql_type_for_field(field)))
    return cols


def needs_dropdown_g(field: dict[str, Any]) -> bool:
    t = int(field["item_type"])
    explicit = (field.get("dropdown_type") or "").strip().upper()
    if explicit:
        return explicit == "G"
    cat = (field.get("global_code_category") or "").strip()
    # RADIOYN stores ExternalCode1 Y/N. DropdownType G would persist GlobalCodeId.
    if t == ITEM_RADIO and cat.upper() == "RADIOYN":
        return False
    return bool(cat) and t in (
        ITEM_DROPDOWN,
        ITEM_RADIO,
        ITEM_MULTISELECT,
    )


def reused_global_code_categories(spec: dict[str, Any]) -> list[str]:
    """Categories referenced on fields but not created by this spec (e.g. RADIOYN)."""
    owned = {
        (cat.get("category") or "").strip()
        for cat in spec.get("global_code_categories") or []
        if (cat.get("category") or "").strip()
    }
    found: list[str] = []
    seen: set[str] = set()
    for _s, _g, field in iter_fields(spec):
        cat = (field.get("global_code_category") or "").strip()
        if not cat or cat in owned or cat in seen:
            continue
        seen.add(cat)
        found.append(cat)
    return found


def load_form_javascript(spec: dict[str, Any], spec_dir: Path) -> str | None:
    raw = spec.get("form_javascript")
    if isinstance(raw, str) and raw.strip():
        return raw
    rel = (spec.get("form_javascript_file") or "").strip()
    if not rel:
        return None
    path = Path(rel)
    if not path.is_absolute():
        path = spec_dir / rel
    if not path.is_file():
        raise ValueError(f"form_javascript_file not found: {path}")
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        raise ValueError(f"form_javascript_file is empty: {path}")
    return text


def javascript_override_sql(spec: dict[str, Any], has_js: bool) -> str:
    raw = spec.get("is_javascript_override")
    if raw in ("Y", "N"):
        return sql_str(raw)
    if has_js:
        return "N'Y'"
    return "NULL"


def validate_spec(spec: dict[str, Any]) -> None:
    table = spec.get("table_name") or ""
    if not TABLE_NAME_RE.match(table):
        raise ValueError(f"table_name must match CustomDocument[A-Za-z0-9]+: {table!r}")
    cols: list[str] = []
    group_names: list[str] = []
    for _s, group, field in iter_fields(spec):
        defaults_for_field(field)
        t = int(field["item_type"])
        if is_data_field(field):
            name = item_column_name(field)
            if not COLUMN_NAME_RE.match(name):
                raise ValueError(f"Invalid column_name {name!r} for {field.get('label')!r}")
            if name in cols:
                raise ValueError(
                    f"Duplicate ItemColumnName {name!r} (must be unique across the form, "
                    "including grids — 60364 Phone vs Phone2)"
                )
            cols.append(name)
            if group.get("grid_type") == "G" and t in (5367, 5369, 5379):
                raise ValueError(
                    f"Grid field {name!r} ItemType {t} cannot be visible Date/Time/Phone. "
                    "Use 5361 + varchar (#111917)."
                )
            if group.get("grid_type") == "G":
                raw_header = (field.get("grid_header") or "").strip() or re.sub(
                    r"<[^>]+>", "", field.get("label") or ""
                )
                header_key = re.sub(r"[^a-z]+", "", raw_header.casefold())
                if re.search(r"\b(date|time|phone)\b", raw_header, flags=re.I):
                    raise ValueError(
                        f"Grid field {name!r} header {raw_header!r} contains Date/Time/Phone. "
                        "Visible grid Date/Time/Phone ItemTypes recreate #111917. "
                        "Bedded 3 Need day headers still blank; do not use GridType G for this form "
                        "(Bedded 4 is 5374 labels + blank 5361 rows)."
                    )
        if t in (ITEM_RADIO, ITEM_DROPDOWN, ITEM_MULTISELECT) and not (
            field.get("global_code_category") or ""
        ).strip():
            raise ValueError(f"{field.get('label')!r} item_type {t} needs global_code_category")
    for section in spec["sections"]:
        if (section.get("section_enable_checkbox") or "").upper() != "Y":
            continue
        ename = (section.get("section_enable_checkbox_column_name") or "").strip()
        etext = (section.get("section_enable_checkbox_text") or "").strip()
        if not ename or not COLUMN_NAME_RE.match(ename):
            raise ValueError(
                f"Section {section.get('section_label')!r} enable checkbox needs "
                "section_enable_checkbox_column_name"
            )
        if not etext:
            raise ValueError(
                f"Section {section.get('section_label')!r} enable checkbox needs "
                "section_enable_checkbox_text"
            )
        if ename in cols:
            raise ValueError(
                f"Section enable column {ename!r} duplicates a FormItem column. "
                "Do not also add that checkbox as a FormItem."
            )
        cols.append(ename)
    for _s, group in iter_groups(spec):
        gn = group.get("group_name") or ""
        if not gn:
            raise ValueError("Every group needs group_name")
        if gn in group_names:
            raise ValueError(f"Duplicate group_name {gn!r}")
        group_names.append(gn)
        if group.get("grid_type") == "G":
            gt = group.get("custom_grid_table_name") or ""
            if not gt.startswith("XGrid"):
                raise ValueError(f"Grid table must start with XGrid: {gt!r}")
        gl = (group.get("group_label") or "").strip()
        if gl:
            for field in group["fields"]:
                fl = (field.get("label") or "").strip()
                if fl and fl.casefold() == gl.casefold():
                    raise ValueError(
                        f"Group label {gl!r} matches item label. Leave the item label blank "
                        "so the DFA does not print the heading twice (QA UAT 2026-08-19)."
                    )
    for cat in spec.get("global_code_categories") or []:
        c = (cat.get("category") or "").strip()
        if not c.startswith("X"):
            raise ValueError(f"Custom GlobalCode category must start with X: {c!r}")
        if len(c) > 20:
            raise ValueError(f"GlobalCode category max 20 chars: {c!r}")
        if not cat.get("options"):
            raise ValueError(f"Category {c} has no options")
        for option in cat["options"]:
            name, _code, ext = option_parts(option)
            if not name:
                raise ValueError(f"Category {c} has a blank option")
            if not re.fullmatch(r"[A-Za-z0-9]+", ext):
                raise ValueError(
                    f"Category {c} option {name!r} ExternalCode1 {ext!r} must be alphanumeric "
                    "(radio save uses ExternalCode1; #97352)."
                )
            if ext.isdigit():
                raise ValueError(
                    f"Category {c} option {name!r} ExternalCode1 {ext!r} is numeric-only. "
                    "Use a letter token so RDL decode does not collide with GlobalCodeId."
                )
    if spec.get("host_document_code_id") is not None:
        try:
            host_document_code_id(spec)
        except (TypeError, ValueError) as exc:
            raise ValueError("host_document_code_id must be an int DocumentCodeId") from exc
        ft = spec.get("form_type")
        if ft is not None and int(ft) not in (9467, 9468, 9469):
            raise ValueError(f"form_type must be 9467/9468/9469; got {ft!r}")


def is_host_custom_fields_tab(spec: dict[str, Any]) -> bool:
    """Vendor ascx extra tab (PAS 45 analog). Form only; no new DocumentCode."""
    return spec.get("host_document_code_id") is not None


def host_document_code_id(spec: dict[str, Any]) -> int:
    return int(spec["host_document_code_id"])


def form_type_sql(spec: dict[str, Any]) -> str:
    return str(int(spec.get("form_type") or 9469))


def option_parts(option: Any) -> tuple[str, str, str]:
    """Return CodeName, Code, ExternalCode1. Radios persist ExternalCode1 (#97352)."""
    if isinstance(option, dict):
        name = (option.get("code_name") or option.get("name") or "").strip()
        ext = (option.get("external_code1") or option.get("code") or "").strip()
        code = (option.get("code") or ext).strip()
    else:
        name = str(option or "").strip()
        ext = re.sub(r"[^A-Za-z0-9]", "", name)[:20]
        code = ext
    return name, code, ext


def ensure_guids(spec: dict[str, Any]) -> bool:
    changed = False
    if not spec.get("form_guid"):
        spec["form_guid"] = new_guid_upper()
        changed = True
    if not spec.get("document_code_guid"):
        spec["document_code_guid"] = new_guid_lower()
        changed = True
    if not spec.get("screen_guid"):
        spec["screen_guid"] = new_guid_lower()
        changed = True
    for i, section in enumerate(spec["sections"], start=1):
        if not section.get("id"):
            section["id"] = f"sec{i}"
            changed = True
        if section.get("sort_order") is None:
            section["sort_order"] = i * 10
            changed = True
        if section.get("number_of_columns") is None:
            section["number_of_columns"] = 1
            changed = True
        if not section.get("form_section_guid"):
            section["form_section_guid"] = new_guid_upper()
            changed = True
        for j, group in enumerate(section["groups"], start=1):
            if not group.get("id"):
                group["id"] = f"{section['id']}_g{j}"
                changed = True
            if group.get("sort_order") is None:
                group["sort_order"] = j * 10
                changed = True
            if group.get("number_of_items_in_row") is None:
                group["number_of_items_in_row"] = 1
                changed = True
            if not group.get("form_section_group_guid"):
                group["form_section_group_guid"] = new_guid_upper()
                changed = True
            for k, field in enumerate(group["fields"], start=1):
                if not field.get("id"):
                    field["id"] = f"{group['id']}_f{k}"
                    changed = True
                if field.get("sort_order") is None:
                    field["sort_order"] = k * 10
                    changed = True
                if not field.get("form_item_guid"):
                    field["form_item_guid"] = new_guid_upper()
                    changed = True
                defaults_for_field(field)
    for cat in spec.get("global_code_categories") or []:
        if not cat.get("category_row_identifier"):
            cat["category_row_identifier"] = new_guid_upper()
            changed = True
    return changed


def generate_01(spec: dict[str, Any]) -> str:
    db = spec.get("target_database") or "YourSmartCareDatabase"
    table = spec["table_name"]
    form_name = spec["form_name"]
    doc_name = spec["document_name"]
    form_guid = spec["form_guid"]
    doc_guid = spec["document_code_guid"]
    screen_guid = spec["screen_guid"]
    cols = main_table_columns(spec)
    if cols:
        col_inserts = ",\n    ".join(f"(N'{esc(n)}')" for n, _t in cols)
        expected_block = f"""
DECLARE @Expected TABLE (ItemColumnName SYSNAME NOT NULL);
INSERT INTO @Expected (ItemColumnName) VALUES
    {col_inserts};

IF OBJECT_ID(N'dbo.' + @TableName, N'U') IS NOT NULL
BEGIN
    INSERT INTO @Checks (CheckName, Status, Detail)
    SELECT
        N'MissingColumn',
        N'WARN',
        N'Column ' + e.ItemColumnName + N' not on table yet (apply will ADD).'
    FROM @Expected AS e
    WHERE COL_LENGTH(N'dbo.' + @TableName, e.ItemColumnName) IS NULL;
END
"""
    else:
        expected_block = """
INSERT INTO @Checks VALUES ('Columns', 'OK', N'No custom data columns (label-only form).');
"""
    reused_blocks: list[str] = []
    for cat in reused_global_code_categories(spec):
        reused_blocks.append(
            f"""
IF NOT EXISTS (
    SELECT 1 FROM dbo.GlobalCodeCategories
    WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = {sql_str(cat)}
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('GlobalCodes:{esc(cat)}', 'BLOCKER', N'Category {esc(cat)} is missing. Form radios/dropdowns reuse it; do not create a new X* list.');
ELSE IF NOT EXISTS (
    SELECT 1 FROM dbo.GlobalCodes
    WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = {sql_str(cat)}
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('GlobalCodes:{esc(cat)}', 'BLOCKER', N'Category {esc(cat)} exists but has no active codes.');
ELSE
    INSERT INTO @Checks VALUES ('GlobalCodes:{esc(cat)}', 'OK', N'Reusing existing category {esc(cat)}.');
"""
        )
    reused_cat_sql = "\n".join(reused_blocks)
    host_precheck_sql = ""
    if is_host_custom_fields_tab(spec):
        host_id = host_document_code_id(spec)
        host_precheck_sql = f"""
DECLARE @HostDocumentCodeId INT = {host_id};

IF NOT EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @HostDocumentCodeId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('HostDocument', 'BLOCKER', N'DocumentCode {host_id} is missing or inactive.');
ELSE
    INSERT INTO @Checks VALUES ('HostDocument', 'OK', N'Host DocumentCode {host_id} is active.');

IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @HostDocumentCodeId
      AND FormCollectionId IS NOT NULL
)
    INSERT INTO @Checks VALUES ('HostFormCollection', 'BLOCKER', N'Host {host_id} has FormCollectionId. Extra tab is CustomFieldFormId only.');
ELSE
    INSERT INTO @Checks VALUES ('HostFormCollection', 'OK', N'Host FormCollectionId is NULL.');

IF NOT EXISTS (
    SELECT 1 FROM dbo.Screens
    WHERE DocumentCodeId = @HostDocumentCodeId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('HostScreen', 'BLOCKER', N'No active Screen for DocumentCode {host_id}.');
ELSE IF EXISTS (
    SELECT 1
    FROM dbo.Screens AS s
    LEFT JOIN dbo.Forms AS f ON f.FormId = s.CustomFieldFormId
    WHERE s.DocumentCodeId = @HostDocumentCodeId
      AND s.Active = N'Y'
      AND ISNULL(s.RecordDeleted, N'N') = N'N'
      AND s.CustomFieldFormId IS NOT NULL
      AND ISNULL(f.FormGUID, '{form_guid}') <> '{form_guid}'
)
    INSERT INTO @Checks VALUES ('HostCustomFields', 'BLOCKER', N'Host screen already has a different CustomFieldFormId.');
ELSE IF EXISTS (
    SELECT 1 FROM dbo.Screens
    WHERE DocumentCodeId = @HostDocumentCodeId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
      AND CustomFieldFormId IS NOT NULL
)
    INSERT INTO @Checks VALUES ('HostCustomFields', 'WARN', N'Host CustomFieldFormId already points at this form (rerun).');
ELSE
    INSERT INTO @Checks VALUES ('HostCustomFields', 'OK', N'Host CustomFieldFormId is NULL (no extra tab yet).');

IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @HostDocumentCodeId
      AND (N',' + REPLACE(ISNULL(TableList, N''), N' ', N'') + N',') LIKE N'%,{esc(table)},%'
)
    INSERT INTO @Checks VALUES ('HostTableList', 'WARN', N'Host TableList already includes {esc(table)}. Do not append; vendor GET has two result sets.');
ELSE
    INSERT INTO @Checks VALUES ('HostTableList', 'OK', N'Host TableList does not include {esc(table)} (leave vendor GET as-is).');
"""
    body = f"""
SET NOCOUNT ON;

DECLARE @FormName VARCHAR(250) = {sql_str(form_name)};
DECLARE @DocumentName VARCHAR(250) = {sql_str(doc_name)};
DECLARE @TableName SYSNAME = N'{esc(table)}';
DECLARE @FormGUID UNIQUEIDENTIFIER = '{form_guid}';
DECLARE @DocumentCodeGuid VARCHAR(100) = '{esc(doc_guid)}';
DECLARE @ScreenGuid VARCHAR(100) = '{esc(screen_guid)}';

DECLARE @Checks TABLE (
    CheckName VARCHAR(80) NOT NULL,
    Status VARCHAR(10) NOT NULL,
    Detail NVARCHAR(1000) NULL
);

IF OBJECT_ID(N'dbo.' + @TableName, N'U') IS NULL
    INSERT INTO @Checks VALUES ('Table', 'OK', N'Table does not exist yet (greenfield).');
ELSE
    INSERT INTO @Checks VALUES ('Table', 'WARN', N'Table already exists — apply will ADD missing columns only.');

IF EXISTS (
    SELECT 1 FROM dbo.Forms
    WHERE TableName = @TableName
      AND ISNULL(RecordDeleted, N'N') = N'N'
      AND FormGUID <> @FormGUID
)
    INSERT INTO @Checks VALUES ('TableNameOwner', 'BLOCKER', N'Another Form row already uses this TableName.');
ELSE
    INSERT INTO @Checks VALUES ('TableNameOwner', 'OK', N'No other Form owns this table name.');

IF EXISTS (
    SELECT 1 FROM dbo.Forms
    WHERE FormGUID = @FormGUID AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('FormGUID', 'WARN', N'FormGUID already present — apply is a rerun.');
ELSE
    INSERT INTO @Checks VALUES ('FormGUID', 'OK', N'FormGUID is new.');

IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentName = @DocumentName
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
      AND Code <> @DocumentCodeGuid
)
    INSERT INTO @Checks VALUES ('DocumentName', 'BLOCKER', N'Another DocumentCode already uses this DocumentName.');
ELSE IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE Code = @DocumentCodeGuid AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('DocumentName', 'WARN', N'DocumentCodes.Code already present — apply is a rerun.');
ELSE
    INSERT INTO @Checks VALUES ('DocumentName', 'OK', N'Document name / Code GUID are free.');

IF EXISTS (
    SELECT 1 FROM dbo.Screens
    WHERE Code = @ScreenGuid AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Checks VALUES ('ScreenGUID', 'WARN', N'Screens.Code already present — apply is a rerun.');
ELSE
    INSERT INTO @Checks VALUES ('ScreenGUID', 'OK', N'Screen GUID is new.');
{host_precheck_sql}{reused_cat_sql}{expected_block}

SELECT CheckName, Status, Detail
FROM @Checks
ORDER BY CASE Status WHEN N'BLOCKER' THEN 1 WHEN N'WARN' THEN 2 ELSE 3 END, CheckName;

IF EXISTS (SELECT 1 FROM @Checks WHERE Status = N'BLOCKER')
    RAISERROR(N'Precheck BLOCKER rows present. Do not run 03_apply_form.sql.', 16, 1);
ELSE
    PRINT N'Precheck passed (OK / WARN only). Next: 02_globalcodes.sql if present, else 03_apply_form.sql.';
"""
    return sql_header(
        "01_precheck.sql",
        f"Read-only collision check for {form_name} ({table}).",
        False,
        db,
    ) + body


def generate_02(spec: dict[str, Any]) -> str | None:
    cats = spec.get("global_code_categories") or []
    if not cats:
        return None
    db = spec.get("target_database") or "YourSmartCareDatabase"
    lines = [
        sql_header(
            "02_globalcodes.sql",
            "Idempotent GlobalCodeCategories + GlobalCodes for DFA picklists. Category parent first.",
            True,
            db,
        ),
        "SET NOCOUNT ON;",
        "BEGIN TRY",
        "BEGIN TRANSACTION;",
        "",
    ]
    for cat in cats:
        category = (cat["category"] or "").strip()
        cat_guid = cat.get("category_row_identifier") or new_guid_upper()
        ident = _ident(category)
        lines.append(f"DECLARE @Category_{ident} NVARCHAR(20) = {sql_str(category)};")
        lines.append(f"DECLARE @CatGuid_{ident} UNIQUEIDENTIFIER = '{cat_guid}';")
        lines.append(f"""
IF NOT EXISTS (
    SELECT 1 FROM dbo.GlobalCodeCategories
    WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category_{ident}))
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
INSERT INTO dbo.GlobalCodeCategories (
    Category, CategoryName, Active, AllowAddDelete, AllowCodeNameEdit, AllowSortOrderEdit,
    UserDefinedCategory, HasSubcodes, RowIdentifier, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
    PrimaryDriven, AffiliateAllowAddition, AffiliateAllowDeactivation
)
VALUES (
    @Category_{ident}, @Category_{ident}, N'Y', N'Y', N'Y', N'Y',
    N'Y', N'N', @CatGuid_{ident}, SYSTEM_USER, GETDATE(), SYSTEM_USER, GETDATE(),
    NULL, NULL, NULL
);

UPDATE dbo.GlobalCodeCategories
SET UserDefinedCategory = N'Y',
    HasSubcodes = N'N',
    PrimaryDriven = NULL,
    AffiliateAllowAddition = NULL,
    AffiliateAllowDeactivation = NULL,
    ModifiedBy = SYSTEM_USER,
    ModifiedDate = GETDATE()
WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category_{ident}))
  AND ISNULL(RecordDeleted, N'N') = N'N';
""")
        sort = 10
        for option in cat["options"]:
            name, code, ext = option_parts(option)
            if not name:
                continue
            lines.append(f"""
IF NOT EXISTS (
    SELECT 1 FROM dbo.GlobalCodes
    WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category_{ident}))
      AND RTRIM(LTRIM(CAST(CodeName AS NVARCHAR(500)))) = {sql_str(name)}
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
INSERT INTO dbo.GlobalCodes (Category, CodeName, Code, ExternalCode1, Active, SortOrder)
VALUES (@Category_{ident}, {sql_str(name)}, {sql_str(code)}, {sql_str(ext)}, N'Y', {sort});
""")
            sort += 10
    lines.append("COMMIT TRANSACTION;")
    lines.append("END TRY")
    lines.append("BEGIN CATCH")
    lines.append("    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;")
    lines.append("    THROW;")
    lines.append("END CATCH;")
    lines.append("")
    for cat in cats:
        category = (cat["category"] or "").strip()
        lines.append(f"""
SELECT Category, UserDefinedCategory, HasSubcodes, PrimaryDriven, AffiliateAllowAddition, AffiliateAllowDeactivation
FROM dbo.GlobalCodeCategories
WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = {sql_str(category)}
  AND ISNULL(RecordDeleted, N'N') = N'N';

SELECT GlobalCodeId, Category, Code, CodeName, ExternalCode1, Active, SortOrder
FROM dbo.GlobalCodes
WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = {sql_str(category)}
  AND Active = N'Y'
  AND ISNULL(RecordDeleted, N'N') = N'N'
ORDER BY SortOrder, CodeName;
""")
    return "\n".join(lines)


def _ident(name: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]", "", name)
    return s or "X"


def _create_table_sql(table: str, columns: list[tuple[str, str]], grid: bool, main_table: str | None) -> str:
    col_sql = "\n".join(f"    , [{n}] {t} NULL" for n, t in columns)
    if grid:
        pk = f"{table}id"
        fk = f"{main_table}_{table}_FK"
        return f"""IF OBJECT_ID(N'dbo.{table}', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[{table}]
    (
          [{pk}] INT NOT NULL IDENTITY(1,1)
        , [DocumentVersionId] INT NULL
        , [CreatedBy] TYPE_CURRENTUSER NOT NULL
        , [CreatedDate] TYPE_CURRENTDATETIME NOT NULL
        , [ModifiedBy] TYPE_CURRENTUSER NOT NULL
        , [ModifiedDate] TYPE_CURRENTDATETIME NOT NULL
        , [RecordDeleted] TYPE_YORN NULL
        , [DeletedBy] TYPE_USERID NULL
        , [DeletedDate] DATETIME NULL
{col_sql}
        , CONSTRAINT [{table}_PK] PRIMARY KEY ([{pk}] ASC)
    );
    ALTER TABLE [dbo].[{table}] WITH CHECK ADD CONSTRAINT [{fk}]
        FOREIGN KEY([DocumentVersionId]) REFERENCES [dbo].[{main_table}] ([DocumentVersionId]);
    ALTER TABLE [dbo].[{table}] CHECK CONSTRAINT [{fk}];
END"""
    fk = f"DocumentVersions_{table}_FK"
    return f"""IF OBJECT_ID(N'dbo.{table}', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[{table}]
    (
          [DocumentVersionId] INT NOT NULL
        , [CreatedBy] TYPE_CURRENTUSER NOT NULL
        , [CreatedDate] TYPE_CURRENTDATETIME NOT NULL
        , [ModifiedBy] TYPE_CURRENTUSER NOT NULL
        , [ModifiedDate] TYPE_CURRENTDATETIME NOT NULL
        , [RecordDeleted] TYPE_YORN NULL
        , [DeletedBy] TYPE_USERID NULL
        , [DeletedDate] DATETIME NULL
{col_sql}
        , CONSTRAINT [{table}_PK] PRIMARY KEY ([DocumentVersionId] ASC)
    );
    ALTER TABLE [dbo].[{table}] WITH CHECK ADD CONSTRAINT [{fk}]
        FOREIGN KEY([DocumentVersionId]) REFERENCES [dbo].[DocumentVersions] ([DocumentVersionId]);
    ALTER TABLE [dbo].[{table}] CHECK CONSTRAINT [{fk}];
END"""


def _add_columns_sql(table: str, columns: list[tuple[str, str]]) -> str:
    parts = []
    for name, sql_type in columns:
        parts.append(
            f"IF COL_LENGTH(N'dbo.{table}', N'{esc(name)}') IS NULL\n"
            f"    ALTER TABLE [dbo].[{table}] ADD [{name}] {sql_type} NULL;"
        )
    return "\n".join(parts)


def _log_ddl(ddl: str) -> str:
    compact = " ".join(ddl.split())
    return (
        "IF OBJECT_ID(N'dbo.DFADDLStatementLog', N'U') IS NOT NULL\n"
        f"    INSERT INTO dbo.DFADDLStatementLog (DDLStatement) VALUES (N'{esc(compact)}');\n"
    )


def generate_document_validations_sql(spec: dict[str, Any]) -> str:
    rules = spec.get("document_validations") or []
    if not rules:
        return ""
    table = spec["table_name"]
    inserts: list[str] = []
    for rule in rules:
        col = rule["column_name"]
        logic = (rule.get("validation_logic") or "").replace("{table}", table)
        tab = rule.get("tab_name") or "1"
        tab_order = int(rule.get("tab_order") or 0)
        order = int(rule["validation_order"])
        desc = rule.get("validation_description")
        err = rule.get("error_message") or col
        section = rule.get("section_name")
        doc_type = int(rule.get("document_type") or 10)
        inserts.append(
            f"""
IF NOT EXISTS (
    SELECT 1
    FROM dbo.DocumentValidations
    WHERE DocumentCodeId = @DocumentCodeId
      AND TableName = {sql_str(table)}
      AND ColumnName = {sql_str(col)}
      AND ISNULL(ValidationOrder, -999) = {order}
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO dbo.DocumentValidations (
        Active, DocumentCodeId, DocumentType, TabName, TabOrder,
        TableName, ColumnName, ValidationLogic, ValidationDescription,
        ValidationOrder, ErrorMessage, SectionName,
        CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, RecordDeleted
    )
    VALUES (
        N'Y', @DocumentCodeId, {doc_type}, {sql_str(tab)}, {tab_order},
        {sql_str(table)}, {sql_str(col)}, {sql_str(logic)}, {sql_str(desc)},
        {order}, {sql_str(err)}, {sql_str(section)},
        SYSTEM_USER, GETDATE(), SYSTEM_USER, GETDATE(), N'N'
    );
"""
        )
    return "\n".join(inserts)


def generate_03(spec: dict[str, Any], form_javascript: str | None = None) -> str:
    db = spec.get("target_database") or "YourSmartCareDatabase"
    table = spec["table_name"]
    form_name = spec["form_name"]
    doc_name = spec["document_name"]
    screen_name = spec["screen_name"]
    coll_name = spec["form_collection_name"]
    form_guid = spec["form_guid"]
    doc_guid = spec["document_code_guid"]
    screen_guid = spec["screen_guid"]
    service_note = spec.get("service_note") or "N"
    requires_sig = spec.get("requires_signature") or "Y"
    patient_consent_sql = dfa_flag_sql(spec, "patient_consent", None)
    default_co_signer_sql = dfa_flag_sql_keys(spec, ("default_co_signer", "default_cosigner"), "Y")
    default_guardian_sql = dfa_flag_sql(spec, "default_guardian", None)
    recreate_pdf_sql = dfa_flag_sql(spec, "recreate_pdf_on_client_signature", None)
    rdl = spec.get("view_document_rdl") or "RDLDFACommonReport"
    sp = spec.get("stored_procedure") or "ssp_GetDFADocumentsData"
    val_sp = spec.get("validation_stored_procedure")
    val_sp_sql = sql_str(val_sp) if val_sp else "NULL"
    main_cols = main_table_columns(spec)
    create_main = _create_table_sql(table, main_cols, False, None)
    add_main = _add_columns_sql(table, main_cols)
    js_sql = sql_str(form_javascript) if form_javascript else "NULL"
    override_sql = javascript_override_sql(spec, bool(form_javascript))

    form_type = form_type_sql(spec)
    purpose = (
        f"Create or reuse {form_name} as Custom Fields tab on DocumentCode "
        f"{host_document_code_id(spec)}. Table + Forms only. Do not INSERT DocumentCodes/Screens. "
        "No IDENTITY_INSERT. Match Forms by GUID."
        if is_host_custom_fields_tab(spec)
        else (
            f"Create or reuse {form_name}: table, Form metadata, FormCollection, DocumentCodes, Screens. "
            "No IDENTITY_INSERT. Match existing rows by GUID."
        )
    )
    lines: list[str] = [
        sql_header(
            "03_apply_form.sql",
            purpose,
            True,
            db,
        ),
        "SET NOCOUNT ON;",
        "BEGIN TRY",
        "BEGIN TRANSACTION;",
        "",
        "DECLARE @FormId INT;",
        "DECLARE @FormSectionId INT;",
        "DECLARE @FormSectionGroupId INT;",
        "DECLARE @FormItemId INT;",
        "DECLARE @FormCollectionId INT;",
        "DECLARE @DocumentCodeId INT;",
        "DECLARE @ScreenId INT;",
        "DECLARE @FormGUID UNIQUEIDENTIFIER;",
        "DECLARE @FormSectionGUID UNIQUEIDENTIFIER;",
        "DECLARE @FormSectionGroupGUID UNIQUEIDENTIFIER;",
        "DECLARE @FormItemGUID UNIQUEIDENTIFIER;",
        "DECLARE @DocumentCodeGuid VARCHAR(100);",
        "DECLARE @ScreenGuid VARCHAR(100);",
        "DECLARE @Sections TABLE (FormSectionGUID UNIQUEIDENTIFIER NOT NULL, FormSectionId INT NOT NULL);",
        "DECLARE @Groups TABLE (FormSectionGroupGUID UNIQUEIDENTIFIER NOT NULL, FormSectionGroupId INT NOT NULL);",
        "",
        f"SET @FormGUID = '{form_guid}';",
        f"SET @DocumentCodeGuid = '{esc(doc_guid)}';",
        f"SET @ScreenGuid = '{esc(screen_guid)}';",
        "",
        create_main + ";",
        _log_ddl(create_main),
        add_main,
        "",
    ]

    for _section, group in iter_groups(spec):
        if group.get("grid_type") != "G":
            continue
        gt = group["custom_grid_table_name"]
        gcols = grid_table_columns(group)
        create_g = _create_table_sql(gt, gcols, True, table)
        lines.append(create_g + ";")
        lines.append(_log_ddl(create_g))
        lines.append(_add_columns_sql(gt, gcols))
        lines.append("")

    lines.append(f"""
SELECT @FormId = FormId
FROM dbo.Forms
WHERE FormGUID = @FormGUID
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @FormId IS NULL
BEGIN
    INSERT INTO dbo.Forms (
        FormName, TableName, TotalNumberOfColumns, Active, RetrieveStoredProcedure,
        FormType, FormJavascript, IsJavascriptOverride, FormGUID, Core, FormCustomIdentIFier
    )
    VALUES (
        {sql_str(form_name)}, {sql_str(table)}, 1, N'Y', NULL,
        {form_type}, {js_sql}, {override_sql}, @FormGUID, NULL, NULL
    );
    SELECT @FormId = FormId
    FROM dbo.Forms
    WHERE FormGUID = @FormGUID AND ISNULL(RecordDeleted, N'N') = N'N';
END
ELSE
    UPDATE dbo.Forms
    SET TableName = {sql_str(table)},
        FormName = {sql_str(form_name)},
        FormType = {form_type},
        FormJavascript = {js_sql},
        IsJavascriptOverride = {override_sql},
        ModifiedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE FormId = @FormId;
""")

    for section in spec["sections"]:
        sec_guid = section["form_section_guid"]
        en_cb, en_text, en_col = section_enable_sql(section)
        lines.append(f"""
SET @FormSectionId = NULL;
SET @FormSectionGUID = '{sec_guid}';
SELECT @FormSectionId = FormSectionId
FROM dbo.FormSections
WHERE FormSectionGUID = @FormSectionGUID
  AND FormId = @FormId
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @FormSectionId IS NULL
BEGIN
    INSERT INTO dbo.FormSections (
        FormId, SortOrder, PlaceOnTopOfPage, SectionLabel, Active,
        SectionEnableCheckBox, SectionEnableCheckBoxText, SectionEnableCheckBoxColumnName,
        NumberOfColumns, ShowPencilIcon, FormSectionGUID, FormSectionCustomIdentIFier
    )
    VALUES (
        @FormId, {int(section['sort_order'])}, NULL, {sql_str(section['section_label'])}, N'Y',
        {en_cb}, {en_text}, {en_col},
        {int(section.get('number_of_columns') or 1)}, NULL, @FormSectionGUID, NULL
    );
    SELECT @FormSectionId = FormSectionId
    FROM dbo.FormSections
    WHERE FormSectionGUID = @FormSectionGUID AND FormId = @FormId AND ISNULL(RecordDeleted, N'N') = N'N';
END
ELSE
    UPDATE dbo.FormSections
    SET SectionLabel = {sql_str(section['section_label'])},
        SortOrder = {int(section['sort_order'])},
        NumberOfColumns = {int(section.get('number_of_columns') or 1)},
        SectionEnableCheckBox = {en_cb},
        SectionEnableCheckBoxText = {en_text},
        SectionEnableCheckBoxColumnName = {en_col},
        ModifiedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE FormSectionId = @FormSectionId;

INSERT INTO @Sections (FormSectionGUID, FormSectionId) VALUES (@FormSectionGUID, @FormSectionId);
""")
        for group in section["groups"]:
            grp_guid = group["form_section_group_guid"]
            grid_type = group.get("grid_type")
            grid_type_sql = sql_str(grid_type) if grid_type else "NULL"
            grid_table_sql = (
                sql_str(group.get("custom_grid_table_name"))
                if group.get("custom_grid_table_name")
                else "NULL"
            )
            group_label_sql = sql_str(group.get("group_label")) if group.get("group_label") else "NULL"
            lines.append(f"""
SET @FormSectionGroupId = NULL;
SET @FormSectionGroupGUID = '{grp_guid}';
SELECT @FormSectionId = FormSectionId FROM @Sections WHERE FormSectionGUID = '{sec_guid}';
SELECT @FormSectionGroupId = FormSectionGroupId
FROM dbo.FormSectionGroups
WHERE FormSectionGroupGUID = @FormSectionGroupGUID
  AND FormSectionId = @FormSectionId
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @FormSectionGroupId IS NULL
BEGIN
    INSERT INTO dbo.FormSectionGroups (
        FormSectionId, SortOrder, GroupLabel, Active, GroupEnableCheckBox, GroupEnableCheckBoxText,
        GroupEnableCheckBoxColumnName, NumberOfItemsInRow, GroupName, ShowPencilIcon,
        FormSectionGroupGUID, FormSectionGroupCustomIdentIFier, GridType, CustomGridtableName,
        TableStoredProcedureName
    )
    VALUES (
        @FormSectionId, {int(group['sort_order'])}, {group_label_sql}, N'Y', NULL, NULL,
        NULL, {int(group.get('number_of_items_in_row') or 1)}, {sql_str(group['group_name'])}, NULL,
        @FormSectionGroupGUID, NULL, {grid_type_sql}, {grid_table_sql},
        NULL
    );
    SELECT @FormSectionGroupId = FormSectionGroupId
    FROM dbo.FormSectionGroups
    WHERE FormSectionGroupGUID = @FormSectionGroupGUID
      AND FormSectionId = @FormSectionId
      AND ISNULL(RecordDeleted, N'N') = N'N';
END

INSERT INTO @Groups (FormSectionGroupGUID, FormSectionGroupId)
VALUES (@FormSectionGroupGUID, @FormSectionGroupId);
""")

    for section in spec["sections"]:
        sec_guid = section["form_section_guid"]
        for group in section["groups"]:
            grp_guid = group["form_section_group_guid"]
            for field in group["fields"]:
                defaults_for_field(field)
                t = int(field["item_type"])
                col = item_column_name(field)
                gc = field.get("global_code_category")
                gc_sql = sql_str(str(gc).strip()) if gc else "NULL"
                dt_sql = "'G'" if needs_dropdown_g(field) else "NULL"
                mfeh = sql_int_or_null(field.get("multiline_edit_field_height"))
                radio_nl = (
                    "N'Y'"
                    if (field.get("each_radio_button_on_new_line") or "").upper() == "Y"
                    else "NULL"
                )
                cgw = grid_width_sql(field, group)
                cgh = grid_header_sql(field, group)
                show_g = "Y" if group.get("grid_type") == "G" else "N"
                show_p = "Y" if group.get("grid_type") == "G" else "N"
                item_guid = field["form_item_guid"]
                lines.append(f"""
SET @FormItemId = NULL;
SET @FormItemGUID = '{item_guid}';
SELECT @FormSectionId = FormSectionId FROM @Sections WHERE FormSectionGUID = '{sec_guid}';
SELECT @FormSectionGroupId = FormSectionGroupId FROM @Groups WHERE FormSectionGroupGUID = '{grp_guid}';
SELECT @FormItemId = FormItemId
FROM dbo.FormItems
WHERE FormItemGUID = @FormItemGUID
  AND FormSectionGroupId = @FormSectionGroupId
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @FormItemId IS NULL
BEGIN
    INSERT INTO dbo.FormItems (
        FormSectionId, FormSectionGroupId, ItemType, ItemLabel, SortOrder, Active, GlobalCodeCategory,
        ItemColumnName, ItemRequiresComment, ItemCommentColumnName, ItemWidth, MaximumLength, DropdownType,
        SharedTableName, StoredProcedureName, ValueField, TextField, MultilineEditFieldHeight,
        EachRadioButtonOnNewLine, InformationIcon, InformationIconStoredProcedure, ExcludeFROMPencilIcon,
        HasStoredProcedureParameter, Filter, FilterName, FormItemGUID, FormItemCustomIdentIFier,
        CustomGridColumnWidth, CustomGridColumnHeader, CustomGridShowInGrid, CustomGridShowInPDF
    )
    VALUES (
        @FormSectionId, @FormSectionGroupId, '{t}', {sql_str(field['label'])}, {int(field['sort_order'])},
        N'Y', {gc_sql}, {sql_str(col)}, N'N', NULL, {int(field['item_width'])}, {int(field['maximum_length'])},
        {dt_sql}, NULL, NULL, NULL, NULL, {mfeh}, {radio_nl}, NULL, NULL, NULL, NULL, NULL, NULL,
        @FormItemGUID, NULL, {cgw}, {cgh}, '{show_g}', '{show_p}'
    );
END
""")

    if is_host_custom_fields_tab(spec):
        host_id = host_document_code_id(spec)
        wiring_sql = f"""
SELECT @DocumentCodeId = DocumentCodeId
FROM dbo.DocumentCodes
WHERE DocumentCodeId = {host_id}
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @DocumentCodeId IS NULL
    THROW 50001, N'Host DocumentCode {host_id} not found.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @DocumentCodeId
      AND FormCollectionId IS NOT NULL
)
    THROW 50002, N'Host {host_id} has FormCollectionId. Extra tab is CustomFieldFormId only.', 1;

SELECT @ScreenId = ScreenId
FROM dbo.Screens
WHERE DocumentCodeId = @DocumentCodeId
  AND Active = N'Y'
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @ScreenId IS NULL
    THROW 50003, N'Host {host_id} has no active Screen.', 1;

UPDATE dbo.Screens
SET CustomFieldFormId = @FormId,
    ModifiedBy = SYSTEM_USER,
    ModifiedDate = GETDATE()
WHERE ScreenId = @ScreenId;

SET @FormCollectionId = NULL;
"""
        apply_print = (
            "PRINT N'Apply committed on ' + DB_NAME() + N'. Host DocumentCode "
            + str(host_id)
            + " CustomFieldFormId set. Next: 04_postcheck.sql, then Refresh Shared Tables and log out/in.';"
        )
    else:
        wiring_sql = f"""
SELECT @FormCollectionId = (
    SELECT TOP 1 fcf.FormCollectionId
    FROM dbo.FormCollectionForms AS fcf
    WHERE fcf.FormId = @FormId
      AND fcf.Active = N'Y'
      AND ISNULL(fcf.RecordDeleted, N'N') = N'N'
    ORDER BY fcf.FormOrder
);

IF @FormCollectionId IS NULL
BEGIN
    INSERT INTO dbo.FormCollections (NumberOfForms, CollectionType, FormCollectionName)
    VALUES (1, 11126725, {sql_str(coll_name)});
    SET @FormCollectionId = SCOPE_IDENTITY();
END

IF NOT EXISTS (
    SELECT 1 FROM dbo.FormCollectionForms
    WHERE FormCollectionId = @FormCollectionId
      AND FormId = @FormId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO dbo.FormCollectionForms (FormCollectionId, FormId, Active, FormOrder)
    VALUES (@FormCollectionId, @FormId, N'Y', 10);

SELECT @DocumentCodeId = DocumentCodeId
FROM dbo.DocumentCodes
WHERE Code = @DocumentCodeGuid
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @DocumentCodeId IS NULL
BEGIN
    INSERT INTO dbo.DocumentCodes (
        DocumentName, DocumentDescription, DocumentType, Active, ServiceNote, PatientConsent, ViewDocument,
        OnlyAvailableOnline, ImageFormatType, DefaultImageFolderId, ImageFormat, ViewDocumentURL, ViewDocumentRDL,
        StoredProcedure, TableList, RequiresSignature, ViewOnlyDocument, DocumentSchema, DocumentHTML, DocumentURL,
        ToBeInitialized, InitializationProcess, InitializationStoredProcedure, FormCollectionId,
        ValidationStoredProcedure, ViewStoredProcedure, MetadataFormId, TextTemplate, RequiresLicensedSignature,
        ReviewFormId, MedicationReconciliationDocument, NewValidationStoredProcedure, AllowEditingByNonAuthors,
        EnableEditValidationStoredProcedure, MultipleCredentials, RecreatePDFOnClientSignature, DiagnosisDocument,
        RegenerateRDLOnCoSignature, DefaultCoSigner, DefaultGuardian, Need5Columns, SignatureDateAsEffectiveDate,
        FamilyHistoryDocument, CoSignerRDL, ShareDocumentOnSave, DSMV, ExcludeFromBatchSigning,
        DaysDocumentEditableAfterSignature, Mobile, AllowClientPortalUserAsAuthor, PrintOrder, DisclosurePrintOrder,
        ClientOrder, Code, AllowVersionAuthorToSign, DefaultStaffCoSigner, EditableAfterSignature, ROI,
        MobileFormCollectionId, MobileTableList, ThirdPartyAuthorizationDocument, ConsentDocument,
        DefaultHealthcareDecisionMaker, DefaultAcknowledgedByStaffId, EnableDocumentAcknowledgement,
        DefaultRoleToAcknowledge, CarePlan, ClinicalNoteType, ExcludeFromCDAGRule, HeaderFontSize, ContentFontSize,
        AllowDocumentCreationForInactiveClients, PageDataSetName, EncounterForm, DynamicDocumentRDL,
        CarePlanAllowToSelectAssessmentForInitialization, CarePlanTimePeriodInMonths, LaboratoryType, LabTypeInternal,
        LabTypeExternal, LabTypeInternalXDays, LabTypeExternalXDays, AllLabsXDays,
        CreateInProgressVersionStaffDeclinesToCoSign, CreateInProgressVersionClientGuardianDeclinesToCoSign,
        AgeOfMajority, DefaultLegalGuardian, ShowAliasNameOnPDF, InitializeServiceNoteByProgram,
        InitializeServiceNoteByProcedure, InitializeServiceNoteByClinician
    )
    VALUES (
        {sql_str(doc_name)}, NULL, 10, N'Y', N'{esc(service_note)}', {patient_consent_sql}, NULL,
        N'N', NULL, NULL, NULL, {sql_str(rdl)}, {sql_str(rdl)},
        {sql_str(sp)}, {sql_str(table)}, N'{esc(requires_sig)}', NULL, NULL, NULL, NULL,
        N'Y', 5850, NULL, @FormCollectionId,
        {val_sp_sql}, {sql_str(sp)}, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL,
        NULL, NULL, {recreate_pdf_sql}, NULL,
        NULL, {default_co_signer_sql}, {default_guardian_sql}, NULL, NULL,
        NULL, N'RDLCoreCoSignatures', NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL,
        NULL, @DocumentCodeGuid, NULL, NULL, N'Y',
        NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL
    );
    SELECT @DocumentCodeId = DocumentCodeId
    FROM dbo.DocumentCodes
    WHERE Code = @DocumentCodeGuid AND ISNULL(RecordDeleted, N'N') = N'N';
END
ELSE
    UPDATE dbo.DocumentCodes
    SET FormCollectionId = @FormCollectionId,
        TableList = {sql_str(table)},
        ViewDocumentURL = {sql_str(rdl)},
        ViewDocumentRDL = {sql_str(rdl)},
        StoredProcedure = {sql_str(sp)},
        ViewStoredProcedure = {sql_str(sp)},
        ServiceNote = N'{esc(service_note)}',
        RequiresSignature = N'{esc(requires_sig)}',
        PatientConsent = {patient_consent_sql},
        DefaultCoSigner = {default_co_signer_sql},
        DefaultGuardian = {default_guardian_sql},
        RecreatePDFOnClientSignature = {recreate_pdf_sql},
        ValidationStoredProcedure = {val_sp_sql},
        CoSignerRDL = N'RDLCoreCoSignatures',
        ModifiedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE DocumentCodeId = @DocumentCodeId;

SELECT @ScreenId = ScreenId
FROM dbo.Screens
WHERE Code = @ScreenGuid
  AND ISNULL(RecordDeleted, N'N') = N'N';

IF @ScreenId IS NULL
BEGIN
    INSERT INTO dbo.Screens (
        ScreenName, ScreenType, ScreenURL, ScreenToolbarURL, TabId, InitializationStoredProcedure,
        ValidationStoredProcedureUpdate, ValidationStoredProcedureComplete, WarningStoredProcedureComplete,
        PostUpdateStoredProcedure, RefreshPermissionsAfterUpdate, DocumentCodeId, HelpURL, MessageReferenceType,
        PrimaryKeyName, WarningStoreProcedureUpdate, KeyPhraseCategory, ScreenParamters, Code,
        SynchronizeStoredProcedureUpdate, AllowedToOpenDirectly, Active, CareCoordination
    )
    VALUES (
        {sql_str(screen_name)}, 5763, N'/CommonUserControls/DFASingleTabDocuments.ascx', N'', 2, NULL,
        NULL, NULL, NULL,
        NULL, NULL, @DocumentCodeId, NULL, NULL,
        NULL, NULL, NULL, NULL, @ScreenGuid,
        NULL, N'Y', N'Y', NULL
    );
    SELECT @ScreenId = ScreenId
    FROM dbo.Screens
    WHERE Code = @ScreenGuid AND ISNULL(RecordDeleted, N'N') = N'N';
END
ELSE
    UPDATE dbo.Screens
    SET DocumentCodeId = @DocumentCodeId,
        CustomFieldFormId = NULL,
        ScreenURL = N'/CommonUserControls/DFASingleTabDocuments.ascx',
        ModifiedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE ScreenId = @ScreenId;
"""
        apply_print = (
            "PRINT N'Apply committed on ' + DB_NAME() + N'. Next: 04_postcheck.sql, "
            "then Refresh Shared Tables and log out/in.';"
        )

    lines.append(f"""
{wiring_sql}
{generate_document_validations_sql(spec)}
COMMIT TRANSACTION;

SELECT
    DB_NAME() AS DbName,
    @FormId AS FormId,
    @FormCollectionId AS FormCollectionId,
    @DocumentCodeId AS DocumentCodeId,
    @ScreenId AS ScreenId,
    @FormGUID AS FormGUID,
    @DocumentCodeGuid AS DocumentCodeGuid,
    @ScreenGuid AS ScreenGuid;

{apply_print}
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
""")
    return "\n".join(lines)


def generate_04(spec: dict[str, Any], form_javascript: str | None = None) -> str:
    db = spec.get("target_database") or "YourSmartCareDatabase"
    table = spec["table_name"]
    form_guid = spec["form_guid"]
    doc_guid = spec["document_code_guid"]
    screen_guid = spec["screen_guid"]
    expected_items = sum(1 for _s, _g, _f in iter_fields(spec))
    cols = main_table_columns(spec)
    if cols:
        col_inserts = ",\n    ".join(f"(N'{esc(n)}')" for n, _t in cols)
        column_check_sql = f"""
DECLARE @Expected TABLE (ItemColumnName SYSNAME NOT NULL);
INSERT INTO @Expected (ItemColumnName) VALUES
    {col_inserts};

INSERT INTO @Results (CheckName, Status, Detail)
SELECT
    N'Column:' + e.ItemColumnName,
    CASE WHEN COL_LENGTH(N'dbo.' + @TableName, e.ItemColumnName) IS NULL THEN N'FAIL' ELSE N'PASS' END,
    CASE WHEN COL_LENGTH(N'dbo.' + @TableName, e.ItemColumnName) IS NULL
         THEN N'Missing on ' + @TableName
         ELSE N'Present'
    END
FROM @Expected AS e;
"""
    else:
        column_check_sql = """
INSERT INTO @Results VALUES ('Columns', 'PASS', N'No custom data columns (label-only form).');
"""
    cosigner_check = ""
    default_co_signer = spec.get("default_co_signer") or spec.get("default_cosigner") or "Y"
    if default_co_signer == "Y" and not is_host_custom_fields_tab(spec):
        cosigner_check = """
IF @DocumentCodeId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @DocumentCodeId
      AND DefaultCoSigner = N'Y'
)
    INSERT INTO @Results VALUES ('DefaultCoSigner', 'PASS', N'Client is the default co-signer.');
ELSE
    INSERT INTO @Results VALUES ('DefaultCoSigner', 'FAIL', N'DocumentCodes.DefaultCoSigner is not Y.');
"""
    if spec.get("recreate_pdf_on_client_signature") == "Y" and not is_host_custom_fields_tab(spec):
        cosigner_check += """
IF @DocumentCodeId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @DocumentCodeId
      AND RecreatePDFOnClientSignature = N'Y'
)
    INSERT INTO @Results VALUES ('RecreatePDFOnClientSignature', 'PASS', N'PDF recreates after client signature.');
ELSE
    INSERT INTO @Results VALUES ('RecreatePDFOnClientSignature', 'FAIL', N'DocumentCodes.RecreatePDFOnClientSignature is not Y.');
"""
    grid_checks: list[str] = []
    for _s, group in iter_groups(spec):
        if group.get("grid_type") != "G":
            continue
        gt = group["custom_grid_table_name"]
        grid_checks.append(
            f"""
IF OBJECT_ID(N'dbo.{esc(gt)}', N'U') IS NULL
    INSERT INTO @Results VALUES ('GridTable:{esc(gt)}', 'FAIL', N'Table missing.');
ELSE
    INSERT INTO @Results VALUES ('GridTable:{esc(gt)}', 'PASS', N'Table present.');
"""
        )
        for n, _typ in grid_table_columns(group):
            grid_checks.append(
                f"""
IF COL_LENGTH(N'dbo.{esc(gt)}', N'{esc(n)}') IS NULL
    INSERT INTO @Results VALUES ('GridCol:{esc(gt)}.{esc(n)}', 'FAIL', N'Missing.');
ELSE
    INSERT INTO @Results VALUES ('GridCol:{esc(gt)}.{esc(n)}', 'PASS', N'Present');
"""
            )
    if any(g.get("grid_type") == "G" for _s, g in iter_groups(spec)):
        grid_checks.append(
            """
IF @FormId IS NOT NULL AND EXISTS (
    SELECT 1
    FROM dbo.FormItems AS fi
    INNER JOIN dbo.FormSectionGroups AS fsg ON fsg.FormSectionGroupId = fi.FormSectionGroupId
    INNER JOIN dbo.FormSections AS fs ON fs.FormSectionId = fsg.FormSectionId
    WHERE fs.FormId = @FormId
      AND fsg.GridType = N'G'
      AND fi.CustomGridShowInGrid = N'Y'
      AND fi.ItemType IN (5367, 5369, 5379)
      AND ISNULL(fi.RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Results VALUES ('GridVisibleTypes', 'FAIL', N'Visible grid Date/Time/Phone (5367/5369/5379). Must be 5361.');
ELSE IF @FormId IS NOT NULL
    INSERT INTO @Results VALUES ('GridVisibleTypes', 'PASS', N'No visible 5367/5369/5379 grid columns.');

IF @FormId IS NOT NULL AND EXISTS (
    SELECT 1
    FROM dbo.FormItems AS fi
    INNER JOIN dbo.FormSectionGroups AS fsg ON fsg.FormSectionGroupId = fi.FormSectionGroupId
    INNER JOIN dbo.FormSections AS fs ON fs.FormSectionId = fsg.FormSectionId
    WHERE fs.FormId = @FormId
      AND fsg.GridType = N'G'
      AND fi.CustomGridShowInGrid = N'Y'
      AND ISNULL(fi.RecordDeleted, N'N') = N'N'
      AND (
            NULLIF(LTRIM(RTRIM(CAST(fi.CustomGridColumnHeader AS NVARCHAR(200)))), N'') IS NULL
         OR REPLACE(LOWER(LTRIM(RTRIM(CAST(fi.CustomGridColumnHeader AS NVARCHAR(200))))), N':', N'') IN (N'date', N'time', N'phone')
      )
)
    INSERT INTO @Results VALUES ('GridHeaders', 'FAIL', N'Visible grid header blank or Date/Time/Phone (DFA skips those labels).');
ELSE IF @FormId IS NOT NULL
    INSERT INTO @Results VALUES ('GridHeaders', 'PASS', N'Visible grid headers are set and not Date/Time/Phone.');
"""
        )
    grid_check_sql = "".join(grid_checks)
    js_check = ""
    if form_javascript:
        js_check = """
IF @FormId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.Forms
    WHERE FormId = @FormId
      AND NULLIF(LTRIM(RTRIM(CAST(FormJavascript AS NVARCHAR(MAX)))), N'') IS NOT NULL
      AND IsJavascriptOverride = N'Y'
)
    INSERT INTO @Results VALUES ('FormJavascript', 'PASS', N'FormJavascript is set and IsJavascriptOverride=Y.');
ELSE
    INSERT INTO @Results VALUES ('FormJavascript', 'FAIL', N'FormJavascript missing or IsJavascriptOverride is not Y.');
"""
    val_check = ""
    val_sp = spec.get("validation_stored_procedure")
    rules = spec.get("document_validations") or []
    if val_sp:
        val_check += f"""
IF @DocumentCodeId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @DocumentCodeId
      AND ValidationStoredProcedure = {sql_str(val_sp)}
)
    INSERT INTO @Results VALUES ('ValidationSP', 'PASS', N'ValidationStoredProcedure={esc(val_sp)}');
ELSE
    INSERT INTO @Results VALUES ('ValidationSP', 'FAIL', N'DocumentCodes.ValidationStoredProcedure is not {esc(val_sp)}.');
"""
    if rules:
        expected_val = len(rules)
        val_check += f"""
IF @DocumentCodeId IS NOT NULL AND (
    SELECT COUNT(*)
    FROM dbo.DocumentValidations
    WHERE DocumentCodeId = @DocumentCodeId
      AND ISNULL(RecordDeleted, N'N') = N'N'
      AND Active = N'Y'
) = {expected_val}
    INSERT INTO @Results VALUES ('DocumentValidations', 'PASS', N'Active rules={expected_val}');
ELSE
    INSERT INTO @Results VALUES ('DocumentValidations', 'FAIL', N'Expected {expected_val} active DocumentValidations rows.');
"""
    if is_host_custom_fields_tab(spec):
        host_id = host_document_code_id(spec)
        ft = form_type_sql(spec)
        id_lookup_sql = f"""
DECLARE @DocumentCodeId INT = {host_id};
DECLARE @ScreenId INT = (
    SELECT TOP 1 ScreenId
    FROM dbo.Screens
    WHERE DocumentCodeId = @DocumentCodeId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
);
"""
        wiring_checks_sql = f"""
IF NOT EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @DocumentCodeId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Results VALUES ('DocumentCodes', 'FAIL', N'Host {host_id} missing or inactive.');
ELSE
    INSERT INTO @Results VALUES ('DocumentCodes', 'PASS', N'Host DocumentCodeId={host_id}');

IF @ScreenId IS NULL
    INSERT INTO @Results VALUES ('Screens', 'FAIL', N'No active Screen for host {host_id}.');
ELSE
    INSERT INTO @Results VALUES ('Screens', 'PASS', N'ScreenId=' + CONVERT(VARCHAR(20), @ScreenId));

IF @FormId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.Forms
    WHERE FormId = @FormId
      AND TableName = @TableName
      AND FormType = {ft}
)
    INSERT INTO @Results VALUES ('FormType', 'PASS', N'FormType={ft} TableName=' + @TableName);
ELSE
    INSERT INTO @Results VALUES ('FormType', 'FAIL', N'Form TableName/FormType mismatch.');

IF @ScreenId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.Screens
    WHERE ScreenId = @ScreenId
      AND DocumentCodeId = @DocumentCodeId
      AND CustomFieldFormId = @FormId
      AND ScreenURL LIKE N'%NYTransitionDischargePlan%'
)
    INSERT INTO @Results VALUES ('ScreenWiring', 'PASS', N'Host CustomFieldFormId points at this form; vendor ascx unchanged.');
ELSE
    INSERT INTO @Results VALUES ('ScreenWiring', 'FAIL', N'Host CustomFieldFormId is not this form, or ScreenURL changed.');

IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE DocumentCodeId = @DocumentCodeId
      AND FormCollectionId IS NULL
      AND (N',' + REPLACE(ISNULL(TableList, N''), N' ', N'') + N',') NOT LIKE N'%,{esc(table)},%'
)
    INSERT INTO @Results VALUES ('TableList', 'PASS', N'Host TableList is still vendor-only (no {esc(table)}).');
ELSE
    INSERT INTO @Results VALUES ('TableList', 'FAIL', N'Host FormCollectionId or TableList changed. Do not append the custom table to TableList.');

IF @FormId IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.FormCollectionForms
    WHERE FormId = @FormId
      AND Active = N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Results VALUES ('FormCollection', 'PASS', N'No FormCollectionForms row (vendor extra tab).');
ELSE
    INSERT INTO @Results VALUES ('FormCollection', 'FAIL', N'FormCollectionForms exists. Do not attach this form to a collection.');

IF EXISTS (
    SELECT 1 FROM dbo.DocumentCodes
    WHERE Code = @DocumentCodeGuid
      AND ISNULL(RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Results VALUES ('NoNewDocument', 'FAIL', N'A DocumentCodes row was created for this tab GUID. Remove it.');
ELSE
    INSERT INTO @Results VALUES ('NoNewDocument', 'PASS', N'No extra New-document DocumentCode.');
"""
    else:
        id_lookup_sql = """
DECLARE @DocumentCodeId INT = (SELECT DocumentCodeId FROM dbo.DocumentCodes WHERE Code = @DocumentCodeGuid AND ISNULL(RecordDeleted, N'N') = N'N');
DECLARE @ScreenId INT = (SELECT ScreenId FROM dbo.Screens WHERE Code = @ScreenGuid AND ISNULL(RecordDeleted, N'N') = N'N');
"""
        wiring_checks_sql = """
IF @DocumentCodeId IS NULL
    INSERT INTO @Results VALUES ('DocumentCodes', 'FAIL', N'No DocumentCodes row for Code GUID.');
ELSE
    INSERT INTO @Results VALUES ('DocumentCodes', 'PASS', N'DocumentCodeId=' + CONVERT(VARCHAR(20), @DocumentCodeId));

IF @ScreenId IS NULL
    INSERT INTO @Results VALUES ('Screens', 'FAIL', N'No Screens row for Code GUID.');
ELSE
    INSERT INTO @Results VALUES ('Screens', 'PASS', N'ScreenId=' + CONVERT(VARCHAR(20), @ScreenId));

IF @FormId IS NOT NULL AND @DocumentCodeId IS NOT NULL
   AND EXISTS (
        SELECT 1
        FROM dbo.DocumentCodes AS dc
        INNER JOIN dbo.Forms AS f ON f.FormId = @FormId
        WHERE dc.DocumentCodeId = @DocumentCodeId
          AND dc.TableList = f.TableName
          AND dc.FormCollectionId IS NOT NULL
   )
    INSERT INTO @Results VALUES ('TableList', 'PASS', N'DocumentCodes.TableList matches Forms.TableName and FormCollectionId is set.');
ELSE
    INSERT INTO @Results VALUES ('TableList', 'FAIL', N'TableList / FormCollectionId mismatch.');

IF @ScreenId IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.Screens
    WHERE ScreenId = @ScreenId
      AND DocumentCodeId = @DocumentCodeId
      AND CustomFieldFormId IS NULL
      AND ScreenURL = N'/CommonUserControls/DFASingleTabDocuments.ascx'
)
    INSERT INTO @Results VALUES ('ScreenWiring', 'PASS', N'Screen URL is DFASingleTabDocuments; CustomFieldFormId is NULL.');
ELSE
    INSERT INTO @Results VALUES ('ScreenWiring', 'FAIL', N'Screen missing, CustomFieldFormId set, or DocumentCodeId mismatch.');

IF @FormId IS NOT NULL AND @DocumentCodeId IS NOT NULL AND EXISTS (
    SELECT 1
    FROM dbo.DocumentCodes AS dc
    INNER JOIN dbo.FormCollectionForms AS fcf ON fcf.FormCollectionId = dc.FormCollectionId
    WHERE dc.DocumentCodeId = @DocumentCodeId
      AND fcf.FormId = @FormId
      AND fcf.Active = N'Y'
      AND ISNULL(fcf.RecordDeleted, N'N') = N'N'
)
    INSERT INTO @Results VALUES ('FormCollection', 'PASS', N'FormCollectionForms links the form to the document.');
ELSE
    INSERT INTO @Results VALUES ('FormCollection', 'FAIL', N'FormCollectionForms link missing.');
"""
    body = f"""
SET NOCOUNT ON;

DECLARE @FormGUID UNIQUEIDENTIFIER = '{form_guid}';
DECLARE @DocumentCodeGuid VARCHAR(100) = '{esc(doc_guid)}';
DECLARE @ScreenGuid VARCHAR(100) = '{esc(screen_guid)}';
DECLARE @TableName SYSNAME = N'{esc(table)}';
DECLARE @ExpectedItemCount INT = {expected_items};

DECLARE @FormId INT = (SELECT FormId FROM dbo.Forms WHERE FormGUID = @FormGUID AND ISNULL(RecordDeleted, N'N') = N'N');
{id_lookup_sql}

DECLARE @Results TABLE (CheckName VARCHAR(80) NOT NULL, Status VARCHAR(10) NOT NULL, Detail NVARCHAR(1000) NULL);

IF @FormId IS NULL
    INSERT INTO @Results VALUES ('Form', 'FAIL', N'No Forms row for FormGUID.');
ELSE
    INSERT INTO @Results VALUES ('Form', 'PASS', N'FormId=' + CONVERT(VARCHAR(20), @FormId) + N' TableName=' + ISNULL((SELECT TableName FROM dbo.Forms WHERE FormId = @FormId), N''));

{wiring_checks_sql}

DECLARE @ItemCount INT = (
    SELECT COUNT(*)
    FROM dbo.FormItems AS fi
    INNER JOIN dbo.FormSectionGroups AS fsg ON fsg.FormSectionGroupId = fi.FormSectionGroupId
    INNER JOIN dbo.FormSections AS fs ON fs.FormSectionId = fsg.FormSectionId
    WHERE fs.FormId = @FormId
      AND ISNULL(fi.RecordDeleted, N'N') = N'N'
      AND fi.Active = N'Y'
);

IF @ItemCount = @ExpectedItemCount
    INSERT INTO @Results VALUES ('FormItems', 'PASS', N'Active FormItems=' + CONVERT(VARCHAR(20), @ItemCount));
ELSE
    INSERT INTO @Results VALUES (
        'FormItems', 'FAIL',
        N'Expected ' + CONVERT(VARCHAR(20), @ExpectedItemCount) + N' active items, found ' + CONVERT(VARCHAR(20), ISNULL(@ItemCount, 0))
    );
{column_check_sql}{cosigner_check}{grid_check_sql}{js_check}{val_check}
SELECT CheckName, Status, Detail
FROM @Results
ORDER BY CASE Status WHEN N'FAIL' THEN 1 ELSE 2 END, CheckName;

IF EXISTS (SELECT 1 FROM @Results WHERE Status = N'FAIL')
    RAISERROR(N'Postcheck FAIL rows present.', 16, 1);
ELSE
    PRINT N'Postcheck all PASS. Refresh Shared Tables, log out/in, New document, save/sign/PDF.';
"""
    return sql_header(
        "04_postcheck.sql",
        f"Verify {spec['form_name']} wiring after apply.",
        False,
        db,
    ) + body


def generate_form_run_steps(spec: dict[str, Any], has_gc: bool) -> str:
    name = spec["form_name"]
    db = spec.get("target_database") or "YourSmartCareDatabase"
    gc_step = (
        "2. GlobalCodes: [02_globalcodes.sql](SQL/02_globalcodes.sql)\n"
        "3. Apply: [03_apply_form.sql](SQL/03_apply_form.sql)\n"
        "4. Postcheck: [04_postcheck.sql](SQL/04_postcheck.sql)\n"
        if has_gc
        else "2. Apply: [03_apply_form.sql](SQL/03_apply_form.sql)  (no 02_globalcodes.sql — no picklists)\n"
        "3. Postcheck: [04_postcheck.sql](SQL/04_postcheck.sql)\n"
    )
    n = 5 if has_gc else 4
    qa = spec.get("qa_deploy") or {}
    qa_block = ""
    if qa.get("applied") and qa.get("form_id"):
        qa_block = f"""
## Environment order (after QA)

Test environment is done. Do **not** re-F5 `03` there. Next environments that are still **greenfield** (form missing): same apply SQL and **same GUIDs**. Do not use vendor DFA export or GUID-merge until the form already exists on the target.

1. `{db}`: precheck → apply → postcheck (this folder).
2. After that PASS: set `target_database` to the next non-Prod database, regenerate, then apply the same three files there.

## Prior test apply (do not re-F5 03 on that database)

Recorded in `FORM_SPEC.json` `qa_deploy`.

| Object | Id |
|--------|------|
| FormId | {qa.get("form_id")} |
| FormCollectionId | {qa.get("form_collection_id")} |
| DocumentCodeId | {qa.get("document_code_id")} |
| ScreenId | {qa.get("screen_id")} |

GUIDs: Form `{qa.get("form_guid")}`; DocumentCodes `{qa.get("document_code_guid")}`; Screens `{qa.get("screen_guid")}`.
"""
    setup = spec.get("setup_deploy") or {}
    setup_block = ""
    if setup.get("applied") and setup.get("form_id"):
        setup_block = f"""
## Prior apply record (`setup_deploy`)

| Object | Id |
|--------|------|
| FormId | {setup.get("form_id")} |
| FormCollectionId | {setup.get("form_collection_id")} |
| DocumentCodeId | {setup.get("document_code_id")} |
| ScreenId | {setup.get("screen_id")} |
"""
    extra_notes = (spec.get("run_steps_notes") or "").strip()
    extra = f"\n{extra_notes}\n" if extra_notes else ""
    if is_host_custom_fields_tab(spec):
        host_id = host_document_code_id(spec)
        uat_line = (
            f"{n + 1}. Client chart → **New** **host document** (DocumentCode "
            f"**{host_id}**) → Custom Fields / extra tab → save. "
            "Do not look for a separate New-document entry unless you created one."
        )
    else:
        uat_line = f"{n + 1}. Client chart → **New** document → **{name}** → save, sign, PDF."
    return f"""# {name} — run steps

**Database:** `{db}` · **Mutating scripts:** Human F5s in SSMS · paste output back if using an agent.

1. Precheck (read-only): [01_precheck.sql](SQL/01_precheck.sql)
{gc_step}{n}. Administration → Shared Tables → Refresh. Log out and back in.
{uat_line}

Do not use SmartCare Import DFA for these `.sql` files.
{extra}{qa_block}{setup_block}"""


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.replace("\r\n", "\n"), encoding="utf-8", newline="\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate SmartCare DFA SQL from FORM_SPEC.json")
    parser.add_argument("--spec", required=True, help="Path to FORM_SPEC.json")
    parser.add_argument("--sql-dir", default=None, help="Output SQL folder (default: <form>/SQL)")
    args = parser.parse_args(argv)

    spec_path = Path(args.spec).resolve()
    if not spec_path.is_file():
        print(f"Spec not found: {spec_path}", file=sys.stderr)
        return 1

    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    guid_changed = ensure_guids(spec)
    validate_spec(spec)
    form_javascript = load_form_javascript(spec, spec_path.parent)
    if guid_changed:
        spec_path.write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"Wrote GUIDs back to {spec_path}")

    form_dir = spec_path.parent
    sql_dir = Path(args.sql_dir).resolve() if args.sql_dir else form_dir / "SQL"
    sql_dir.mkdir(parents=True, exist_ok=True)

    write_text(sql_dir / "01_precheck.sql", generate_01(spec))
    gc_sql = generate_02(spec)
    has_gc = gc_sql is not None
    gc_path = sql_dir / "02_globalcodes.sql"
    if has_gc:
        write_text(gc_path, gc_sql)
    elif gc_path.exists():
        gc_path.unlink()
    write_text(sql_dir / "03_apply_form.sql", generate_03(spec, form_javascript))
    write_text(sql_dir / "04_postcheck.sql", generate_04(spec, form_javascript))
    write_text(form_dir / "RUN_STEPS.md", generate_form_run_steps(spec, has_gc))

    n_fields = sum(1 for _ in iter_fields(spec))
    n_cols = len(main_table_columns(spec))
    js_note = "yes" if form_javascript else "no"
    print(f"Wrote SQL under {sql_dir}")
    print(f"  fields={n_fields} main_columns={n_cols} globalcodes={'yes' if has_gc else 'no'} form_javascript={js_note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
