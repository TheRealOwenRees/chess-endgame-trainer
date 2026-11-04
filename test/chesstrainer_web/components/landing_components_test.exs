defmodule ChesstrainerWeb.LandingComponentsTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Chesstrainer.Endgames.Endgame
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
end
