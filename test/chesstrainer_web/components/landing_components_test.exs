defmodule ChesstrainerWeb.LandingComponentsTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Themes.Theme
  alias ChesstrainerWeb.LandingComponents

  @endgame %Endgame{
    fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
    color: :white,
    key: "KR v K"
  }

  test "renders the endgame's pieces, side to move, and caption" do
    html = render_component(&LandingComponents.board_preview/1, %{endgame: @endgame})

    assert html =~ "KR v K"
    assert html =~ "To move"
    assert html =~ "White"
    assert html =~ "♔"
    assert html =~ "♖"
    assert html =~ "♚"
    assert html =~ "Today’s position"
  end

  test "falls back to a neutral position without an endgame" do
    html = render_component(&LandingComponents.board_preview/1, %{endgame: nil})

    assert html =~ "Featured position"
    assert html =~ "White"
    assert html =~ "♖"
  end

  test "renders themes under the position title" do
    endgame = %{
      fen: @endgame.fen,
      color: :white,
      key: "KR v K",
      themes: [%Theme{name: "Lucena"}]
    }

    html = render_component(&LandingComponents.board_preview/1, %{endgame: endgame})

    assert html =~ "Lucena"
  end

  describe "puzzle_count_label/1" do
    test "shows counts below 100 exactly" do
      assert LandingComponents.puzzle_count_label(0) == "0"
      assert LandingComponents.puzzle_count_label(47) == "47"
      assert LandingComponents.puzzle_count_label(99) == "99"
    end

    test "floors counts of 100 or more to hundreds" do
      assert LandingComponents.puzzle_count_label(100) == "100+"
      assert LandingComponents.puzzle_count_label(199) == "100+"
      assert LandingComponents.puzzle_count_label(999) == "900+"
    end

    test "floors counts of 1000 or more to thousands" do
      assert LandingComponents.puzzle_count_label(1000) == "1000+"
      assert LandingComponents.puzzle_count_label(1999) == "1000+"
      assert LandingComponents.puzzle_count_label(2400) == "2000+"
    end
  end
end
