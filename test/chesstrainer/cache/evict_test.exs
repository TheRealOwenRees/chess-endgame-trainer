defmodule Chesstrainer.Cache.EvictTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Cache.Evict

  setup do
    table = :"evict_test_#{System.unique_integer([:positive])}"
    :ets.new(table, [:named_table, :public, :set])

    {:ok, table: table}
  end

  describe "sampling" do
    test "returns at most 64 entries from a large table", %{table: table} do
      for i <- 1..1_000, do: :ets.insert(table, {i, i, 1, i})

      sample = Evict.sample(table)

      assert length(sample) == 64

      assert Enum.all?(sample, fn {key, frequency, last_access} ->
               is_integer(key) and frequency == 1 and is_integer(last_access)
             end)
    end

    test "returns every entry when the table is smaller than the sample", %{table: table} do
      for i <- 1..5, do: :ets.insert(table, {i, i, 1, i})

      assert length(Evict.sample(table)) == 5
    end
  end

  describe "evict/2" do
    test "shrinks a table that is far over capacity", %{table: table} do
      for i <- 1..1_000, do: :ets.insert(table, {i, i, 1, i})

      assert :ok = Evict.evict(table, 900)
      assert :ets.info(table, :size) == 900
    end

    test "keeps a frequently used entry while cold entries are evicted", %{table: table} do
      :ets.insert(table, {:hot, :hot, 100, 0})
      for i <- 1..1_000, do: :ets.insert(table, {i, i, 1, i})

      assert :ok = Evict.evict(table, 100)

      assert :ets.info(table, :size) == 100
      assert [{:hot, :hot, 100, 0}] = :ets.lookup(table, :hot)
    end
  end
end
