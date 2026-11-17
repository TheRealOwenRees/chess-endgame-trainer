defmodule Mix.Tasks.Themes.DeriveMotifs do
  use Mix.Task

  @shortdoc "Tags every endgame with its tablebase-proved motifs"

  @moduledoc """
  Derives only-move, underpromotion and 50-move-draw motifs from the local
  Syzygy tablebase.

      mix themes.derive_motifs

  The pass never calls the remote tablebase. Positions the local files cannot
  answer are skipped and reported. Re-running is idempotent: only links to the
  motif themes are replaced, so material, curated and community links survive.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{links: links, skipped: skipped, by_motif: by_motif, themes: themes} =
      Chesstrainer.Endgames.MotifThemes.derive()

    Mix.shell().info(
      "Motif themes: #{themes} themes, #{links} link(s) written, #{skipped} endgame(s) skipped."
    )

    for {motif, count} <- Enum.sort(by_motif) do
      Mix.shell().info("  #{motif}: #{count}")
    end
  end
end
