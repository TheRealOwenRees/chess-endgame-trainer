defmodule Chesstrainer.Endgames.TablebaseTest do
  use ExUnit.Case, async: false

  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.Endgames.Tablebase.Parser
  alias Chesstrainer.FEN
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

  describe "normalize_wdl/1" do
    test "maps Fathom WDL atoms, treating 50-move-rule draws as draws" do
      assert Tablebase.normalize_wdl(:win) == :win
      assert Tablebase.normalize_wdl(:loss) == :loss
      assert Tablebase.normalize_wdl(:draw) == :draw
      assert Tablebase.normalize_wdl(:cursed_win) == :draw
      assert Tablebase.normalize_wdl(:blessed_loss) == :draw
      assert Tablebase.normalize_wdl(:unknown) == :unknown
    end
  end

  describe "struct shape" do
    test "Tablebase carries only the fields the trainer reads" do
      assert %Tablebase{} |> Map.from_struct() |> Map.keys() |> Enum.sort() ==
               [:category, :checkmate, :moves]
    end

    test "Tablebase.Move carries only the fields the trainer reads" do
      assert %Tablebase.Move{} |> Map.from_struct() |> Map.keys() |> Enum.sort() ==
               [:category, :dtz, :san, :uci]
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
                 "dtz" => 3,
                 "moves" => [
                   %{
                     "category" => "blessed-loss",
                     "dtc" => nil,
                     "dtm" => -19,
                     "dtz" => -2,
                     "san" => "Kd7",
                     "uci" => "e8d7"
                   }
                 ]
               })

      assert %Tablebase{category: :draw, checkmate: false} = tablebase

      assert [%Tablebase.Move{category: :draw, dtz: -2}] = tablebase.moves
      assert [%Tablebase.Move{san: "Kd7", uci: "e8d7"}] = tablebase.moves
    end

    test "drops the fields the trainer never reads" do
      assert {:ok, tablebase} =
               Parser.from_map(%{
                 "category" => "win",
                 "checkmate" => true,
                 "dtc" => 1,
                 "dtm" => 2,
                 "dtw" => 3,
                 "dtz" => 4,
                 "insufficient_material" => false,
                 "moves" => [
                   %{
                     "category" => "loss",
                     "checkmate" => true,
                     "conversion" => true,
                     "dtc" => 5,
                     "dtm" => 6,
                     "dtw" => 7,
                     "dtz" => 8,
                     "insufficient_material" => false,
                     "precise_dtz" => 9,
                     "san" => "Qd7#",
                     "stalemate" => false,
                     "uci" => "d1d7",
                     "variant_loss" => false,
                     "variant_win" => false,
                     "zeroing" => true
                   }
                 ]
               })

      assert %Tablebase{} |> Map.from_struct() |> Map.keys() |> Enum.sort() ==
               [:category, :checkmate, :moves]

      assert [move] = tablebase.moves

      assert move |> Map.from_struct() |> Map.keys() |> Enum.sort() ==
               [:category, :dtz, :san, :uci]
    end

    test "keeps checkmate and empty moves, which drive terminal detection" do
      assert {:ok, tablebase} =
               Parser.from_map(%{
                 "category" => "win",
                 "checkmate" => true,
                 "dtc" => 1,
                 "dtm" => 2,
                 "dtz" => 3,
                 "moves" => []
               })

      assert tablebase.checkmate
      assert tablebase.moves == []
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
      key = FEN.position_key(fen)

      TablebaseCache.put(key, tablebase)
      on_exit(fn -> TablebaseCache.delete(key) end)

      assert {:ok, ^tablebase} = Tablebase.new(fen)
    end

    test "shares a cache entry for FENs that differ only in the clocks" do
      fen = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
      other_clock = "8/8/3k4/8/8/3K1R2/8/8 w - - 7 42"
      tablebase = %Tablebase{category: :win, moves: []}
      key = FEN.position_key(fen)

      TablebaseCache.put(key, tablebase)
      on_exit(fn -> TablebaseCache.delete(key) end)

      assert {:ok, ^tablebase} = Tablebase.new(other_clock)
    end

    test "returns {:error, :not_covered} for a position with more than seven pieces" do
      fen = "3k4/2n2B2/1KP5/2B2p2/5b1p/7P/8/8 b - - 0 1"
      TablebaseCache.delete(FEN.position_key(fen))

      assert Tablebase.new(fen) == {:error, :not_covered}
    end
  end
end
