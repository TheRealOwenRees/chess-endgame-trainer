# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Chesstrainer.Repo.insert!(%Chesstrainer.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Chesstrainer.Repo
alias Chesstrainer.Endgames.Endgame
alias Chesstrainer.Themes.Theme

now = DateTime.utc_now() |> DateTime.truncate(:second)

IO.puts("🌱 Seeding basic endgames into DB...")

endgames = [
  %{
    fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
    color: :white,
    message: "Rook vs king endgame",
    notes: "Basic rook endgame",
    result: :win
  },
  %{
    fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1",
    color: :black,
    message: "3 pawns vs 2 pawns",
    notes: "https://www.chessgames.com/perl/chessgame?gid=1017147",
    result: :win
  }
]

Repo.insert_all(
  Endgame,
  Enum.map(endgames, fn endgame ->
    {:ok, key} = Chesstrainer.Key.from_fen(endgame.fen)

    endgame
    |> Map.put(:id, Ecto.UUID.generate())
    |> Map.put(:key, key)
    |> Map.merge(%{inserted_at: now, updated_at: now})
  end),
  on_conflict: :nothing
)

IO.puts("✅ Done seeding endgames.")

IO.puts("🌱 Seeding endgame themes into DB...")

theme_names = [
  "mate in 2",
  "mate in 3",
  "Lucena",
  "Philidor",
  "opposition",
  "promotion",
  "stalemate"
]

Repo.insert_all(
  Theme,
  Enum.map(theme_names, fn name ->
    %{name: name, category: :endgame, inserted_at: now, updated_at: now}
  end),
  on_conflict: :nothing
)

IO.puts("✅ Done seeding endgame themes.")
