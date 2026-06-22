defmodule Chesstrainer.Ratelimiters.Lichess do
  @moduledoc """
  Global rate limiter for 429 response codes from the Lichess API.
  """

  @cooldown_seconds 60
  @table :lichess_cooldown

  def add_cooldown do
    ensure_table()
    insert_cooldown()
  end

  def reset_cooldown do
    ensure_table()
    :ets.insert(@table, {:until, nil})
  end

  def check_cooldown do
    ensure_table()
    current_ms = System.system_time(:millisecond)

    case :ets.lookup(@table, :until) do
      [{:until, nil}] ->
        {:ok, 0}

      [{:until, until_ms}] ->
        remaining = until_ms - current_ms

        if remaining <= 0 do
          reset_cooldown()
          {:ok, 0}
        else
          {:cooldown, remaining}
        end
    end
  end

  defp create do
    :ets.new(@table, [:named_table, :public, :set])
    :ets.insert(@table, {:until, nil})
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> create()
      _ -> :ok
    end
  end

  defp insert_cooldown do
    until_ms = System.system_time(:millisecond) + @cooldown_seconds * 1000
    :ets.insert(@table, {:until, until_ms})
  end
end
