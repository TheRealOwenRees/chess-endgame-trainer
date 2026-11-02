defmodule Chesstrainer.ThemesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chesstrainer.Themes` context.
  """

  @doc """
  Generate a unique theme name.
  """
  def unique_theme_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a theme.
  """
  def theme_fixture(attrs \\ %{}) do
    {:ok, theme} =
      attrs
      |> Enum.into(%{
        category: :endgame,
        name: unique_theme_name()
      })
      |> Chesstrainer.Themes.create_theme()

    theme
  end
end
