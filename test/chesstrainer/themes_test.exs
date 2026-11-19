defmodule Chesstrainer.ThemesTest do
  use Chesstrainer.DataCase

  import Ecto.Query

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
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

  describe "tag_endgames/3 and untag_endgame/3" do
    test "adds curated links without duplicating them" do
      theme = theme_fixture()
      first = endgame_fixture()
      second = endgame_fixture()

      assert {:ok, 2} = Themes.tag_endgames(theme, [first.id, second.id])
      assert {:ok, 2} = Themes.tag_endgames(theme, [first.id, second.id])

      assert link_sources(first.id) == %{theme.id => "curated"}
      assert link_sources(second.id) == %{theme.id => "curated"}
    end

    test "never overwrites a derived link" do
      theme = theme_fixture()
      endgame = endgame_fixture()

      :ok = Themes.sync_derived_themes(endgame.id, [theme.id])

      assert {:ok, 1} = Themes.tag_endgames(theme, [endgame.id])
      assert link_sources(endgame.id) == %{theme.id => "derived"}
    end

    test "removes only the requested source" do
      theme = theme_fixture()
      curated = endgame_fixture()
      community = endgame_fixture()

      {:ok, _} = Themes.tag_endgames(theme, [curated.id], :curated)
      {:ok, _} = Themes.tag_endgames(theme, [community.id], :community)

      assert {:ok, 1} = Themes.untag_endgame(theme, curated.id, :curated)
      assert link_sources(curated.id) == %{}
      assert link_sources(community.id) == %{theme.id => "community"}
    end
  end

  describe "theme suggestions" do
    test "a player with an attempt can suggest an existing technique theme" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme = theme_fixture()

      assert {:ok, suggestion} =
               Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})

      assert suggestion.status == :pending
      assert suggestion.theme_id == theme.id
      assert suggestion.user_id == scope.user.id
      assert link_sources(endgame.id) == %{}
    end

    test "requires a recorded attempt" do
      endgame = endgame_fixture()
      scope = user_scope_fixture()
      theme = theme_fixture()

      assert {:error, :not_attempted} =
               Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})
    end

    test "rejects anonymous scopes" do
      endgame = endgame_fixture()
      theme = theme_fixture()

      assert {:error, :unauthorized} = Themes.suggest_theme(nil, endgame, %{theme_id: theme.id})

      assert {:error, :unauthorized} =
               Themes.suggest_theme(%Scope{}, endgame, %{theme_id: theme.id})
    end

    test "rejects themes that are not technique themes" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      material = theme_fixture(%{name: "Rook endgame", kind: :material})

      assert {:error, :not_suggestible} =
               Themes.suggest_theme(scope, endgame, %{theme_id: material.id})
    end

    test "rejects a theme the endgame already carries" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme = theme_fixture()
      {:ok, _} = Endgames.update_endgame(endgame, %{}, [theme])

      assert {:error, :already_tagged} =
               Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})
    end

    test "does not duplicate the same suggestion" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme = theme_fixture()

      assert {:ok, _} = Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})

      assert changeset.errors != []
    end

    test "proposes a new name and folds a matching existing name into that theme" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      opposition = theme_fixture(%{name: "Opposition"})

      assert {:ok, suggestion} =
               Themes.suggest_theme(scope, endgame, %{proposed_name: "  Back rank mate  "})

      assert suggestion.proposed_name == "Back rank mate"
      assert suggestion.theme_id == nil

      assert {:ok, folded} =
               Themes.suggest_theme(scope, endgame, %{proposed_name: "opposition"})

      assert folded.theme_id == opposition.id
      assert folded.proposed_name == nil
    end

    test "does not duplicate a proposed name, ignoring case" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)

      assert {:ok, _} = Themes.suggest_theme(scope, endgame, %{proposed_name: "Back rank mate"})

      assert {:error, %Ecto.Changeset{}} =
               Themes.suggest_theme(scope, endgame, %{proposed_name: "back rank mate"})
    end

    test "rejects a proposed name that matches a material theme" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme_fixture(%{name: "Pawn endgame", kind: :material})

      assert {:error, :not_suggestible} =
               Themes.suggest_theme(scope, endgame, %{proposed_name: "Pawn endgame"})
    end

    test "withdraws only the player's own pending suggestion" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme = theme_fixture()
      {:ok, suggestion} = Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})

      other_scope = user_scope_fixture()

      assert {:error, :unauthorized} = Themes.withdraw_suggestion(other_scope, suggestion)
      assert {:ok, _} = Themes.withdraw_suggestion(scope, suggestion)
      assert Themes.pending_suggestion_count(endgame.id) == 0
    end

    test "cannot withdraw a suggestion that is no longer pending" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme = theme_fixture()
      {:ok, suggestion} = Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})
      {:ok, accepted} = Repo.update(Ecto.Changeset.change(suggestion, status: :accepted))

      assert {:error, :not_pending} = Themes.withdraw_suggestion(scope, accepted)
    end

    test "counts pending suggestions per theme and in total" do
      endgame = endgame_fixture()
      theme = theme_fixture()

      for _ <- 1..2 do
        scope = attempted_scope(endgame)
        {:ok, _} = Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})
      end

      scope = attempted_scope(endgame)
      {:ok, _} = Themes.suggest_theme(scope, endgame, %{proposed_name: "New idea"})

      assert Themes.pending_suggestion_count(endgame.id) == 3
      assert Themes.pending_suggestion_counts(endgame.id) == %{theme.id => 2}
    end

    test "lists a player's suggestions for the data export" do
      endgame = endgame_fixture()
      scope = attempted_scope(endgame)
      theme = theme_fixture()
      {:ok, _} = Themes.suggest_theme(scope, endgame, %{theme_id: theme.id})

      assert [suggestion] = Themes.list_suggestions_for_user(scope.user.id)
      assert suggestion.endgame.id == endgame.id
      assert suggestion.theme.id == theme.id
    end
  end

  defp attempted_scope(endgame) do
    scope = user_scope_fixture()
    {:ok, _attempt} = Attempts.record_attempt(scope, endgame, :solved)
    scope
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
