defmodule Chesstrainer.Cache.Evict do
  @moduledoc """
  Eviction functions for LRU cache
  """

  # O(n) time, not efficient
  def maybe_evict_oldest(table, max_size) do
    if :ets.info(table, :size) > max_size do
      case find_oldest_entry(table) do
        {oldest_key, _} -> :ets.delete(table, oldest_key)
        _ -> :ok
      end
    end
  end

  defp find_oldest_entry(table) do
    :ets.foldl(
      fn {k, _v, t}, acc ->
        case acc do
          nil -> {k, t}
          {_, oldest_t} when t < oldest_t -> {k, t}
          _ -> acc
        end
      end,
      nil,
      table
    )
  end
end
