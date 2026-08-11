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
alias Chesstrainer.Tags.Tag

now = DateTime.utc_now() |> DateTime.truncate(:second)

IO.puts("🌱 Seeding basic endgames into DB...")

Repo.insert_all(Endgame, [
  %{
    id: Ecto.UUID.generate(),
    fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
    color: :white,
    key: "KR v K",
    message: "Rook vs king endgame",
    notes: "Basic rook endgame",
    result: :win,
    inserted_at: now,
    updated_at: now
  },
  %{
    id: Ecto.UUID.generate(),
    fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1",
    color: :black,
    key: "KPPP v KPP",
    message: "3 pawns vs 2 pawns",
    notes: "https://www.chessgames.com/perl/chessgame?gid=1017147",
    result: :win,
    inserted_at: now,
    updated_at: now
  }
])

IO.puts("✅ Done seeding endgames.")

IO.puts("🌱 Seeding endgame tags into DB...")

Repo.insert_all(Tag, [
  %{
    name: "mate in 2",
    category: :endgame,
    inserted_at: now,
    updated_at: now
  },
  %{
    name: "mate in 3",
    category: :endgame,
    inserted_at: now,
    updated_at: now
  }
])

IO.puts("✅ Done seeding endgame tags.")
