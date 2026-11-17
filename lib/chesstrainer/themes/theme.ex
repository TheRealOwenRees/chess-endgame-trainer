defmodule Chesstrainer.Themes.Theme do
  @moduledoc """
  A label describing an endgame's technique or goal.

  A theme has a stable `slug` for URLs, a `kind` saying where the label comes
  from — `material`, `motif` or `technique` — and an optional description. The
  slug is generated from the name when the theme is first created and is then
  left alone, so renaming a theme never breaks a link to it.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @kinds [material: "material", motif: "motif", technique: "technique"]

  schema "themes" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :kind, Ecto.Enum, values: @kinds, default: :technique
    field :category, Ecto.Enum, values: [endgame: "endgame", opening: "opening", tactic: "tactic"]

    timestamps(type: :utc_datetime)
  end

  @doc "The kinds a theme can have."
  def kinds, do: Keyword.keys(@kinds)

  @doc """
  Turns a theme name into a URL-safe slug.

  Lowercase letters, digits and single hyphens; accents are folded, runs of
  other characters collapse to one hyphen, and a blank result becomes
  `"theme"`.
  """
  @spec slugify(String.t() | nil) :: String.t()
  def slugify(name) do
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

  @doc false
  def changeset(theme, attrs) do
    theme
    |> cast(attrs, [:name, :slug, :description, :kind, :category])
    |> update_change(:name, &trim/1)
    |> update_change(:description, &trim/1)
    |> put_slug()
    |> validate_required([:name, :slug, :kind, :category])
    |> validate_length(:name, min: 1, max: 60)
    |> validate_length(:slug, min: 1, max: 80)
    |> validate_length(:description, max: 500)
    |> validate_format(:slug, ~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
      message: "must be lowercase letters, numbers and single hyphens"
    )
    |> unique_constraint(:name,
      name: :themes_name_category_lower_index,
      message: "already exists"
    )
    |> unique_constraint(:slug, message: "is already taken")
    |> check_constraint(:kind, name: :themes_kind_in_allowed)
  end

  defp put_slug(changeset) do
    case get_field(changeset, :slug) do
      slug when is_binary(slug) ->
        if String.trim(slug) == "" do
          generate_slug(changeset)
        else
          put_change(changeset, :slug, slugify(slug))
        end

      nil ->
        generate_slug(changeset)
    end
  end

  # A new theme starts without a name, so generating a slug from it would only
  # produce the fallback. Wait until there is a name to derive from.
  defp generate_slug(changeset) do
    case get_field(changeset, :name) do
      name when is_binary(name) ->
        if String.trim(name) == "" do
          changeset
        else
          put_change(changeset, :slug, slugify(name))
        end

      _ ->
        changeset
    end
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
