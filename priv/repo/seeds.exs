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

Code.require_file("seeds/endgames/win.ex", __DIR__)
Code.require_file("seeds/endgames/draw.ex", __DIR__)
Code.require_file("seeds/endgames.ex", __DIR__)
Code.require_file("seeds/themes.ex", __DIR__)

alias Chesstrainer.Repo
alias Chesstrainer.Endgames.Endgame
alias Chesstrainer.Themes.Theme
alias Chesstrainer.Repo.Seeds.Endgames
alias Chesstrainer.Repo.Seeds.Themes, as: SeedThemes

now = DateTime.utc_now() |> DateTime.truncate(:second)

# Seed maps may list `themes: ["Lucena", ...]`. Names are matched to seeded
# themes case-insensitively, and names missing from seeds/themes.ex are created.
endgames =
  Enum.map(Endgames.all(), fn endgame ->
    {theme_names, attrs} = Map.pop(endgame, :themes, [])
    fen = Chesstrainer.FEN.normalize(attrs.fen)
    {:ok, key} = Chesstrainer.Key.from_fen(fen)

    themes =
      theme_names
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&String.downcase/1)

    row =
      attrs
      |> Map.put(:fen, fen)
      |> Map.put(:id, Ecto.UUID.generate())
      |> Map.put(:public_code, Endgame.generate_public_code())
      |> Map.put(:key, key)
      |> Map.merge(%{inserted_at: now, updated_at: now})

    %{fen: fen, themes: themes, row: row}
  end)

IO.puts("🌱 Seeding endgame themes into DB...")

theme_names =
  (SeedThemes.all() ++ Enum.flat_map(endgames, & &1.themes))
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.uniq_by(&String.downcase/1)

Repo.insert_all(
  Theme,
  Enum.map(theme_names, fn name ->
    %{name: name, category: :endgame, inserted_at: now, updated_at: now}
  end),
  on_conflict: :nothing
)

theme_id_by_name =
  Theme
  |> Repo.all()
  |> Enum.filter(&(&1.category == :endgame))
  |> Map.new(&{String.downcase(&1.name), &1.id})

IO.puts("✅ Done seeding endgame themes.")

IO.puts("🌱 Seeding basic endgames into DB...")

Repo.insert_all(Endgame, Enum.map(endgames, & &1.row), on_conflict: :nothing)

endgame_id_by_fen =
  Endgame
  |> Repo.all()
  |> Map.new(&{&1.fen, &1.id})

links =
  Enum.flat_map(endgames, fn %{fen: fen, themes: themes} ->
    endgame_id = Map.fetch!(endgame_id_by_fen, fen)

    Enum.map(themes, fn name ->
      %{
        endgame_id: Ecto.UUID.dump!(endgame_id),
        theme_id: Map.fetch!(theme_id_by_name, String.downcase(name))
      }
    end)
  end)

if links != [] do
  Repo.insert_all("endgames_themes", links, on_conflict: :nothing)
end

IO.puts("✅ Done seeding endgames.")
