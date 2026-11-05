defmodule Chesstrainer.DailyPuzzlesTest do
  use Chesstrainer.DataCase

  alias Chesstrainer.DailyPuzzles
  alias Chesstrainer.DailyPuzzles.DailyPuzzle
  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Repo
  alias Ecto.Adapters.SQL.Sandbox

  @kr "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
  @kr_other "8/8/4k3/8/8/3K1R2/8/8 w - - 0 1"
  @kq "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1"

  defp create_endgame!(fen) do
    {:ok, endgame} =
      Endgames.create_endgame(%{fen: fen, color: :white, result: :win, rating: 1500})

    endgame
  end

  test "returns nil and persists nothing when there are no endgames" do
    date = ~D[2026-01-01]

    assert DailyPuzzles.for_date(date) == nil
    assert Repo.get_by(DailyPuzzle, date: date) == nil
  end

  test "persists one stable endgame for the day" do
    endgame = create_endgame!(@kr)
    date = ~D[2026-01-01]

    assert DailyPuzzles.for_date(date).id == endgame.id
    assert DailyPuzzles.for_date(date).id == endgame.id

    assert %DailyPuzzle{endgame_id: endgame_id} = Repo.get_by(DailyPuzzle, date: date)
    assert endgame_id == endgame.id
    assert Repo.aggregate(DailyPuzzle, :count) == 1
  end

  test "rotates through endgames across consecutive days" do
    create_endgame!(@kr)
    create_endgame!(@kr_other)
    create_endgame!(@kq)

    day = ~D[2026-01-01]
    ids = for offset <- 0..2, do: DailyPuzzles.for_date(Date.add(day, offset)).id

    assert length(Enum.uniq(ids)) == 3
  end

  test "falls back to an endgame when the eligible pool is exhausted" do
    endgame = create_endgame!(@kr)
    day = ~D[2026-01-01]

    assert DailyPuzzles.for_date(day).id == endgame.id
    assert DailyPuzzles.for_date(Date.add(day, 1)).id == endgame.id
  end

  test "concurrent first requests create a single assignment" do
    date = ~D[2026-01-01]
    fens = [@kr, @kr_other, @kq]

    cleanup = fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(from daily_puzzle in DailyPuzzle, where: daily_puzzle.date == ^date)
        Repo.delete_all(from endgame in Endgame, where: endgame.fen in ^fens)
      end)
    end

    # This test commits outside the sandbox so the worker tasks use real,
    # separate connections and actually race on the unique date constraint.
    cleanup.()
    on_exit(cleanup)

    endgame_ids =
      Sandbox.unboxed_run(Repo, fn ->
        for fen <- fens, do: create_endgame!(fen).id
      end)

    tasks =
      for _ <- 1..8 do
        Task.async(fn ->
          receive do
            :go -> :ok
          end

          Sandbox.unboxed_run(Repo, fn -> DailyPuzzles.for_date(date).id end)
        end)
      end

    Enum.each(tasks, &send(&1.pid, :go))
    assigned_ids = Task.await_many(tasks, 10_000)

    assert [assigned_id] = Enum.uniq(assigned_ids)
    assert assigned_id in endgame_ids

    count =
      Sandbox.unboxed_run(Repo, fn ->
        Repo.aggregate(
          from(daily_puzzle in DailyPuzzle, where: daily_puzzle.date == ^date),
          :count
        )
      end)

    assert count == 1
  end
end
