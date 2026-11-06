defmodule Chesstrainer.GuestLimitsTest do
  use ExUnit.Case, async: false

  alias Chesstrainer.GuestLimits

  @address {203, 0, 113, 7}
  @other {198, 51, 100, 9}
  @today ~D[2026-11-06]

  setup do
    GuestLimits.reset()
    :ok
  end

  test "allows five puzzles a day and blocks the sixth" do
    assert {:ok, 4} = GuestLimits.take(@address, @today)
    assert {:ok, 3} = GuestLimits.take(@address, @today)
    assert {:ok, 2} = GuestLimits.take(@address, @today)
    assert {:ok, 1} = GuestLimits.take(@address, @today)
    assert {:ok, 0} = GuestLimits.take(@address, @today)

    assert {:limit_reached, retry_ms} = GuestLimits.take(@address, @today)
    assert retry_ms > 0
  end

  test "resets on the next UTC day" do
    for _ <- 1..5, do: assert({:ok, _} = GuestLimits.take(@address, @today))
    assert {:limit_reached, _} = GuestLimits.take(@address, @today)

    assert {:ok, 4} = GuestLimits.take(@address, ~D[2026-11-07])
  end

  test "tracks addresses independently" do
    for _ <- 1..5, do: assert({:ok, _} = GuestLimits.take(@address, @today))

    assert {:limit_reached, _} = GuestLimits.take(@address, @today)
    assert {:ok, 4} = GuestLimits.take(@other, @today)
  end

  test "does not limit a missing address" do
    assert {:ok, nil} = GuestLimits.take(nil, @today)
    assert {:ok, nil} = GuestLimits.take(nil, @today)
  end

  test "reset clears spent budgets" do
    for _ <- 1..5, do: assert({:ok, _} = GuestLimits.take(@address, @today))
    assert {:limit_reached, _} = GuestLimits.take(@address, @today)

    GuestLimits.reset()

    assert {:ok, 4} = GuestLimits.take(@address, @today)
  end
end
