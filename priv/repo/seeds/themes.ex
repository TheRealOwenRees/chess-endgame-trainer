defmodule Chesstrainer.Repo.Seeds.Themes do
  # Endgame seed maps may also reference themes with `themes: ["Lucena", ...]`;
  # names missing from this list are created when the seeds run.
  def all do
    [
      "mate in 2",
      "mate in 3",
      "Lucena",
      "Philidor",
      "opposition",
      "promotion",
      "stalemate"
    ]
  end
end
