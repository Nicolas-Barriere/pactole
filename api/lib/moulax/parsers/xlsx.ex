defmodule Moulax.Parsers.Xlsx do
  @moduledoc false

  @zip_magic "PK\x03\x04"

  @spec xlsx?(binary()) :: boolean()
  def xlsx?(<<@zip_magic, _::binary>>), do: true
  def xlsx?(_), do: false

  @spec rows(binary()) :: {:ok, [[String.t()]]} | :error
  def rows(content) when is_binary(content) do
    with true <- xlsx?(content),
         {:ok, files} <- unzip_files(content),
         {:ok, sheet_xml} <- fetch_sheet_xml(files),
         {:ok, shared_strings} <- parse_shared_strings(files),
         {:ok, rows} <- parse_sheet_rows(sheet_xml, shared_strings) do
      {:ok, rows}
    else
      _ -> :error
    end
  end

  defp unzip_files(content) do
    case :zip.unzip(content, [:memory]) do
      {:ok, entries} ->
        files =
          Map.new(entries, fn {name, data} ->
            {List.to_string(name), data}
          end)

        {:ok, files}

      _ ->
        :error
    end
  end

  defp fetch_sheet_xml(files) do
    case Map.get(files, "xl/worksheets/sheet1.xml") do
      nil -> :error
      xml -> {:ok, xml}
    end
  end

  defp parse_shared_strings(files) do
    case Map.get(files, "xl/sharedStrings.xml") do
      nil ->
        {:ok, %{}}

      xml ->
        strings =
          Regex.scan(~r/<si\b[^>]*>(.*?)<\/si>/s, xml, capture: :all_but_first)
          |> Enum.map(fn [si_body] ->
            Regex.scan(~r/<t\b[^>]*>(.*?)<\/t>/s, si_body, capture: :all_but_first)
            |> Enum.map_join("", fn [text] -> xml_unescape(text) end)
          end)
          |> Enum.with_index()
          |> Map.new(fn {text, idx} -> {idx, text} end)

        {:ok, strings}
    end
  end

  defp parse_sheet_rows(sheet_xml, shared_strings) do
    with {:ok, document} <- parse_xml(sheet_xml) do
      rows =
        :xmerl_xpath.string(
          ~c"//*[local-name()='worksheet']/*[local-name()='sheetData']/*[local-name()='row']",
          document
        )
        |> Enum.map(&row_cells(&1, shared_strings))

      {:ok, rows}
    end
  end

  defp row_cells(row_node, shared_strings) do
    cells = :xmerl_xpath.string(~c"./*[local-name()='c']", row_node)

    indexed_cells =
      cells
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {cell_node, fallback_index}, acc ->
        col_index = column_index(cell_node, fallback_index)
        Map.put(acc, col_index, cell_value(cell_node, shared_strings))
      end)

    case Map.keys(indexed_cells) do
      [] ->
        []

      indices ->
        max_index = Enum.max(indices)
        Enum.map(0..max_index, &Map.get(indexed_cells, &1, ""))
    end
  end

  defp column_index(cell_node, fallback_index) do
    case xpath_string(~c"string(./@r)", cell_node) do
      "" ->
        fallback_index

      reference ->
        case Regex.run(~r/^[A-Z]+/, String.upcase(reference)) do
          [letters] -> letters_to_index(letters)
          _ -> fallback_index
        end
    end
  end

  defp letters_to_index(letters) do
    letters
    |> String.to_charlist()
    |> Enum.reduce(0, fn char, acc -> acc * 26 + (char - ?A + 1) end)
    |> Kernel.-(1)
  end

  defp cell_value(cell_node, shared_strings) do
    type = xpath_string(~c"string(./@t)", cell_node)

    case type do
      "s" ->
        case Integer.parse(xpath_string(~c"string(./*[local-name()='v']/text())", cell_node)) do
          {idx, ""} -> Map.get(shared_strings, idx, "")
          _ -> ""
        end

      "inlineStr" ->
        xpath_string(~c"string(./*[local-name()='is']/*[local-name()='t'])", cell_node)

      _ ->
        xpath_string(~c"string(./*[local-name()='v']/text())", cell_node)
    end
  end

  defp parse_xml(xml_binary) do
    try do
      {document, _rest} = :xmerl_scan.string(String.to_charlist(xml_binary), quiet: true)
      {:ok, document}
    catch
      _, _ -> :error
    end
  end

  defp xpath_string(path, node) do
    case :xmerl_xpath.string(path, node) do
      {:xmlObj, :string, value} -> List.to_string(value)
      value when is_list(value) -> List.to_string(value)
      _ -> ""
    end
  end

  defp xml_unescape(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&amp;", "&")
  end
end
