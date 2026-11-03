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

Code.require_file("seeds/endgames.ex", __DIR__)
Code.require_file("seeds/themes.ex", __DIR__)

alias Chesstrainer.Repo
alias Chesstrainer.Endgames.Endgame
alias Chesstrainer.Themes.Theme
alias Chesstrainer.Repo.Seeds.Endgames
alias Chesstrainer.Repo.Seeds.Themes

now = DateTime.utc_now() |> DateTime.truncate(:second)

IO.puts("🌱 Seeding basic endgames into DB...")

endgames = Endgames.all()

Repo.insert_all(
  Endgame,
  Enum.map(endgames, fn endgame ->
    fen = Chesstrainer.FEN.normalize(endgame.fen)
    {:ok, key} = Chesstrainer.Key.from_fen(fen)

    endgame
    |> Map.put(:fen, fen)
    |> Map.put(:id, Ecto.UUID.generate())
    |> Map.put(:key, key)
    |> Map.merge(%{inserted_at: now, updated_at: now})
  end),
  on_conflict: :nothing
)

IO.puts("✅ Done seeding endgames.")

IO.puts("🌱 Seeding endgame themes into DB...")

theme_names = Themes.all()

Repo.insert_all(
  Theme,
  Enum.map(theme_names, fn name ->
    %{name: name, category: :endgame, inserted_at: now, updated_at: now}
  end),
  on_conflict: :nothing
)

IO.puts("✅ Done seeding endgame themes.")
