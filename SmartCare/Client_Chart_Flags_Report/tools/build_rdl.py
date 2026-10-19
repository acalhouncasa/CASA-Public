"""
Module: build_rdl.py

Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-19
Last Modified: 2026-10-19

Description:
    Write rdl/ClientChartFlags.rdl for any SmartCare site.
    The connection string contains placeholders. Replace them with the SmartCare server and database.

Usage:
    python tools/build_rdl.py

License: MIT
"""

from __future__ import annotations

from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "rdl" / "ClientChartFlags.rdl"

MULTI = ("FlagStatus", "ChartStatus", "FlagTypeId", "ProgramId", "StaffId")
SINGLE = ("DateFrom", "DateTo", "ClientIdx")

HEADER_FIELDS = [
    ("RunDateText", "System.String"),
    ("DateFromText", "System.String"),
    ("DateToText", "System.String"),
    ("FlagCount", "System.Int32"),
    ("ClientCount", "System.Int32"),
    ("ActiveCount", "System.Int32"),
    ("EndedCount", "System.Int32"),
    ("FlagStatusLabel", "System.String"),
    ("ChartStatusLabel", "System.String"),
    ("FlagTypeLabel", "System.String"),
    ("ProgramLabel", "System.String"),
    ("StaffLabel", "System.String"),
    ("ClientLabel", "System.String"),
]
DETAIL_FIELDS = [
    ("ObjectFlagId", "System.Int32"),
    ("ClientId", "System.Int32"),
    ("ClientName", "System.String"),
    ("ChartStatus", "System.String"),
    ("FlagType", "System.String"),
    ("FlagStatus", "System.String"),
    ("StartDate", "System.DateTime"),
    ("StartDateText", "System.String"),
    ("EndDateText", "System.String"),
    ("Programs", "System.String"),
    ("PrimaryClinician", "System.String"),
    ("NoteText", "System.String"),
    ("SortRank", "System.Int32"),
]
COLUMNS = [
    ("Client", "ClientName", "1.40in"),
    ("Client ID", "ClientId", "0.58in"),
    ("Chart", "ChartStatus", "0.58in"),
    ("Flag Type", "FlagType", "1.35in"),
    ("Flag", "FlagStatus", "0.62in"),
    ("Start", "StartDateText", "0.68in"),
    ("End", "EndDateText", "0.68in"),
    ("Programs", "Programs", "1.55in"),
    ("Primary Clinician", "PrimaryClinician", "1.20in"),
    ("Note", "NoteText", "1.56in"),
]


def query_params() -> str:
    parts = ["        <QueryParameters>"]
    for name in SINGLE + MULTI:
        if name in MULTI:
            value = f'=Join(Parameters!{name}.Value, ",")'
        else:
            value = f"=Parameters!{name}.Value"
        parts.append(
            f"""          <QueryParameter Name="@{name}">
            <Value>{value}</Value>
          </QueryParameter>"""
        )
    parts.append("        </QueryParameters>")
    return "\n".join(parts)


def dataset_xml(name: str, proc: str, fields: list[tuple[str, str]], with_params: bool) -> str:
    field_xml = "\n".join(
        f"""        <Field Name="{fn}">
          <DataField>{fn}</DataField>
          <rd:TypeName>{ft}</rd:TypeName>
        </Field>"""
        for fn, ft in fields
    )
    params = query_params() + "\n" if with_params else ""
    return f"""    <DataSet Name="{name}">
      <Query>
        <DataSourceName>SmartCare</DataSourceName>
{params}        <CommandType>StoredProcedure</CommandType>
        <CommandText>{proc}</CommandText>
      </Query>
      <Fields>
{field_xml}
      </Fields>
    </DataSet>"""


def textbox(name: str, value: str, bold: bool, color: str, size: str = "7pt") -> str:
    weight = "<FontWeight>Bold</FontWeight>" if bold else ""
    return f"""<Textbox Name="{name}">
                          <CanGrow>true</CanGrow>
                          <Paragraphs><Paragraph><TextRuns><TextRun>
                            <Value>{value}</Value>
                            <Style><FontFamily>Calibri</FontFamily><FontSize>{size}</FontSize>{weight}<Color>{color}</Color></Style>
                          </TextRun></TextRuns></Paragraph></Paragraphs>
                          <Style>
                            <Border><Color>#B8BFC7</Color><Style>Solid</Style><Width>0.5pt</Width></Border>
                            <BackgroundColor>{'#0A2540' if bold else '#FFFFFF'}</BackgroundColor>
                            <PaddingLeft>2pt</PaddingLeft><PaddingRight>2pt</PaddingRight>
                            <PaddingTop>1pt</PaddingTop><PaddingBottom>1pt</PaddingBottom>
                          </Style>
                        </Textbox>"""


def tablix_detail() -> str:
    cols = "\n".join(
        f"                <TablixColumn><Width>{width}</Width></TablixColumn>"
        for _h, _f, width in COLUMNS
    )
    headers = []
    details = []
    members = []
    for idx, (header, field, _width) in enumerate(COLUMNS):
        headers.append(
            f"""                    <TablixCell>
                      <CellContents>
                        {textbox(f'tblDetail_h{idx}', escape(header), True, '#FFFFFF')}
                      </CellContents>
                    </TablixCell>"""
        )
        details.append(
            f"""                    <TablixCell>
                      <CellContents>
                        {textbox(f'tblDetail_d{idx}', f'=Fields!{field}.Value', False, '#0A2540')}
                      </CellContents>
                    </TablixCell>"""
        )
        members.append("<TablixMember />")
    return f"""          <Tablix Name="tblDetail">
            <TablixBody>
              <TablixColumns>
{cols}
              </TablixColumns>
              <TablixRows>
                <TablixRow>
                  <Height>0.32in</Height>
                  <TablixCells>
{chr(10).join(headers)}
                  </TablixCells>
                </TablixRow>
                <TablixRow>
                  <Height>0.28in</Height>
                  <TablixCells>
{chr(10).join(details)}
                  </TablixCells>
                </TablixRow>
              </TablixRows>
            </TablixBody>
            <TablixColumnHierarchy><TablixMembers>{''.join(members)}</TablixMembers></TablixColumnHierarchy>
            <TablixRowHierarchy>
              <TablixMembers>
                <TablixMember><KeepWithGroup>After</KeepWithGroup><RepeatOnNewPage>true</RepeatOnNewPage></TablixMember>
                <TablixMember>
                  <Group Name="tblDetail_Details" />
                  <SortExpressions>
                    <SortExpression><Value>=Fields!SortRank.Value</Value></SortExpression>
                    <SortExpression><Value>=Fields!ClientName.Value</Value></SortExpression>
                    <SortExpression><Value>=Fields!FlagType.Value</Value></SortExpression>
                    <SortExpression><Value>=Fields!StartDate.Value</Value><Direction>Descending</Direction></SortExpression>
                  </SortExpressions>
                </TablixMember>
              </TablixMembers>
            </TablixRowHierarchy>
            <DataSetName>Detail</DataSetName>
            <Top>1.15in</Top>
            <Left>0in</Left>
            <Height>0.60in</Height>
            <Width>10.2in</Width>
          </Tablix>"""


def header_tablix() -> str:
    summary = (
        '="From " &amp; Fields!DateFromText.Value'
        ' &amp; " through " &amp; Fields!DateToText.Value'
        ' &amp; "    Flag " &amp; Fields!FlagStatusLabel.Value'
        ' &amp; "    Chart " &amp; Fields!ChartStatusLabel.Value'
        ' &amp; "    Flag type " &amp; Fields!FlagTypeLabel.Value'
        ' &amp; "    Program " &amp; Fields!ProgramLabel.Value'
        ' &amp; "    Clinician " &amp; Fields!StaffLabel.Value'
        ' &amp; "    Client " &amp; Fields!ClientLabel.Value'
        ' &amp; "    Run " &amp; Fields!RunDateText.Value'
    )
    counts = (
        '="Flags " &amp; CStr(Fields!FlagCount.Value)'
        ' &amp; "    Clients " &amp; CStr(Fields!ClientCount.Value)'
        ' &amp; "    Active " &amp; CStr(Fields!ActiveCount.Value)'
        ' &amp; "    Ended " &amp; CStr(Fields!EndedCount.Value)'
    )
    note = escape(
        "One row per client chart flag. A flag is included when its dates overlap the From and To dates. "
        "Active means the flag is still open on the To date. Programs are Requested or Enrolled enrollments. "
        "The Note column is the flag note on the chart."
    )
    return f"""          <Tablix Name="tblHeader">
            <TablixBody>
              <TablixColumns><TablixColumn><Width>10.2in</Width></TablixColumn></TablixColumns>
              <TablixRows>
                <TablixRow>
                  <Height>1.05in</Height>
                  <TablixCells>
                    <TablixCell>
                      <CellContents>
                        <Rectangle Name="rectCoverInner">
                          <ReportItems>
                            <Textbox Name="txtTitle">
                              <Paragraphs><Paragraph><TextRuns><TextRun>
                                <Value>Client Chart Flags</Value>
                                <Style><FontFamily>Calibri</FontFamily><FontSize>16pt</FontSize><FontWeight>Bold</FontWeight><Color>#0A2540</Color></Style>
                              </TextRun></TextRuns></Paragraph></Paragraphs>
                              <Top>0in</Top><Left>0in</Left><Height>0.28in</Height><Width>10.2in</Width>
                            </Textbox>
                            <Textbox Name="txtMeta">
                              <Paragraphs><Paragraph><TextRuns><TextRun>
                                <Value>{summary}</Value>
                                <Style><FontFamily>Calibri</FontFamily><FontSize>8pt</FontSize><Color>#0A2540</Color></Style>
                              </TextRun></TextRuns></Paragraph></Paragraphs>
                              <Top>0.30in</Top><Left>0in</Left><Height>0.22in</Height><Width>10.2in</Width>
                            </Textbox>
                            <Textbox Name="txtCounts">
                              <Paragraphs><Paragraph><TextRuns><TextRun>
                                <Value>{counts}</Value>
                                <Style><FontFamily>Calibri</FontFamily><FontSize>9pt</FontSize><FontWeight>Bold</FontWeight><Color>#0A2540</Color></Style>
                              </TextRun></TextRuns></Paragraph></Paragraphs>
                              <Top>0.52in</Top><Left>0in</Left><Height>0.22in</Height><Width>10.2in</Width>
                            </Textbox>
                            <Textbox Name="txtNote">
                              <Paragraphs><Paragraph><TextRuns><TextRun>
                                <Value>{note}</Value>
                                <Style><FontFamily>Calibri</FontFamily><FontSize>8pt</FontSize><Color>#1E5A8C</Color></Style>
                              </TextRun></TextRuns></Paragraph></Paragraphs>
                              <Top>0.76in</Top><Left>0in</Left><Height>0.24in</Height><Width>10.2in</Width>
                            </Textbox>
                          </ReportItems>
                          <KeepTogether>true</KeepTogether>
                        </Rectangle>
                      </CellContents>
                    </TablixCell>
                  </TablixCells>
                </TablixRow>
              </TablixRows>
            </TablixBody>
            <TablixColumnHierarchy><TablixMembers><TablixMember /></TablixMembers></TablixColumnHierarchy>
            <TablixRowHierarchy><TablixMembers><TablixMember><Group Name="tblHeader_Details" /></TablixMember></TablixMembers></TablixRowHierarchy>
            <DataSetName>Header</DataSetName>
            <Top>0in</Top><Left>0in</Left><Height>1.05in</Height><Width>10.2in</Width>
          </Tablix>"""


def parameters_xml() -> str:
    return """  <ReportParameters>
    <ReportParameter Name="DateFrom">
      <DataType>DateTime</DataType>
      <DefaultValue><Values><Value>=DateAdd("d", -365, Today())</Value></Values></DefaultValue>
      <Prompt>From date</Prompt>
    </ReportParameter>
    <ReportParameter Name="DateTo">
      <DataType>DateTime</DataType>
      <DefaultValue><Values><Value>=Today()</Value></Values></DefaultValue>
      <Prompt>To date</Prompt>
    </ReportParameter>
    <ReportParameter Name="FlagStatus">
      <DataType>String</DataType>
      <DefaultValue><Values><Value>Active</Value></Values></DefaultValue>
      <Prompt>Flag status</Prompt>
      <ValidValues>
        <ParameterValues>
          <ParameterValue><Value>Active</Value><Label>Active</Label></ParameterValue>
          <ParameterValue><Value>Ended</Value><Label>Ended</Label></ParameterValue>
          <ParameterValue><Value>All</Value><Label>All</Label></ParameterValue>
        </ParameterValues>
      </ValidValues>
      <MultiValue>true</MultiValue>
    </ReportParameter>
    <ReportParameter Name="ChartStatus">
      <DataType>String</DataType>
      <DefaultValue><Values><Value>Active</Value></Values></DefaultValue>
      <Prompt>Chart status</Prompt>
      <ValidValues>
        <ParameterValues>
          <ParameterValue><Value>Active</Value><Label>Active</Label></ParameterValue>
          <ParameterValue><Value>Inactive</Value><Label>Inactive</Label></ParameterValue>
          <ParameterValue><Value>All</Value><Label>All</Label></ParameterValue>
        </ParameterValues>
      </ValidValues>
      <MultiValue>true</MultiValue>
    </ReportParameter>
    <ReportParameter Name="FlagTypeId">
      <DataType>Integer</DataType>
      <DefaultValue><Values><Value>-1</Value></Values></DefaultValue>
      <Prompt>Flag type</Prompt>
      <ValidValues>
        <DataSetReference>
          <DataSetName>FlagTypeList</DataSetName>
          <ValueField>FlagTypeId</ValueField>
          <LabelField>FlagTypeName</LabelField>
        </DataSetReference>
      </ValidValues>
      <MultiValue>true</MultiValue>
    </ReportParameter>
    <ReportParameter Name="ProgramId">
      <DataType>Integer</DataType>
      <DefaultValue><Values><Value>-1</Value></Values></DefaultValue>
      <Prompt>Program</Prompt>
      <ValidValues>
        <DataSetReference>
          <DataSetName>ProgramList</DataSetName>
          <ValueField>ProgramId</ValueField>
          <LabelField>ProgramName</LabelField>
        </DataSetReference>
      </ValidValues>
      <MultiValue>true</MultiValue>
    </ReportParameter>
    <ReportParameter Name="StaffId">
      <DataType>Integer</DataType>
      <DefaultValue><Values><Value>-1</Value></Values></DefaultValue>
      <Prompt>Primary clinician</Prompt>
      <ValidValues>
        <DataSetReference>
          <DataSetName>StaffList</DataSetName>
          <ValueField>StaffId</ValueField>
          <LabelField>StaffName</LabelField>
        </DataSetReference>
      </ValidValues>
      <MultiValue>true</MultiValue>
    </ReportParameter>
    <ReportParameter Name="ClientIdx">
      <DataType>Integer</DataType>
      <Nullable>true</Nullable>
      <DefaultValue><Values><Value>-1</Value></Values></DefaultValue>
      <Prompt>Client ID (-1 = all)</Prompt>
    </ReportParameter>
  </ReportParameters>
  <ReportParametersLayout>
    <GridLayoutDefinition>
      <NumberOfColumns>4</NumberOfColumns>
      <NumberOfRows>2</NumberOfRows>
      <CellDefinitions>
        <CellDefinition><ColumnIndex>0</ColumnIndex><RowIndex>0</RowIndex><ParameterName>DateFrom</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>1</ColumnIndex><RowIndex>0</RowIndex><ParameterName>DateTo</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>2</ColumnIndex><RowIndex>0</RowIndex><ParameterName>FlagStatus</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>3</ColumnIndex><RowIndex>0</RowIndex><ParameterName>ChartStatus</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>0</ColumnIndex><RowIndex>1</RowIndex><ParameterName>FlagTypeId</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>1</ColumnIndex><RowIndex>1</RowIndex><ParameterName>ProgramId</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>2</ColumnIndex><RowIndex>1</RowIndex><ParameterName>StaffId</ParameterName></CellDefinition>
        <CellDefinition><ColumnIndex>3</ColumnIndex><RowIndex>1</RowIndex><ParameterName>ClientIdx</ParameterName></CellDefinition>
      </CellDefinitions>
    </GridLayoutDefinition>
  </ReportParametersLayout>"""


def build() -> str:
    datasets = "\n".join(
        [
            dataset_xml("Header", "ssp_SCClientChartFlagsHeader", HEADER_FIELDS, True),
            dataset_xml("Detail", "ssp_SCClientChartFlagsDetail", DETAIL_FIELDS, True),
            dataset_xml(
                "FlagTypeList",
                "ssp_SCClientChartFlagsFlagTypes",
                [("FlagTypeId", "System.Int32"), ("FlagTypeName", "System.String")],
                False,
            ),
            dataset_xml(
                "ProgramList",
                "ssp_SCClientChartFlagsPrograms",
                [("ProgramId", "System.Int32"), ("ProgramName", "System.String")],
                False,
            ),
            dataset_xml(
                "StaffList",
                "ssp_SCClientChartFlagsStaff",
                [("StaffId", "System.Int32"), ("StaffName", "System.String")],
                False,
            ),
        ]
    )
    footer = escape(
        "Confidential. One row per client chart flag. Programs are Requested or Enrolled enrollments."
    )
    return f"""<?xml version="1.0" encoding="utf-8"?>
<Report xmlns="http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition" xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner">
  <AutoRefresh>0</AutoRefresh>
  <DataSources>
    <DataSource Name="SmartCare">
      <ConnectionProperties>
        <DataProvider>SQL</DataProvider>
        <ConnectString>Data Source=YOUR_SQL_SERVER;Initial Catalog=YOUR_DATABASE</ConnectString>
        <Prompt>SmartCare credentials</Prompt>
      </ConnectionProperties>
      <rd:SecurityType>DataBase</rd:SecurityType>
      <rd:DataSourceID>8f4c2a61-6b17-4d0e-9a33-71c5e0b84d22</rd:DataSourceID>
    </DataSource>
  </DataSources>
  <DataSets>
{datasets}
  </DataSets>
  <ReportSections>
    <ReportSection>
        <Body>
          <ReportItems>
{header_tablix()}
{tablix_detail()}
          </ReportItems>
          <Height>2.4in</Height>
          <Style />
        </Body>
      <Width>10.2in</Width>
      <Page>
        <PageHeader>
          <Height>0.32in</Height>
          <PrintOnFirstPage>true</PrintOnFirstPage>
          <PrintOnLastPage>true</PrintOnLastPage>
          <ReportItems>
            <Textbox Name="phLeft">
              <Paragraphs><Paragraph><TextRuns><TextRun>
                <Value>Client Chart Flags</Value>
                <Style><FontFamily>Calibri</FontFamily><FontSize>8pt</FontSize><Color>#1E5A8C</Color></Style>
              </TextRun></TextRuns></Paragraph></Paragraphs>
              <Top>0.04in</Top><Left>0in</Left><Height>0.22in</Height><Width>7.2in</Width>
            </Textbox>
            <Textbox Name="phRight">
              <Paragraphs><Paragraph><TextRuns><TextRun>
                <Value>="Page " &amp; Globals!PageNumber.ToString() &amp; " of " &amp; Globals!TotalPages.ToString()</Value>
                <Style><FontFamily>Calibri</FontFamily><FontSize>8pt</FontSize><Color>#6B7280</Color></Style>
              </TextRun></TextRuns></Paragraph></Paragraphs>
              <Top>0.04in</Top><Left>7.2in</Left><Height>0.22in</Height><Width>3.0in</Width>
            </Textbox>
          </ReportItems>
        </PageHeader>
        <PageFooter>
          <Height>0.28in</Height>
          <PrintOnFirstPage>true</PrintOnFirstPage>
          <PrintOnLastPage>true</PrintOnLastPage>
          <ReportItems>
            <Textbox Name="pfNote">
              <Paragraphs><Paragraph><TextRuns><TextRun>
                <Value>{footer}</Value>
                <Style><FontFamily>Calibri</FontFamily><FontSize>7pt</FontSize><FontStyle>Italic</FontStyle><Color>#6B7280</Color></Style>
              </TextRun></TextRuns></Paragraph></Paragraphs>
              <Top>0.02in</Top><Left>0in</Left><Height>0.22in</Height><Width>10.2in</Width>
            </Textbox>
          </ReportItems>
        </PageFooter>
        <PageHeight>8.5in</PageHeight>
        <PageWidth>11in</PageWidth>
        <LeftMargin>0.4in</LeftMargin>
        <RightMargin>0.4in</RightMargin>
        <TopMargin>0.35in</TopMargin>
        <BottomMargin>0.35in</BottomMargin>
        <Style />
      </Page>
    </ReportSection>
  </ReportSections>
{parameters_xml()}
  <ConsumeContainerWhitespace>true</ConsumeContainerWhitespace>
  <rd:ReportUnitType>Inch</rd:ReportUnitType>
  <rd:ReportID>c3a91e74-5d28-4b6f-8e10-2f7a6c9d4b55</rd:ReportID>
</Report>
"""


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(build(), encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
