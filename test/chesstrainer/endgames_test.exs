defmodule Chesstrainer.EndgamesTest do
  use Chesstrainer.DataCase

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Themes

  describe "create_endgame/1 FEN validation" do
    test "accepts a standard valid FEN" do
      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
        color: :white,
        key: "KR v K",
        result: :win,
        rating: 1500
      }

      assert {:ok, %Endgame{}} = Endgames.create_endgame(attrs)
    end

    test "normalizes fullmove 0 to 1 before inserting" do
      attrs = %{
        fen: "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 0",
        color: :black,
        key: "KPPP v KPP",
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
        key: "KR v K",
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
        key: "KQ v K",
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
        key: "KQ v K",
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
        key: "KQ v K",
        result: :win,
        rating: 1500
      }

      assert {:error, changeset} = Endgames.create_endgame(attrs)
      assert [msg] = errors_on(changeset).fen
      assert msg =~ "active color"
    end
  end

  describe "themes" do
    test "create_endgame/2 associates themes" do
      {:ok, theme} = Themes.create_theme(%{name: "Lucena", category: :endgame})

      attrs = %{
        fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
        color: :white,
        key: "KR v K",
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
        key: "KPPP v KPP",
        result: :win,
        rating: 1500
      }

      assert {:ok, endgame} = Endgames.create_endgame(attrs, [lucena])
      assert {:ok, updated} = Endgames.update_endgame(endgame, %{rating: 1600}, [philidor])
      assert Enum.map(updated.themes, & &1.id) == [philidor.id]
    end
  end
end
