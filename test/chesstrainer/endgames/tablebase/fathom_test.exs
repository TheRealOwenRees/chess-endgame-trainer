defmodule Chesstrainer.Endgames.Tablebase.FathomTest do
  # Not async: Fathom keeps global state, and `init/1` points it at one directory.
  use ExUnit.Case, async: false

  alias Chesstrainer.Endgames.Tablebase.Fathom

  @fixture_path Path.expand("../../../fixtures/tablebase", __DIR__)

  # KRvK, white to move. Fathom CLI reports WDL Win, DTZ 23, 15 legal moves.
  @krk "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"

  setup_all do
    assert {:ok, largest} = Fathom.init(@fixture_path)
    assert largest == 3
    :ok
  end

  test "probes a known KRvK position" do
    assert {:ok, {root, moves}} = Fathom.probe(@krk)

    assert {:win, _from, _to, _promotes, _ep, 23} = root
    assert length(moves) == 15
    assert Enum.all?(moves, fn {wdl, _from, _to, _promotes, _ep, _dtz} -> wdl == :win end)
  end

  test "rejects a malformed FEN" do
    assert {:error, _reason} = Fathom.probe("not a fen")
  end
end
