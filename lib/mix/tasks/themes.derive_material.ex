defmodule Mix.Tasks.Themes.DeriveMaterial do
  use Mix.Task

  @shortdoc "Tags every endgame with its material family theme"

  @moduledoc """
  Derives each endgame's material family from its Key and stores the result as
  a derived theme.

      mix themes.derive_material

  Every endgame belongs to exactly one family, so the themes partition the
  library. Re-running is idempotent: only derived links are replaced, and
  curated or community links are untouched.

  Positions that are kings only, or that have no Key, are reported as skipped.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{tagged: tagged, skipped: skipped, themes: themes} =
      Chesstrainer.Endgames.MaterialThemes.derive()

    Mix.shell().info(
      "Material themes: #{themes} themes, #{tagged} endgames tagged, " <>
        "#{skipped} skipped (kings only or no Key)."
    )
  end
end
