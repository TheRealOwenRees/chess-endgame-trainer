defmodule Chesstrainer.Cache.Evict do
  @moduledoc """
  Eviction for the LFU cache.

  Eviction is deliberately approximate. Folding over the whole table to find the
  exact least-frequently-used entry costs O(n) on every put once the cache is at
  capacity, which stops the cache scaling past ~100k entries. Instead each pass
  samples a bounded number of entries and evicts the coldest of those: a cache
  that re-fetches on a miss only needs "a cold entry", not the coldest one.
  """

  @sample_size 64

  @doc """
  Evicts entries until `table` holds at most `max_size` rows.

  Each pass samples at most #{@sample_size} entries and deletes the least
  frequently used one of them. Ties in frequency are broken by least recent use
  (`last_access`).
  """
  def evict(table, max_size) do
    if :ets.info(table, :size) > max_size do
      case least_used_entry(table) do
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

  @doc """
  Returns up to #{@sample_size} `{key, frequency, last_access}` entries from
  `table`, without scanning the whole table.

  `:ets.select/3` stops once it has enough matches, so the cost does not grow
  with the table's size and its hash order gives a random-enough sample.
  """
  def sample(table) do
    # `:ets.select/3` returns a continuation alongside the matches; the sample
    # is bounded, so the partial traversal is abandoned rather than resumed.
    case :ets.select(
           table,
           [{{:"$1", :_, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}],
           @sample_size
         ) do
      {entries, _continuation} -> entries
      :"$end_of_table" -> []
    end
  end

  defp least_used_entry(table) do
    case sample(table) do
      [] ->
        nil

      entries ->
        Enum.min_by(entries, fn {_key, frequency, last_access} -> {frequency, last_access} end)
    end
  end
end
