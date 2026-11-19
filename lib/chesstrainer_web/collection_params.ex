defmodule ChesstrainerWeb.CollectionParams do
  @moduledoc """
  The collection query grammar shared by browsing and training.

  A collection is a set of themes plus an optional material Key, written as
  `?themes=lucena,philidor&key=KR+v+K`. Browsing (`/endgames`) and a session
  (`/train`) read the same grammar, so whatever can be filtered can be played.

  Unknown slugs and keys are dropped rather than rejected: a stale link widens
  the collection instead of erroring.
  """

  alias Chesstrainer.Endgames
  alias Chesstrainer.Themes

  @type t :: %{themes: [Themes.Theme.t()], key: String.t() | nil}

  @doc "Parses `themes` and `key` out of request params."
  @spec parse(map()) :: t()
  def parse(params) do
    themes = parse_themes(Map.get(params, "themes"))
    key = params |> Map.get("key") |> blank_to_nil()
    key = if key in Endgames.list_keys(), do: key, else: nil

    %{themes: themes, key: key}
  end

  @doc "The whole library."
  @spec empty() :: t()
  def empty, do: %{themes: [], key: nil}

  @doc "Whether the collection narrows the library at all."
  @spec any?(t()) :: boolean()
  def any?(%{themes: [], key: nil}), do: false
  def any?(_collection), do: true

  @doc """
  The active query parameters, ready to interpolate into a verified route.

  An empty list means no collection, so callers should link to the bare path.
  """
  @spec params(t()) :: keyword()
  def params(%{themes: themes, key: key}) do
    []
    |> put(:themes, Enum.map_join(themes, ",", & &1.slug))
    |> put(:key, key)
  end

  @doc "A player-facing label for the collection, or nil for the whole library."
  @spec label(t()) :: String.t() | nil
  def label(%{themes: [], key: nil}), do: nil

  def label(%{themes: themes, key: key}) do
    names = Enum.map_join(themes, ", ", & &1.name)

    cond do
      names == "" -> key
      is_nil(key) -> names
      true -> names <> " · " <> key
    end
  end

  defp parse_themes(nil), do: []

  defp parse_themes(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.uniq()
    |> Enum.map(&Themes.get_theme_by_slug/1)
    |> Enum.reject(&is_nil/1)
  end

  defp put(params, _name, value) when value in [nil, ""], do: params
  defp put(params, name, value), do: params ++ [{name, value}]

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: value
end
