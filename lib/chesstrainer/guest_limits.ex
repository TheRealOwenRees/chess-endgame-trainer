defmodule Chesstrainer.GuestLimits do
  @moduledoc """
  Daily puzzle budget for anonymous visitors.

  Each visitor gets a fixed number of puzzles per UTC day. Visitors are
  identified by an HMAC of their client address — the address itself is never
  stored, logged, or persisted. The digest lives only in ETS, is scoped to the
  current UTC date, and is swept away when the day rolls over. The HMAC secret
  is generated at boot, so digests are not stable across restarts.

  Budgets reset for everyone at 00:00 UTC: the date is part of the key, so a
  new day simply starts a new entry.
  """

  use GenServer

  @table :guest_limits
  @default_limit 5
  @sweep_interval :timer.minutes(10)

  @typedoc "An IPv4/IPv6 address, or `nil` when the socket has no peer data."
  @type address :: :inet.ip_address() | nil

  @doc "Starts the limiter."
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Consumes one puzzle from `address`'s budget for `today`.

  Returns `{:ok, remaining}` with the puzzles left today, or
  `{:limit_reached, retry_in_ms}` when the budget is spent. A `nil` address is
  not limited and returns `{:ok, nil}`.
  """
  @spec take(address, Date.t()) ::
          {:ok, non_neg_integer | nil} | {:limit_reached, non_neg_integer}
  def take(address, today \\ Date.utc_today()) do
    GenServer.call(__MODULE__, {:take, address, today})
  end

  @doc "Clears every budget. Intended for tests."
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc """
  Returns the puzzles left today without consuming one.

  Mirrors `take/2`'s result shape so a caller can show the wall before doing
  work that would otherwise spend a puzzle.
  """
  @spec remaining(address, Date.t()) ::
          {:ok, non_neg_integer | nil} | {:limit_reached, non_neg_integer}
  def remaining(address, today \\ Date.utc_today()) do
    GenServer.call(__MODULE__, {:remaining, address, today})
  end

  @doc "The daily puzzle allowance for a guest."
  def limit, do: config() |> Keyword.get(:limit, @default_limit)

  @doc """
  Whether to read the client address from `X-Forwarded-For`.

  Enable only behind a proxy that overwrites or appends the header.
  """
  def trust_forwarded_for?, do: config() |> Keyword.get(:trust_forwarded_for, false)

  defp config, do: Application.get_env(:chesstrainer, __MODULE__, [])

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :set])
    Process.send_after(self(), :sweep, @sweep_interval)

    {:ok,
     %{
       limit: Keyword.get(opts, :limit, limit()),
       secret: :crypto.strong_rand_bytes(32)
     }}
  end

  @impl true
  def handle_call({:take, nil, _today}, _from, state), do: {:reply, {:ok, nil}, state}

  def handle_call({:remaining, nil, _today}, _from, state), do: {:reply, {:ok, nil}, state}

  def handle_call({:remaining, address, today}, _from, state) do
    day = Date.to_gregorian_days(today)
    key = key(state.secret, day, address)

    case count(key, day) do
      used when used >= state.limit ->
        {:reply, {:limit_reached, ms_until_utc_midnight()}, state}

      used ->
        {:reply, {:ok, state.limit - used}, state}
    end
  end

  def handle_call({:take, address, today}, _from, state) do
    day = Date.to_gregorian_days(today)
    key = key(state.secret, day, address)

    case count(key, day) do
      used when used >= state.limit ->
        {:reply, {:limit_reached, ms_until_utc_midnight()}, state}

      used ->
        :ets.insert(@table, {key, day, used + 1})
        {:reply, {:ok, state.limit - used - 1}, state}
    end
  end

  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep(Date.to_gregorian_days(Date.utc_today()))
    Process.send_after(self(), :sweep, @sweep_interval)
    {:noreply, state}
  end

  defp count(key, day) do
    case :ets.lookup(@table, key) do
      [{^key, ^day, used}] -> used
      _ -> 0
    end
  end

  defp key(secret, day, address) do
    :crypto.mac(:hmac, :sha256, secret, [Integer.to_string(day), "|", address_binary(address)])
  end

  defp address_binary(address) when is_tuple(address), do: :erlang.term_to_binary(address)

  defp sweep(day) do
    :ets.select_delete(@table, [{{:_, :"$1", :_}, [{:<, :"$1", day}], [true]}])
  end

  defp ms_until_utc_midnight do
    now = DateTime.utc_now()
    midnight = now |> DateTime.to_date() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    max(DateTime.diff(midnight, now, :millisecond), 0)
  end
end
