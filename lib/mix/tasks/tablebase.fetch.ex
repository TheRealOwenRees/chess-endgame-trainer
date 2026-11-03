defmodule Mix.Tasks.Tablebase.Fetch do
  use Mix.Task

  @default_mirror "http://tablebase.sesse.net/syzygy/3-4-5/"

  @shortdoc "Download the 3/4/5-piece Syzygy tablebases"

  @moduledoc """
  Downloads the complete 3/4/5-piece Syzygy WDL + DTZ set (~939 MB).

      mix tablebase.fetch --path /data/syzygy/3-4-5
      TABLEBASE_PATH=/data/syzygy/3-4-5 mix tablebase.fetch

  Existing files are skipped, so re-running resumes an interrupted download.
  Use `--mirror` to override the source (defaults to `#{@default_mirror}`), or
  `--dry-run` to see how many files are available without downloading.

  Verify the result with `mix tablebase.check`.
  """

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [path: :string, mirror: :string, dry_run: :boolean]
      )

    path =
      opts[:path] || System.get_env("TABLEBASE_PATH") ||
        Mix.raise("pass --path or set TABLEBASE_PATH, e.g. --path /data/syzygy/3-4-5")

    mirror = opts[:mirror] || @default_mirror
    path = Path.expand(path)

    {:ok, _apps} = Application.ensure_all_started(:req)

    files = list_files(mirror)

    if opts[:dry_run] do
      Mix.shell().info("Would fetch #{length(files)} files into #{path}")
    else
      File.mkdir_p!(path)
      Mix.shell().info("Fetching 3/4/5 Syzygy tablebases into #{path}")
      Mix.shell().info("#{length(files)} files to check")

      {downloaded, skipped} =
        Enum.reduce(files, {0, 0}, fn file, {downloaded, skipped} ->
          target = Path.join(path, file)

          if present?(target) do
            {downloaded, skipped + 1}
          else
            download(mirror <> file, target, file)
            {downloaded + 1, skipped}
          end
        end)

      Mix.shell().info("Done: #{downloaded} downloaded, #{skipped} already present")
      Mix.shell().info("Verify with: mix tablebase.check --path #{path}")
    end
  end

  defp list_files(mirror) do
    %{status: 200, body: body} = Req.get!(mirror)

    ~r/href="([^"]+\.rtb[zw])"/
    |> Regex.scan(body)
    |> Enum.map(fn [_, file] -> file end)
    |> Enum.uniq()
  end

  defp present?(target), do: File.exists?(target) and File.stat!(target).size > 0

  defp download(url, target, file) do
    partial = target <> ".part"
    Mix.shell().info("  #{file}")

    case Req.get(url, into: File.stream!(partial)) do
      {:ok, %{status: 200}} ->
        File.rename!(partial, target)

      {:ok, %{status: status}} ->
        File.rm(partial)
        Mix.raise("HTTP #{status} while fetching #{url}")

      {:error, reason} ->
        File.rm(partial)
        Mix.raise("failed to fetch #{url}: #{inspect(reason)}")
    end
  end
end
