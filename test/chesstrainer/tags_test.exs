defmodule Chesstrainer.TagsTest do
  use Chesstrainer.DataCase

  alias Chesstrainer.Tags

  describe "tags" do
    alias Chesstrainer.Tags.Tag

    import Chesstrainer.TagsFixtures

    @invalid_attrs %{name: nil, category: nil}

    test "list_tags/0 returns all tags" do
      tag = tag_fixture()
      assert Tags.list_tags() == [tag]
    end

    test "get_tag!/1 returns the tag with given id" do
      tag = tag_fixture()
      assert Tags.get_tag!(tag.id) == tag
    end

    test "create_tag/1 with valid data creates a tag" do
      valid_attrs = %{name: "some name", category: :endgame}

      assert {:ok, %Tag{} = tag} = Tags.create_tag(valid_attrs)
      assert tag.name == "some name"
      assert tag.category == :endgame
    end

    test "create_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(@invalid_attrs)
    end

    test "update_tag/2 with valid data updates the tag" do
      tag = tag_fixture()
      update_attrs = %{name: "some updated name", category: :opening}

      assert {:ok, %Tag{} = tag} = Tags.update_tag(tag, update_attrs)
      assert tag.name == "some updated name"
      assert tag.category == :opening
    end

    test "update_tag/2 with invalid data returns error changeset" do
      tag = tag_fixture()
      assert {:error, %Ecto.Changeset{}} = Tags.update_tag(tag, @invalid_attrs)
      assert tag == Tags.get_tag!(tag.id)
    end

    test "delete_tag/1 deletes the tag" do
      tag = tag_fixture()
      assert {:ok, %Tag{}} = Tags.delete_tag(tag)
      assert_raise Ecto.NoResultsError, fn -> Tags.get_tag!(tag.id) end
    end

    test "change_tag/1 returns a tag changeset" do
      tag = tag_fixture()
      assert %Ecto.Changeset{} = Tags.change_tag(tag)
    end

    test "get_or_create/2 matches case-insensitively and trims" do
      assert {:ok, tag} = Tags.get_or_create("Lucena", "endgame")

      assert {:ok, found} = Tags.get_or_create("  lucena  ", "endgame")
      assert found.id == tag.id
      assert length(Tags.list_tags()) == 1
    end

    test "get_or_create/2 rejects a blank name" do
      assert {:error, :blank_name} = Tags.get_or_create("   ", "endgame")
    end

    test "create_tag/1 rejects a case-insensitive duplicate" do
      assert {:ok, _tag} = Tags.create_tag(%{name: "Lucena", category: :endgame})
      assert {:error, changeset} = Tags.create_tag(%{name: "lucena", category: :endgame})
      assert changeset.errors[:name]
    end
  end
end
