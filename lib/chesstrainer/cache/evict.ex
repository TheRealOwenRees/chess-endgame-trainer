defmodule Chesstrainer.Cache.Evict do
  @moduledoc """
  Eviction for the LFU cache.
  """

  @doc """
  Evicts least-frequently-used entries until `table` holds at most `max_size`
  rows. Ties in frequency are broken by least recent use (`last_access`).
  """
  def evict(table, max_size) do
    if :ets.info(table, :size) > max_size do
      case find_least_used_entry(table) do
        {key, _frequency, _last_access} ->
          :ets.delete(table, key)
          evict(table, max_size)

        nil ->
          :ok
      end
    else
      :ok
    end
  end

  defp find_least_used_entry(table) do
    :ets.foldl(
      fn {k, _v, frequency, last_access}, acc ->
        case acc do
          nil ->
            {k, frequency, last_access}

          {_k, best_frequency, best_access}
          when {frequency, last_access} < {best_frequency, best_access} ->
            {k, frequency, last_access}

          _ ->
            acc
        end
      end,
      nil,
      table
    )
  end
end
