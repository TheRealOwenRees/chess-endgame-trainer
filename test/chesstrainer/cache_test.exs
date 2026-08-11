defmodule Chesstrainer.CacheTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Cache

  setup do
    table = :"test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Cache.start_link(table)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    {:ok, %{pid: pid, table: table}}
  end

  describe "ChessTrainer.Cache function tests" do
    test "cache is started", %{pid: pid, table: table} do
      assert is_pid(pid)
      assert 0 = Cache.size(table)
    end

    test "put/3", %{table: table} do
      assert :ok = Cache.put(table, "key1", "value1")
      assert {:ok, "value1"} = Cache.get(table, "key1")
      assert 1 = Cache.size(table)

      assert :ok = Cache.put(table, "key2", "value2")
      assert {:ok, "value2"} = Cache.get(table, "key2")
      assert 2 = Cache.size(table)
    end

    test "delete/2", %{table: table} do
      assert :ok = Cache.put(table, "key1", "value1")
      assert :ok = Cache.put(table, "key2", "value2")
      assert 2 = Cache.size(table)

      assert :ok = Cache.delete(table, "key1")
      assert 1 = Cache.size(table)
      assert :error = Cache.get(table, "key1")
    end
  end
end
