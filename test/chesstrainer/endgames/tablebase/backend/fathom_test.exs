defmodule Chesstrainer.Endgames.Tablebase.Backend.FathomTest.Stub do
  @moduledoc false

  alias Chesstrainer.Endgames.Tablebase

  def probe(_fen), do: {:ok, %Tablebase{category: :draw, checkmate: false, moves: []}}
end

defmodule Chesstrainer.Endgames.Tablebase.Backend.FathomTest.ExplodingFallback do
  @moduledoc false
  def probe(_fen), do: raise("the remote tablebase must not be called")
end

defmodule Chesstrainer.Endgames.Tablebase.Backend.FathomTest do
  # Not async: the local backend reads app config and Fathom keeps global state.
  use ExUnit.Case, async: false

  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Backend.Fathom, as: FathomBackend
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.Endgames.Tablebase.Local
  alias Chesstrainer.FEN

  @krk "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"
  @mate "7k/6Q1/5K2/8/8/8/8/8 b - - 0 1"
  @kpk "8/8/3k4/8/8/3KP3/8/8 w - - 0 1"

  test "probes a KRvK position locally" do
    assert {:ok, %Tablebase{} = tablebase} = FathomBackend.probe(@krk)
    assert tablebase.category == :win
    refute tablebase.checkmate
    assert length(tablebase.moves) == 15
    assert Enum.all?(tablebase.moves, &(&1.category == :loss))

    best = hd(tablebase.moves)
    assert best.uci == "a1a7"
    assert best.dtz == 23
    assert best.san == "Ra7"
  end

  test "detects checkmate" do
    assert {:ok, %Tablebase{category: :loss, checkmate: true, moves: []}} =
             FathomBackend.probe(@mate)
  end

  test "Local.check/0 reports the configured fixture set" do
    assert is_binary(Local.path())
    assert {:ok, 3} = Local.check()
  end

  test "answers through Tablebase.new without a cached entry" do
    # A draw-returning fallback proves the win came from Fathom, not Lichess.
    previous = Application.get_env(:chesstrainer, :tablebase_fallback)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:chesstrainer, :tablebase_fallback, previous),
        else: Application.delete_env(:chesstrainer, :tablebase_fallback)
    end)

    Application.put_env(:chesstrainer, :tablebase_fallback, __MODULE__.Stub)
    TablebaseCache.delete(FEN.position_key(@krk))

    assert {:ok, %Tablebase{category: :win, moves: moves}} = Tablebase.new(@krk)
    assert length(moves) == 15
  end

  describe "fallback" do
    setup do
      previous_path = Application.get_env(:chesstrainer, :tablebase_path)
      previous_fallback = Application.get_env(:chesstrainer, :tablebase_fallback)

      on_exit(fn ->
        Application.put_env(:chesstrainer, :tablebase_path, previous_path)

        if previous_fallback do
          Application.put_env(:chesstrainer, :tablebase_fallback, previous_fallback)
        else
          Application.delete_env(:chesstrainer, :tablebase_fallback)
        end
      end)
    end

    test "falls back when the tablebases are not configured" do
      Application.put_env(:chesstrainer, :tablebase_path, nil)
      Application.put_env(:chesstrainer, :tablebase_fallback, __MODULE__.Stub)

      assert {:ok, %Tablebase{category: :draw}} = FathomBackend.probe(@krk)
    end
  end

  describe "probe_local_detail/1" do
    test "returns the raw root WDL, DTZ and every legal move" do
      assert {:ok, %{wdl: :win, dtz: dtz, moves: moves}} =
               FathomBackend.probe_local_detail(@krk)

      assert is_integer(dtz)
      assert length(moves) == 15
      assert Enum.all?(moves, &(elem(&1, 0) in [:win, :cursed_win, :draw, :blessed_loss, :loss]))
    end

    test "returns terminal for a finished position" do
      assert {:error, :terminal} = FathomBackend.probe_local_detail(@mate)
    end

    test "returns unsupported when the local files cannot answer the position" do
      assert {:error, :unsupported} = FathomBackend.probe_local_detail(@kpk)
    end

    test "never calls the remote backend" do
      previous = Application.get_env(:chesstrainer, :tablebase_fallback)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:chesstrainer, :tablebase_fallback, previous),
          else: Application.delete_env(:chesstrainer, :tablebase_fallback)
      end)

      Application.put_env(:chesstrainer, :tablebase_fallback, __MODULE__.ExplodingFallback)

      assert {:error, :unsupported} = FathomBackend.probe_local_detail(@kpk)
    end
  end
end
