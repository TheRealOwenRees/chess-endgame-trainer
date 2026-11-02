defmodule Chesstrainer.ThemesTest do
  use Chesstrainer.DataCase

  alias Chesstrainer.Themes

  describe "themes" do
    alias Chesstrainer.Themes.Theme

    import Chesstrainer.ThemesFixtures

    @invalid_attrs %{name: nil, category: nil}

    test "list_themes/0 returns all themes" do
      theme = theme_fixture()
      assert Themes.list_themes() == [theme]
    end

    test "get_theme!/1 returns the theme with given id" do
      theme = theme_fixture()
      assert Themes.get_theme!(theme.id) == theme
    end

    test "create_theme/1 with valid data creates a theme" do
      valid_attrs = %{name: "some name", category: :endgame}

      assert {:ok, %Theme{} = theme} = Themes.create_theme(valid_attrs)
      assert theme.name == "some name"
      assert theme.category == :endgame
    end

    test "create_theme/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Themes.create_theme(@invalid_attrs)
    end

    test "update_theme/2 with valid data updates the theme" do
      theme = theme_fixture()
      update_attrs = %{name: "some updated name", category: :opening}

      assert {:ok, %Theme{} = theme} = Themes.update_theme(theme, update_attrs)
      assert theme.name == "some updated name"
      assert theme.category == :opening
    end

    test "update_theme/2 with invalid data returns error changeset" do
      theme = theme_fixture()
      assert {:error, %Ecto.Changeset{}} = Themes.update_theme(theme, @invalid_attrs)
      assert theme == Themes.get_theme!(theme.id)
    end

    test "delete_theme/1 deletes the theme" do
      theme = theme_fixture()
      assert {:ok, %Theme{}} = Themes.delete_theme(theme)
      assert_raise Ecto.NoResultsError, fn -> Themes.get_theme!(theme.id) end
    end

    test "change_theme/1 returns a theme changeset" do
      theme = theme_fixture()
      assert %Ecto.Changeset{} = Themes.change_theme(theme)
    end

    test "get_or_create/2 matches case-insensitively and trims" do
      assert {:ok, theme} = Themes.get_or_create("Lucena", "endgame")

      assert {:ok, found} = Themes.get_or_create("  lucena  ", "endgame")
      assert found.id == theme.id
      assert length(Themes.list_themes()) == 1
    end

    test "get_or_create/2 rejects a blank name" do
      assert {:error, :blank_name} = Themes.get_or_create("   ", "endgame")
    end

    test "create_theme/1 rejects a case-insensitive duplicate" do
      assert {:ok, _theme} = Themes.create_theme(%{name: "Lucena", category: :endgame})
      assert {:error, changeset} = Themes.create_theme(%{name: "lucena", category: :endgame})
      assert changeset.errors[:name]
    end
  end
end
