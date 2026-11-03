defmodule Mix.Tasks.Tablebase.Check do
  use Mix.Task

  @shortdoc "Verify the local Syzygy tablebases"

  @moduledoc """
  Verifies that the configured local Syzygy tablebases load.

      TABLEBASE_PATH=/data/syzygy/3-4-5 mix tablebase.check
      mix tablebase.check --path /data/syzygy/3-4-5

  Exits non-zero when the path is unset, empty, or Fathom fails to initialise.
  """
  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [path: :string])

    path =
      opts[:path] || System.get_env("TABLEBASE_PATH") ||
        Chesstrainer.Endgames.Tablebase.Local.path()

    if is_nil(path) do
      Mix.raise("set TABLEBASE_PATH or pass --path")
    end

    case Chesstrainer.Endgames.Tablebase.Fathom.init(Path.expand(path)) do
      {:ok, 0} ->
        Mix.raise("no tablebase files found in #{path}")

      {:ok, largest} ->
        Mix.shell().info("local tablebases at #{path}: largest=#{largest}")

      {:error, reason} ->
        Mix.raise("failed to initialise Fathom: #{inspect(reason)}")
    end
  end
end
