defmodule Chesstrainer.Cache.Sweep do
  @moduledoc """
  Frequency decay for the LFU cache.

  Halving every frequency each week lets entries that were used heavily once but
  have not been used since age out of the cache.
  """

  @doc """
  Halves the frequency of every entry in `table` with integer division, so an
  entry used once decays from `1` to `0`.
  """
  def halve_frequencies(table) do
    :ets.foldl(
      fn {key, value, frequency, last_access}, :ok ->
        :ets.insert(table, {key, value, div(frequency, 2), last_access})
        :ok
      end,
      :ok,
      table
    )

    :ok
  end
end
