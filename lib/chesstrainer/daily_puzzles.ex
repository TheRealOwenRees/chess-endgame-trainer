defmodule Chesstrainer.DailyPuzzles do
  @moduledoc """
  Assigns a single endgame to each UTC day.

  The assignment is persisted so every request and every user sees the same
  featured puzzle for the day. Assignment is race-safe: concurrent first
  requests rely on the unique date constraint and read back the winning row.

  Selection prefers endgames not used in the last 30 days and falls back to
  any endgame when that pool is exhausted.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.DailyPuzzles.DailyPuzzle
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Repo

  @recent_days 30

  @doc """
  Returns today's endgame (UTC), assigning one if needed.

  Returns `nil` when no endgames exist.
  """
  def today, do: for_date(Date.utc_today())

  @doc """
  Returns the endgame assigned to `date`, assigning one if needed.

  Returns `nil` when no endgames exist.
  """
  def for_date(%Date{} = date) do
    case get_for_date(date) do
      nil -> assign_for_date(date)
      endgame -> endgame
    end
  end

  defp get_for_date(date) do
    case Repo.get_by(DailyPuzzle, date: date) do
      nil -> nil
      daily_puzzle -> Repo.preload(daily_puzzle, endgame: :themes).endgame
    end
  end

  defp assign_for_date(date) do
    case pick_endgame_id(date) do
      nil ->
        nil

      endgame_id ->
        %DailyPuzzle{}
        |> DailyPuzzle.changeset(%{date: date, endgame_id: endgame_id})
        |> Repo.insert(on_conflict: :nothing, conflict_target: :date)

        get_for_date(date)
    end
  end

  defp pick_endgame_id(date) do
    cutoff = Date.add(date, -@recent_days)

    recent_ids =
      Repo.all(
        from daily_puzzle in DailyPuzzle,
          where: daily_puzzle.date >= ^cutoff,
          select: daily_puzzle.endgame_id
      )

    eligible_ids =
      Repo.all(
        from endgame in Endgame,
          where: endgame.id not in ^recent_ids,
          select: endgame.id
      )

    ids =
      case eligible_ids do
        [] -> Repo.all(from endgame in Endgame, select: endgame.id)
        ids -> ids
      end

    case ids do
      [] -> nil
      ids -> Enum.random(ids)
    end
  end
end
