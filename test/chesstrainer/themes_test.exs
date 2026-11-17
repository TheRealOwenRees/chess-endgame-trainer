defmodule Chesstrainer.ThemesTest do
  use Chesstrainer.DataCase

  import Ecto.Query

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  describe "themes" do
    alias Chesstrainer.Themes.Theme

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

  describe "theme identity" do
    test "generates a slug from the name" do
      assert {:ok, theme} = Themes.create_theme(%{name: "  Mate in 2!  ", category: :endgame})
      assert theme.slug == "mate-in-2"
    end

    test "normalises an explicit slug" do
      assert {:ok, theme} =
               Themes.create_theme(%{
                 name: "Lucena",
                 slug: "  Lucena-Position  ",
                 category: :endgame
               })

      assert theme.slug == "lucena-position"
    end

    test "keeps the slug stable when the name changes" do
      theme = theme_fixture(%{name: "Lucena"})

      assert {:ok, updated} = Themes.update_theme(theme, %{name: "Lucena position"})
      assert updated.slug == "lucena"
    end

    test "rejects a slug that is already taken, even in another category" do
      assert {:ok, _theme} = Themes.create_theme(%{name: "Lucena", category: :endgame})

      assert {:error, changeset} = Themes.create_theme(%{name: "Lucena", category: :tactic})
      assert changeset.errors[:slug]
    end

    test "defaults the kind to technique" do
      assert {:ok, theme} = Themes.create_theme(%{name: "Opposition", category: :endgame})
      assert theme.kind == :technique
    end

    test "accepts a material kind" do
      assert {:ok, theme} =
               Themes.create_theme(%{
                 name: "Rook endgame",
                 kind: :material,
                 category: :endgame
               })

      assert theme.kind == :material
    end

    test "rejects an unknown kind" do
      assert {:error, changeset} =
               Themes.create_theme(%{
                 name: "Zugzwang",
                 kind: :bogus,
                 category: :endgame
               })

      assert changeset.errors[:kind]
    end

    test "get_theme_by_slug/1 finds an endgame theme and ignores other categories" do
      theme = theme_fixture(%{name: "Philidor"})
      tactic = theme_fixture(%{name: "Philidor's pin", category: :tactic})

      assert Themes.get_theme_by_slug("philidor").id == theme.id
      assert Themes.get_theme_by_slug(tactic.slug) == nil
      assert Themes.get_theme_by_slug("unknown") == nil
    end
  end

  describe "create_theme/2 authorization" do
    test "an admin scope may create a theme" do
      {:ok, admin} = Accounts.update_user_role(user_fixture(), :admin)
      scope = Scope.for_user(admin)

      assert {:ok, %Themes.Theme{}} =
               Themes.create_theme(scope, %{name: "Opposition", category: :endgame})
    end

    test "a member scope cannot create a theme" do
      scope = user_scope_fixture()

      assert {:error, :unauthorized} =
               Themes.create_theme(scope, %{name: "Opposition", category: :endgame})

      assert Themes.list_themes() == []
    end
  end

  describe "theme link provenance" do
    test "links created from the endgame context default to curated" do
      theme = theme_fixture()
      endgame = endgame_fixture()

      assert {:ok, _endgame} = Endgames.update_endgame(endgame, %{}, [theme])

      assert [%{theme_id: theme_id, source: "curated"}] = link_rows(endgame.id)
      assert theme_id == theme.id
    end

    test "sync_derived_themes/2 adds derived links and leaves curated and community links alone" do
      curated = theme_fixture(%{name: "Lucena"})
      community = theme_fixture(%{name: "Philidor"})
      derived = theme_fixture(%{name: "Rook endgame"})
      endgame = endgame_fixture()

      {:ok, _} = Endgames.update_endgame(endgame, %{}, [curated])
      insert_link(endgame.id, community.id, "community")

      assert :ok = Themes.sync_derived_themes(endgame.id, [derived.id, curated.id])

      sources = link_sources(endgame.id)
      assert sources[curated.id] == "curated"
      assert sources[community.id] == "community"
      assert sources[derived.id] == "derived"
    end

    test "sync_derived_themes/2 replaces only its own derived links" do
      curated = theme_fixture(%{name: "Lucena"})
      old_derived = theme_fixture(%{name: "Rook endgame"})
      new_derived = theme_fixture(%{name: "Two pawns"})
      endgame = endgame_fixture()

      {:ok, _} = Endgames.update_endgame(endgame, %{}, [curated])
      Themes.sync_derived_themes(endgame.id, [old_derived.id])

      assert :ok = Themes.sync_derived_themes(endgame.id, [new_derived.id])

      sources = link_sources(endgame.id)
      assert sources[curated.id] == "curated"
      refute Map.has_key?(sources, old_derived.id)
      assert sources[new_derived.id] == "derived"
    end
  end

  defp link_rows(endgame_id) do
    Repo.all(
      from l in "endgames_themes",
        where: l.endgame_id == type(^endgame_id, :binary_id),
        select: %{theme_id: l.theme_id, source: l.source},
        order_by: l.theme_id
    )
  end

  defp link_sources(endgame_id) do
    endgame_id
    |> link_rows()
    |> Map.new(&{&1.theme_id, &1.source})
  end

  defp insert_link(endgame_id, theme_id, source) do
    Repo.insert_all("endgames_themes", [
      %{
        endgame_id: Ecto.UUID.dump!(endgame_id),
        theme_id: theme_id,
        source: source,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    ])
  end
end
