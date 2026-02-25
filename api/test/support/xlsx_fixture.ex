defmodule Moulax.TestXlsx do
  @moduledoc false

  def write_tmp_xlsx!(rows, basename \\ "revolut") when is_list(rows) do
    path =
      Path.join(
        System.tmp_dir!(),
        "#{basename}_#{System.unique_integer([:positive])}.xlsx"
      )

    File.write!(path, build_xlsx(rows))
    path
  end

  def build_xlsx(rows) when is_list(rows) do
    entries = [
      {~c"[Content_Types].xml", content_types_xml()},
      {~c"_rels/.rels", root_rels_xml()},
      {~c"xl/workbook.xml", workbook_xml()},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels_xml()},
      {~c"xl/worksheets/sheet1.xml", worksheet_xml(rows)}
    ]

    {:ok, {_filename, xlsx_binary}} = :zip.create(~c"fixture.xlsx", entries, [:memory])
    xlsx_binary
  end

  def revolut_rows do
    [
      [
        "Type",
        "Product",
        "Started Date",
        "Completed Date",
        "Description",
        "Amount",
        "Fee",
        "Currency",
        "State",
        "Balance"
      ],
      [
        "CARD",
        "Current",
        "2026-02-10 10:00:00",
        "2026-02-10 10:01:00",
        "Uber",
        "-12.50",
        "0.00",
        "EUR",
        "COMPLETED",
        "100.00"
      ],
      [
        "CARD",
        "Current",
        "2026-02-11 11:00:00",
        "2026-02-11 11:01:00",
        "Amazon",
        "-29.99",
        "0.00",
        "USD",
        "COMPLETED",
        "70.01"
      ]
    ]
  end

  defp content_types_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    </Types>
    """
  end

  defp root_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """
  end

  defp workbook_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
      </sheets>
    </workbook>
    """
  end

  defp workbook_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    </Relationships>
    """
  end

  defp worksheet_xml(rows) do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <sheetData>
        #{Enum.with_index(rows, 1) |> Enum.map_join("\n", &worksheet_row_xml/1)}
      </sheetData>
    </worksheet>
    """
  end

  defp worksheet_row_xml({cells, row_index}) do
    """
    <row r="#{row_index}">
      #{Enum.with_index(cells, 1) |> Enum.map_join("\n", &worksheet_cell_xml(&1, row_index))}
    </row>
    """
  end

  defp worksheet_cell_xml({value, col_index}, row_index) do
    cell_ref = "#{col_name(col_index)}#{row_index}"

    """
    <c r="#{cell_ref}" t="inlineStr"><is><t>#{xml_escape(to_string(value))}</t></is></c>
    """
  end

  defp col_name(index) when index > 0 do
    do_col_name(index, "")
  end

  defp do_col_name(0, acc), do: acc

  defp do_col_name(index, acc) do
    shifted = index - 1
    remainder = rem(shifted, 26)
    letter = <<?A + remainder>>
    do_col_name(div(shifted, 26), letter <> acc)
  end

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
