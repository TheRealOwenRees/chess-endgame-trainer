defmodule Chesstrainer.Cache do
  @moduledoc """
  Generic LFU cache with a periodic frequency-decay sweep.

  Entries are stored in ETS as `{key, value, frequency, last_access}`. Reads bump
  the frequency; when the cache is over its maximum size the least frequently
  used entry is evicted (ties broken by least recent use). A weekly sweep halves
  every frequency so entries that were used heavily once but have not been used
  since eventually age out.

  ## Examples

      iex> start_link(:tablebase)
  """

  use GenServer

  @default_max_size 1000
  @default_sweep_interval :timer.hours(24 * 7)
  @backup_interval_minutes 60

  def start_link(table), do: start_link(table, [])

  def start_link(table, opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, {table, opts}, name: via_tuple(table))
  end

  def put(table, key, value), do: GenServer.call(via_tuple(table), {:put, key, value})
  def get(table, key), do: GenServer.call(via_tuple(table), {:get, key})
  def delete(table, key), do: GenServer.call(via_tuple(table), {:delete, key})
  def backup(table), do: GenServer.call(via_tuple(table), :backup)
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
      sweep_interval: Keyword.get(opts, :sweep_interval, @default_sweep_interval)
    }

    # Create and restore synchronously so the cache is never observed empty
    # between `start_link/1` returning and the restore finishing.
    create_table(table)
    __MODULE__.Persist.restore(table)
    __MODULE__.Evict.evict(table, state.max_size)
    :timer.send_interval(:timer.minutes(@backup_interval_minutes), :backup)
    :timer.send_interval(state.sweep_interval, :sweep)

    {:ok, state}
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
  def handle_call(:backup, _from, state) do
    __MODULE__.Persist.backup(state.table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:sweep, _from, state) do
    __MODULE__.Sweep.halve_frequencies(state.table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:backup, state) do
    __MODULE__.Persist.backup(state.table)
    {:noreply, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    __MODULE__.Sweep.halve_frequencies(state.table)
    {:noreply, state}
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
