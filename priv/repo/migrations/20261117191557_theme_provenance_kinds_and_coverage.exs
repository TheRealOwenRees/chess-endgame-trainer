defmodule Chesstrainer.Repo.Migrations.ThemeProvenanceKindsAndCoverage do
  use Ecto.Migration

  import Ecto.Query

  def up do
    alter table(:themes) do
      add :slug, :string
      add :description, :string
      add :kind, :string, null: false, default: "technique"
    end

    alter table(:endgames_themes) do
      add :source, :string, null: false, default: "curated"
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    flush()

    backfill_slugs()

    alter table(:themes) do
      modify :slug, :string, null: false
    end

    create unique_index(:themes, [:slug])

    create constraint(:themes, :kind_in_allowed,
             check: "kind in ('material', 'motif', 'technique')"
           )

    create constraint(:endgames_themes, :source_in_allowed,
             check: "source in ('derived', 'curated', 'community')"
           )
  end

  def down do
    drop constraint(:endgames_themes, :source_in_allowed)
    drop constraint(:themes, :kind_in_allowed)
    drop unique_index(:themes, [:slug])

    alter table(:endgames_themes) do
      remove :inserted_at
      remove :source
    end

    alter table(:themes) do
      remove :kind
      remove :description
      remove :slug
    end
  end

  # Themes were created without a slug, so every existing row needs one before
  # the column can become mandatory. Names are unique per category but not
  # globally, so collisions get a numeric suffix.
  defp backfill_slugs do
    themes = repo().all(from(t in "themes", select: {t.id, t.name}))

    Enum.reduce(themes, MapSet.new(), fn {id, name}, used ->
      slug = unique_slug(slugify(name), used)
      repo().update_all(from(t in "themes", where: t.id == ^id), set: [slug: slug])
      MapSet.put(used, slug)
    end)
  end

  defp unique_slug(base, used) do
    if MapSet.member?(used, base) do
      Enum.find_value(2..1_000, base, fn suffix ->
        candidate = "#{base}-#{suffix}"
        if MapSet.member?(used, candidate), do: nil, else: candidate
      end)
    else
      base
    end
  end

  defp slugify(name) do
    slug =
      name
      |> to_string()
      |> :unicode.characters_to_nfd_binary()
      |> String.replace(~r/[\x{0300}-\x{036F}]/u, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    if slug == "", do: "theme", else: slug
  end
end
