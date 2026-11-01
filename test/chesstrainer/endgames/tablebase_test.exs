defmodule Chesstrainer.Endgames.TablebaseTest do
  use ExUnit.Case, async: false

  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.Endgames.Tablebase.Parser
  alias Chesstrainer.Ratelimiters

  describe "normalize_category/1" do
    test "maps winning categories to :win" do
      for category <- ["win", "syzygy-win", "maybe-win"] do
        assert Tablebase.normalize_category(category) == :win
      end
    end

    test "maps 50-move-rule draws to :draw" do
      for category <- ["draw", "cursed-win", "blessed-loss"] do
        assert Tablebase.normalize_category(category) == :draw
      end
    end

    test "maps losing categories to :loss" do
      for category <- ["loss", "syzygy-loss", "maybe-loss"] do
        assert Tablebase.normalize_category(category) == :loss
      end
    end

    test "falls back to :unknown for anything else" do
      for category <- ["unknown", "banana", nil] do
        assert Tablebase.normalize_category(category) == :unknown
      end
    end
  end

  describe "Parser.from_map/1" do
    test "normalises the position and move categories" do
      assert {:ok, tablebase} =
               Parser.from_map(%{
                 "category" => "cursed-win",
                 "checkmate" => false,
                 "dtc" => nil,
                 "dtm" => 20,
                 "dtw" => nil,
                 "dtz" => 3,
                 "insufficient_material" => false,
                 "moves" => [
                   %{
                     "category" => "blessed-loss",
                     "checkmate" => false,
                     "conversion" => false,
                     "dtc" => nil,
                     "dtm" => -19,
                     "dtw" => nil,
                     "dtz" => -2,
                     "insufficient_material" => false,
                     "precise_dtz" => -2,
                     "san" => "Kd7",
                     "stalemate" => false,
                     "uci" => "e8d7",
                     "variant_loss" => false,
                     "variant_win" => false,
                     "zeroing" => false
                   }
                 ]
               })

      assert tablebase.category == :draw
      assert [%Tablebase.Move{category: :draw, uci: "e8d7"}] = tablebase.moves
    end
  end

  describe "Parser.parse_response/1" do
    test "a 429 sets the cooldown and returns a rate-limit error" do
      Ratelimiters.lichess_reset_cooldown()
      on_exit(fn -> Ratelimiters.lichess_reset_cooldown() end)

      assert {:error, {:too_many_requests, 429, "rate limited"}} =
               Parser.parse_response({:ok, %Req.Response{status: 429, body: "rate limited"}})

      assert {:cooldown, remaining} = Ratelimiters.lichess_check_cooldown()
      assert remaining > 0
    end
  end

  describe "new/1" do
    test "returns {:ok, tablebase} on a cache hit" do
      fen = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
      tablebase = %Tablebase{category: :win, moves: []}

      TablebaseCache.put(fen, tablebase)
      on_exit(fn -> TablebaseCache.delete(fen) end)

      assert {:ok, ^tablebase} = Tablebase.new(fen)
    end
  end
end
