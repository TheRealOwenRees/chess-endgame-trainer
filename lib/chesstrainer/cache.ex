defmodule Chesstrainer.Cache do
  @moduledoc """
  Generic LFU cache with a periodic frequency-decay sweep.

  Entries are stored in ETS as `{key, value, frequency, last_access}`. Reads bump
  the frequency; when the cache is over its maximum size the least frequently
  used entry is evicted (ties broken by least recent use). A weekly sweep halves
  every frequency so entries that were used heavily once but have not been used
  since eventually age out.

  A daily backup runs off the cache process at a configurable UTC time, so reads
  and writes stay responsive while the snapshot is written.

  ## Examples

      iex> start_link(:tablebase)
  """

  use GenServer

  alias Chesstrainer.Cache.Backup
  alias Chesstrainer.Cache.Persist

  @default_max_size 100_000
  @default_sweep_interval :timer.hours(24 * 7)

  def start_link(table) when is_atom(table), do: start_link(table, [])

  def start_link({table, opts}), do: start_link(table, opts)

  def start_link(table, opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, {table, opts}, name: via_tuple(table))
  end

  def put(table, key, value), do: GenServer.call(via_tuple(table), {:put, key, value})
  def get(table, key), do: GenServer.call(via_tuple(table), {:get, key})
  def delete(table, key), do: GenServer.call(via_tuple(table), {:delete, key})
  def backup(table), do: Persist.backup(table)
  def sweep(table), do: GenServer.call(via_tuple(table), :sweep)

  def show(table) do
    ensure_table(table)
    :ets.tab2list(table)
  end

  def size(table), do: :ets.info(table, :size)

  @impl true
  def init({table, opts}) do
    state = %{
      table: table,
      max_size: Keyword.get(opts, :max_size, @default_max_size),
      sweep_interval: Keyword.get(opts, :sweep_interval, @default_sweep_interval),
      backup_time: Backup.time!(Keyword.get(opts, :backup_time)),
      backup_fun: Keyword.get(opts, :backup_fun, &Persist.backup/1),
      backup_timer: nil
    }

    # Create and restore synchronously so the cache is never observed empty
    # between `start_link/1` returning and the restore finishing.
    create_table(table)
    Persist.restore(table)
    __MODULE__.Evict.evict(table, state.max_size)
    :timer.send_interval(state.sweep_interval, :sweep)

    {:ok, schedule_backup(state)}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    ensure_table(state.table)
    access = System.system_time(:microsecond)
    :ets.insert(state.table, {key, value, 1, access})
    __MODULE__.Evict.evict(state.table, state.max_size)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    ensure_table(state.table)

    case :ets.lookup(state.table, key) do
      [{^key, value, frequency, _old_access}] ->
        access = System.system_time(:microsecond)
        :ets.insert(state.table, {key, value, frequency + 1, access})
        {:reply, {:ok, value}, state}

      [] ->
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:sweep, _from, state) do
    __MODULE__.Sweep.halve_frequencies(state.table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:backup, state) do
    run_backup(state)
    {:noreply, schedule_backup(state)}
  end

  @impl true
  def handle_info(:sweep, state) do
    __MODULE__.Sweep.halve_frequencies(state.table)
    {:noreply, state}
  end

  defp run_backup(state) do
    table = state.table
    backup_fun = state.backup_fun

    Task.Supervisor.start_child(Chesstrainer.Cache.BackupSupervisor, fn -> backup_fun.(table) end)
  end

  defp schedule_backup(state) do
    timer = Process.send_after(self(), :backup, Backup.next_delay(state.backup_time))
    %{state | backup_timer: timer}
  end

  defp via_tuple(table), do: {:via, Registry, {Chesstrainer.CacheRegistry, table}}

  defp ensure_table(table) do
    case :ets.whereis(table) do
      :undefined -> create_table(table)
      _ -> :ok
    end
  end

  defp create_table(table) do
    :ets.new(table, [:named_table, :public, :set])
  rescue
    ArgumentError -> table
  end
end
