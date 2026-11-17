defmodule Mix.Tasks.Assets.Sizes do
  use Mix.Task

  @shortdoc "Report raw, gzip and brotli sizes of built assets"

  @moduledoc """
  Prints the size of every built JavaScript and CSS file under
  `priv/static/assets`, uncompressed and compressed, so bundle changes can be
  measured rather than guessed.

      mix assets.sizes

  Run it after `mix assets.build` (development, unminified) or
  `mix assets.deploy` (production, minified and digested). Production numbers
  are the ones that matter: they are what the browser downloads.

  Brotli sizes are shown as a dash when the `brotli` CLI is not installed.
  """

  @assets_globs ["priv/static/assets/js/**/*.js", "priv/static/assets/css/**/*.css"]

  @impl true
  def run(_argv) do
    files = @assets_globs |> Enum.flat_map(&Path.wildcard/1) |> Enum.sort()

    if files == [] do
      Mix.raise("no built assets found under priv/static/assets; run mix assets.build")
    end

    rows = Enum.map(files, &measure/1)
    print(rows)
  end

  defp measure(path) do
    contents = File.read!(path)

    %{
      path: Path.relative_to_cwd(path),
      raw: byte_size(contents),
      gzip: byte_size(:zlib.gzip(contents)),
      brotli: brotli_size(path)
    }
  end

  defp brotli_size(path) do
    with executable when is_binary(executable) <- System.find_executable("brotli"),
         {output, 0} <- System.cmd(executable, ["-q", "11", "-c", path], into: "") do
      byte_size(output)
    else
      _unavailable -> nil
    end
  end

  defp print(rows) do
    widths = column_widths(rows)

    header = [
      pad("file", widths.path),
      pad("raw", widths.raw, :right),
      pad("gzip", widths.gzip, :right),
      pad("brotli", widths.brotli, :right)
    ]

    Mix.shell().info(Enum.join(header, "  "))
    Mix.shell().info(String.duplicate("-", Enum.sum(Map.values(widths)) + 6))
    Enum.each(rows, &print_row(&1, widths))
  end

  defp print_row(row, widths) do
    values = [
      pad(row.path, widths.path),
      pad(human(row.raw), widths.raw, :right),
      pad(human(row.gzip), widths.gzip, :right),
      pad(human(row.brotli), widths.brotli, :right)
    ]

    Mix.shell().info(Enum.join(values, "  "))
  end

  defp column_widths(rows) do
    %{
      path: rows |> Enum.map(&String.length(&1.path)) |> Enum.max(),
      raw: rows |> Enum.map(&String.length(human(&1.raw))) |> Enum.max(),
      gzip: rows |> Enum.map(&String.length(human(&1.gzip))) |> Enum.max(),
      brotli: rows |> Enum.map(&String.length(human(&1.brotli))) |> Enum.max()
    }
  end

  defp pad(value, width, align \\ :left) do
    value = to_string(value)

    case align do
      :right -> String.pad_leading(value, width)
      :left -> String.pad_trailing(value, width)
    end
  end

  defp human(nil), do: "-"
  defp human(bytes) when bytes < 1024, do: "#{bytes} B"
  defp human(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"
end
