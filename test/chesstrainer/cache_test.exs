defmodule Chesstrainer.CacheTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Cache

  setup context do
    table = :"test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Cache.start_link(table, Map.get(context, :cache_opts, []))
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    {:ok, %{pid: pid, table: table}}
  end

  describe "basic operations" do
    test "cache is started", %{pid: pid, table: table} do
      assert is_pid(pid)
      assert 0 = Cache.size(table)
    end

    test "put/3 and get/2", %{table: table} do
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

  describe "configuration" do
    test "defaults to a max size of 100_000", %{pid: pid} do
      assert :sys.get_state(pid).max_size == 100_000
    end

    test "starts from a {table, opts} child spec argument" do
      table = :"test_child_spec_#{System.unique_integer([:positive])}"
      {:ok, pid} = Cache.start_link({table, max_size: 3})
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      assert :sys.get_state(pid).max_size == 3
    end

    test "the application starts the tablebase cache with the configured options" do
      config = Application.get_env(:chesstrainer, Chesstrainer.Cache, [])
      pid = GenServer.whereis({:via, Registry, {Chesstrainer.CacheRegistry, :tablebase}})
      state = :sys.get_state(pid)

      assert state.max_size == Keyword.get(config, :max_size, 100_000)

      assert state.backup_time ==
               Chesstrainer.Cache.Backup.time!(Keyword.get(config, :backup_time))
    end
  end

  describe "frequency tracking" do
    test "get/2 increments the entry frequency", %{table: table} do
      Cache.put(table, "key", "value")
      Cache.get(table, "key")
      Cache.get(table, "key")
      Cache.get(table, "key")

      assert [{"key", "value", frequency, _last_access}] = Cache.show(table)
      assert frequency == 4
    end
  end

  describe "LFU eviction" do
    @describetag cache_opts: [max_size: 2]

    test "evicts the least-frequently-used entry on overflow", %{table: table} do
      Cache.put(table, "hot", "value")
      for _ <- 1..5, do: Cache.get(table, "hot")

      Cache.put(table, "cold", "value")
      Cache.put(table, "new", "value")

      assert Cache.size(table) == 2
      assert {:ok, "value"} = Cache.get(table, "hot")
      assert :error = Cache.get(table, "cold")
      assert {:ok, "value"} = Cache.get(table, "new")
    end

    test "breaks frequency ties by least-recently-used", %{table: table} do
      Cache.put(table, "older", "value")
      Cache.put(table, "newer", "value")
      Cache.put(table, "newest", "value")

      assert Cache.size(table) == 2
      assert :error = Cache.get(table, "older")
      assert {:ok, "value"} = Cache.get(table, "newer")
      assert {:ok, "value"} = Cache.get(table, "newest")
    end
  end

  describe "eviction on a cache larger than the sample" do
    @describetag cache_opts: [max_size: 100]

    test "stays at the maximum size under churn", %{table: table} do
      for i <- 1..500, do: Cache.put(table, i, i)

      assert Cache.size(table) == 100
    end

    test "a frequently used entry survives churn from cold entries", %{table: table} do
      Cache.put(table, :hot, "value")
      for _ <- 1..50, do: Cache.get(table, :hot)

      for i <- 1..500, do: Cache.put(table, i, i)

      assert Cache.size(table) == 100
      assert {:ok, "value"} = Cache.get(table, :hot)
    end
  end

  describe "weekly sweep" do
    test "halves every entry frequency", %{table: table} do
      Cache.put(table, "busy", "value")
      for _ <- 1..5, do: Cache.get(table, "busy")

      Cache.put(table, "idle", "value")

      Chesstrainer.Cache.Sweep.halve_frequencies(table)

      frequencies = Map.new(Cache.show(table), fn {k, _v, f, _t} -> {k, f} end)
      assert frequencies["busy"] == 3
      assert frequencies["idle"] == 0
    end
  end

  describe "backup" do
    test "runs off the cache process so reads and writes stay responsive" do
      table = :"test_async_backup_#{System.unique_integer([:positive])}"
      parent = self()
      ref = make_ref()

      backup_fun = fn _table ->
        send(parent, {:backup_started, ref, self()})

        receive do
          {:finish_backup, ^ref} -> :ok
        end
      end

      {:ok, pid} = Cache.start_link(table, backup_fun: backup_fun)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      assert :ok = Cache.put(table, "key", "value")

      send(pid, :backup)

      assert_receive {:backup_started, ^ref, backup_pid}, 1_000
      backup_monitor = Process.monitor(backup_pid)

      assert {:ok, "value"} = Cache.get(table, "key")
      assert :ok = Cache.put(table, "other", "value")

      send(backup_pid, {:finish_backup, ref})
      assert_receive {:DOWN, ^backup_monitor, :process, ^backup_pid, :normal}, 1_000
    end

    test "re-arms the daily backup after each run" do
      table = :"test_rearm_#{System.unique_integer([:positive])}"
      {:ok, pid} = Cache.start_link(table, backup_fun: fn _table -> :ok end, backup_time: "04:30")
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      send(pid, :backup)

      state = :sys.get_state(pid)

      assert state.backup_time == {4, 30}
      assert is_reference(state.backup_timer)
      assert :erlang.read_timer(state.backup_timer) > 0
    end
  end

  describe "persistence" do
    test "writes the backup atomically, leaving no temporary file" do
      table = :"test_atomic_#{System.unique_integer([:positive])}"
      backup = Path.join("priv/static/backups", "#{table}.v2.det")

      on_exit(fn ->
        File.rm_rf(backup <> ".tmp")
        File.rm(backup)
      end)

      {:ok, pid} = Cache.start_link(table)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      Cache.put(table, "key", "value")

      assert :ok = Cache.backup(table)
      assert File.exists?(backup)
      refute File.exists?(backup <> ".tmp")
    end

    test "a failed backup leaves the previous backup intact" do
      table = :"test_failed_backup_#{System.unique_integer([:positive])}"
      backup = Path.join("priv/static/backups", "#{table}.v2.det")
      temp = backup <> ".tmp"

      on_exit(fn ->
        File.rm_rf(temp)
        File.rm(backup)
      end)

      {:ok, pid} = Cache.start_link(table)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      Cache.put(table, "key", "value")
      assert :ok = Cache.backup(table)

      # A directory at the temporary path makes the write fail before the rename.
      File.mkdir_p!(temp)
      Cache.put(table, "another", "value")

      assert {:error, _reason} = Cache.Persist.backup(table)
      assert File.exists?(backup)
      assert :ok = GenServer.stop(pid)

      {:ok, restored_pid} = Cache.start_link(table)
      on_exit(fn -> if Process.alive?(restored_pid), do: GenServer.stop(restored_pid) end)

      assert {:ok, "value"} = Cache.get(table, "key")
      assert :error = Cache.get(table, "another")
    end

    test "backup and restore preserve frequencies" do
      table = :"test_persist_#{System.unique_integer([:positive])}"
      backup = Path.join("priv/static/backups", "#{table}.v2.det")
      on_exit(fn -> File.rm(backup) end)

      {:ok, pid} = Cache.start_link(table)

      Cache.put(table, "key", "value")
      Cache.get(table, "key")
      Cache.get(table, "key")

      assert :ok = Cache.backup(table)
      assert :ok = GenServer.stop(pid)

      {:ok, restored_pid} = Cache.start_link(table)
      on_exit(fn -> if Process.alive?(restored_pid), do: GenServer.stop(restored_pid) end)

      assert [{"key", "value", frequency, _last_access}] = Cache.show(table)
      assert frequency == 3
    end
  end
end
