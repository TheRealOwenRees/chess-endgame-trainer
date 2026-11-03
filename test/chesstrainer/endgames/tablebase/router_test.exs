defmodule Chesstrainer.Endgames.Tablebase.RouterTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Endgames.Tablebase.Backend.Lichess
  alias Chesstrainer.Endgames.Tablebase.Router

  @three "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
  @six "8/8/5p2/1P1K1k2/8/2r5/8/7R w - - 0 0"
  @seven "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1"
  @ten "3k4/2n2B2/1KP5/2B2p2/5b1p/7P/8/8 b - - 0 1"

  describe "backend/1" do
    test "routes five or fewer pieces to the local slot" do
      assert Router.backend(@three) == {:ok, Lichess}
    end

    test "routes six and seven pieces to the remote slot" do
      assert Router.backend(@six) == {:ok, Lichess}
      assert Router.backend(@seven) == {:ok, Lichess}
    end

    test "marks eight or more pieces as not covered" do
      assert Router.backend(@ten) == {:error, :not_covered}
    end

    test "marks a malformed FEN as invalid" do
      assert Router.backend("not a fen") == {:error, :invalid_endgame}
    end
  end

  describe "probe/1" do
    test "rejects a position with more than seven pieces without a network call" do
      assert Router.probe(@ten) == {:error, :not_covered}
    end

    test "rejects a malformed FEN" do
      assert Router.probe("not a fen") == {:error, :invalid_endgame}
    end
  end
end
