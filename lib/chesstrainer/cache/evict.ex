defmodule Chesstrainer.Cache.Evict do
  @moduledoc """
  Eviction for the LFU cache.

  Eviction is deliberately approximate. Folding over the whole table to find the
  exact least-frequently-used entry costs O(n) on every put once the cache is at
  capacity, which stops the cache scaling past ~100k entries. Instead each pass
  samples a bounded number of entries and evicts the coldest of those: a cache
  that re-fetches on a miss only needs "a cold entry", not the coldest one.

  The sample walks the table through an `:ets.select/3` continuation, so
  successive passes look at different slices instead of rescanning the same
  first few entries. Over many puts every entry gets a turn to be considered,
  while each pass still costs the same bounded amount.
  """

  @sample_size 64

  @match_spec [{{:"$1", :_, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]

  @typedoc """
  Position in the table's select traversal.

  `:start` begins a new pass; any other value resumes the pass where the
  previous eviction left off.
  """
  @type cursor :: :start | term()

  @doc """
  Evicts entries until `table` holds at most `max_size` rows, returning the
  cursor to pass to the next call.

  Each pass samples at most #{@sample_size} entries and deletes the least
  frequently used one of them, then resumes from the advanced cursor. Ties in
  frequency are broken by least recent use (`last_access`).
  """
  @spec evict(:ets.table(), non_neg_integer(), cursor()) :: cursor()
  def evict(table, max_size, cursor \\ :start) do
    if :ets.info(table, :size) > max_size do
      case sample(table, cursor) do
        {[], :start} ->
          # End of the table: wrap and keep evicting. If we were already at the
          # start there is nothing left to sample (an empty table), so stop.
          if cursor == :start, do: :start, else: evict(table, max_size, :start)

        {entries, next} ->
          {key, _frequency, _last_access} =
            Enum.min_by(entries, fn {_key, frequency, last_access} ->
              {frequency, last_access}
            end)

          :ets.delete(table, key)
          evict(table, max_size, next)
      end
    else
      cursor
    end
  end

  defp sample(table, :start) do
    case :ets.select(table, @match_spec, @sample_size) do
      {entries, continuation} -> {entries, continuation}
      :"$end_of_table" -> {[], :start}
    end
  end

  defp sample(table, cursor) do
    case :ets.select(cursor) do
      {entries, next} -> {entries, next}
      :"$end_of_table" -> {[], :start}
    end
  rescue
    # A continuation is only valid for the table instance that produced it.
    # A deleted and recreated table, or a restore, invalidates it, so restart
    # the rotation instead of crashing the cache.
    ArgumentError -> sample(table, :start)
  end
end
