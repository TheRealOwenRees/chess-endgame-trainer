defmodule Chesstrainer.EndgamesTest do
  use Chesstrainer.DataCase

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Themes

  @kr "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
  @kr_other "8/8/4k3/8/8/3K1R2/8/8 w - - 0 1"
  @kq "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1"

  defp create_endgame!(fen, themes \\ []) do
    attrs = %{fen: fen, color: :white, result: :win, rating: 1500}
    {:ok, endgame} = Endgames.create_endgame(attrs, themes)
    endgame
  end

  describe "create_endgame/1 FEN validation" do
    test "accepts a standard valid FEN and derives its key" do
      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
        color: :white,
        result: :win,
        rating: 1500
      }

      assert {:ok, %Endgame{} = endgame} = Endgames.create_endgame(attrs)
      assert endgame.key == "KR v K"
    end

    test "derives the key from the strongest side, colour-agnostically" do
      attrs = %{
        fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 0",
        color: :black,
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs)
      assert endgame.key == "KPPP v KPP"
    end

    test "ignores a supplied key and derives it from the FEN" do
      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
        color: :white,
        key: "KQ v K",
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs)
      assert endgame.key == "KR v K"
    end

    test "normalizes fullmove 0 to 1 before inserting" do
      attrs = %{
        fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 0",
        color: :black,
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs)
      assert endgame.fen == "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1"
    end

    test "trims whitespace around the FEN before inserting" do
      attrs = %{
        fen: "  8/8/3k4/8/8/3K1R2/8/8 w - - 0 1\t\n",
        color: :white,
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs)
      assert endgame.fen == "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
    end

    test "rejects a FEN with a zero digit in a rank" do
      attrs = %{
        fen: "4k3/8/8/8/8/8/8/0K7 w - - 0 1",
        color: :white,
        result: :win,
        rating: 1500
      }

      assert {:error, changeset} = Endgames.create_endgame(attrs)
      assert [msg] = errors_on(changeset).fen
      assert msg =~ "board must be 8 ranks"
    end

    test "rejects a FEN with the wrong number of fields" do
      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8",
        color: :white,
        result: :win,
        rating: 1500
      }

      assert {:error, changeset} = Endgames.create_endgame(attrs)
      assert [msg] = errors_on(changeset).fen
      assert msg =~ "6 space-separated"
    end

    test "rejects a FEN with an unknown active color" do
      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8 x - - 0 1",
        color: :white,
        result: :win,
        rating: 1500
      }

      assert {:error, changeset} = Endgames.create_endgame(attrs)
      assert [msg] = errors_on(changeset).fen
      assert msg =~ "active color"
    end

    test "rejects a FEN with more than 7 pieces" do
      attrs = %{
        fen: "3k4/2n2B2/1KP5/2B2p2/5b1p/7P/8/8 b - - 0 1",
        color: :black,
        result: :win,
        rating: 1500
      }

      assert {:error, changeset} = Endgames.create_endgame(attrs)
      assert [msg] = errors_on(changeset).fen
      assert msg =~ "more than 7 pieces"
    end

    test "accepts a FEN with exactly 7 pieces" do
      attrs = %{
        fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1",
        color: :black,
        result: :win,
        rating: 1500
      }

      assert {:ok, %Endgame{}} = Endgames.create_endgame(attrs)
    end
  end

  describe "themes" do
    test "create_endgame/2 associates themes" do
      {:ok, theme} = Themes.create_theme(%{name: "Lucena", category: :endgame})

      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
        color: :white,
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs, [theme])
      assert Enum.map(endgame.themes, & &1.id) == [theme.id]
    end

    test "update_endgame/3 replaces themes" do
      {:ok, lucena} = Themes.create_theme(%{name: "Lucena", category: :endgame})
      {:ok, philidor} = Themes.create_theme(%{name: "Philidor", category: :endgame})

      attrs = %{
        fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1",
        color: :black,
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs, [lucena])
      assert {:ok, updated} = Endgames.update_endgame(endgame, %{rating: 1600}, [philidor])
      assert Enum.map(updated.themes, & &1.id) == [philidor.id]
      assert updated.key == "KPPP v KPP"
    end
  end

  describe "rating default" do
    test "a new endgame changeset defaults rating to 1500" do
      changeset = Endgames.change_endgame(%Endgame{})

      assert Ecto.Changeset.get_field(changeset, :rating) == 1500
    end
  end

  describe "listing and filtering" do
    test "list_keys/0 returns the distinct keys sorted" do
      create_endgame!(@kr)
      create_endgame!(@kr_other)
      create_endgame!(@kq)

      assert Endgames.list_keys() == ["KQ v K", "KR v K"]
    end

    test "list_key_groups/1 groups by key and counts" do
      create_endgame!(@kr)
      create_endgame!(@kr_other)
      create_endgame!(@kq)

      assert Endgames.list_key_groups() == [{"KQ v K", 1}, {"KR v K", 2}]
    end

    test "list_endgames_for_key/2 returns only that key with themes preloaded" do
      {:ok, lucena} = Themes.create_theme(%{name: "Lucena", category: :endgame})
      create_endgame!(@kr, [lucena])
      create_endgame!(@kq)

      assert [endgame] = Endgames.list_endgames_for_key("KR v K")
      assert endgame.fen == @kr
      assert Enum.map(endgame.themes, & &1.name) == ["Lucena"]
    end

    test "list_key_groups/1 filters by theme" do
      {:ok, lucena} = Themes.create_theme(%{name: "Lucena", category: :endgame})
      {:ok, philidor} = Themes.create_theme(%{name: "Philidor", category: :endgame})

      create_endgame!(@kr, [lucena])
      create_endgame!(@kq, [philidor])

      assert Endgames.list_key_groups(%{themes: [lucena.id]}) == [{"KR v K", 1}]
    end

    test "list_key_groups/1 filters by key" do
      create_endgame!(@kr)
      create_endgame!(@kq)

      assert Endgames.list_key_groups(%{key: "KQ v K"}) == [{"KQ v K", 1}]
    end
  end
end
