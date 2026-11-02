defmodule Chesstrainer.Cache.EvictTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Cache.Evict

  @sample_size 64

  setup do
    table = :"evict_test_#{System.unique_integer([:positive])}"
    :ets.new(table, [:named_table, :public, :set])

    {:ok, table: table}
  end

  describe "evict/3" do
    test "shrinks a table that is far over capacity", %{table: table} do
      for i <- 1..1_000, do: :ets.insert(table, {i, i, 1, i})

      Evict.evict(table, 900)

      assert :ets.info(table, :size) == 900
    end

    test "keeps a frequently used entry while cold entries are evicted", %{table: table} do
      :ets.insert(table, {:hot, :hot, 100, 0})
      for i <- 1..1_000, do: :ets.insert(table, {i, i, 1, i})

      Evict.evict(table, 100)

      assert :ets.info(table, :size) == 100
      assert [{:hot, :hot, 100, 0}] = :ets.lookup(table, :hot)
    end

    test "the returned cursor resumes the sample instead of restarting it", %{table: table} do
      for i <- 1..5, do: :ets.insert(table, {i, i, 1, i})

      assert Evict.evict(table, 10) == :start

      cursor = Evict.evict(table, 4)

      assert :ets.info(table, :size) == 4
      refute cursor == :start
    end

    test "rotates across the table, eventually evicting entries outside the first sample",
         %{table: table} do
      for i <- 1..1_000, do: :ets.insert(table, {i, i, 1, i})

      # Find the slice a fresh pass would sample and make it the hottest part of
      # the table. A pass that always restarted from `:start` would keep
      # choosing from this slice (every one of those entries is hotter than
      # everything else), so cold entries elsewhere could never be evicted.
      hot_keys = first_sample_keys(table)
      for key <- hot_keys, do: :ets.insert(table, {key, key, 1_000, key})

      Enum.reduce(1..@sample_size, :start, fn _, cursor ->
        Evict.evict(table, :ets.info(table, :size) - 1, cursor)
      end)

      frequencies = Map.new(:ets.tab2list(table), fn {key, _v, f, _t} -> {key, f} end)
      cold_left = Enum.count(frequencies, fn {_key, frequency} -> frequency == 1 end)
      hot_left = Enum.count(frequencies, fn {_key, frequency} -> frequency == 1_000 end)

      assert :ets.info(table, :size) == 1_000 - @sample_size
      assert cold_left < 1_000 - @sample_size
      assert hot_left > 0
    end
  end

  defp first_sample_keys(table) do
    match_spec = [{{:"$1", :_, :"$2", :"$3"}, [], [:"$1"]}]

    case :ets.select(table, match_spec, @sample_size) do
      {keys, _continuation} -> keys
      :"$end_of_table" -> []
    end
  end
end
