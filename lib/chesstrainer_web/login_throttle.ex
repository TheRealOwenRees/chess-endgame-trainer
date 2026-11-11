defmodule ChesstrainerWeb.LoginThrottle do
  @moduledoc """
  In-memory failure throttle for password logins.

  Failures are counted in two independent fixed windows: one per client address
  and one per normalised login (email or username). A successful login clears
  the login bucket only, so one account stays protected from distributed
  guessing while one address stays protected from spraying many accounts.

  Addresses and logins are HMACed with a per-boot secret before they reach ETS;
  raw values are never stored or logged. The table is per node and is cleared on
  restart, which is acceptable for the current single-node deployment.
  """

  use GenServer

  @table :login_throttle
  @sweep_interval :timer.minutes(1)
  @default_window_ms :timer.minutes(15)
  @default_max_per_ip 10
  @default_max_per_login 5

  @typedoc "An IPv4/IPv6 address, or `nil` when the socket has no peer data."
  @type address :: :inet.ip_address() | nil

  @typedoc "Which bucket blocked the attempt."
  @type bucket :: :ip | :login

  @doc "Starts the throttle."
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Checks both buckets without recording anything.

  Returns `:ok`, or `{:throttled, bucket, retry_in_ms}` when that bucket is
  already at its limit.
  """
  @spec check(address, String.t() | nil) :: :ok | {:throttled, bucket(), non_neg_integer()}
  def check(address, login), do: GenServer.call(__MODULE__, {:check, address, login})

  @doc "Records one failed authentication in both buckets."
  @spec record_failure(address, String.t() | nil) :: :ok
  def record_failure(address, login) do
    GenServer.call(__MODULE__, {:record_failure, address, login})
  end

  @doc "Clears the login bucket. The address bucket deliberately stays."
  @spec record_success(String.t() | nil) :: :ok
  def record_success(login), do: GenServer.call(__MODULE__, {:record_success, login})

  @doc """
  Claims a confirmation-email resend for `login`.

  Returns true at most once per cooldown window, so repeated unconfirmed login
  attempts cannot send a fresh confirmation email on every try.
  """
  @spec claim_confirmation_resend(String.t() | nil) :: boolean()
  def claim_confirmation_resend(login) do
    GenServer.call(__MODULE__, {:claim_confirmation_resend, login})
  end

  @doc """
  Returns a stable, non-reversible fingerprint of an address for log metadata.

  The digest is scoped to this boot, matching the throttle keys.
  """
  @spec fingerprint(address) :: String.t() | nil
  def fingerprint(address), do: GenServer.call(__MODULE__, {:fingerprint, address})

  @doc "Clears every bucket. Intended for tests."
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc "Failures allowed per address before the next attempt is blocked."
  def max_per_ip, do: config() |> Keyword.get(:max_per_ip, @default_max_per_ip)

  @doc "Failures allowed per login before the next attempt is blocked."
  def max_per_login, do: config() |> Keyword.get(:max_per_login, @default_max_per_login)

  @doc "How long a bucket stays active, in milliseconds."
  def window_ms, do: config() |> Keyword.get(:window_ms, @default_window_ms)

  defp config, do: Application.get_env(:chesstrainer, __MODULE__, [])

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :set])
    Process.send_after(self(), :sweep, @sweep_interval)

    {:ok,
     %{
       secret: :crypto.strong_rand_bytes(32),
       window_ms: Keyword.get(opts, :window_ms, window_ms()),
       max_per_ip: Keyword.get(opts, :max_per_ip, max_per_ip()),
       max_per_login: Keyword.get(opts, :max_per_login, max_per_login()),
       confirmation_cooldown_ms: Keyword.get(opts, :confirmation_cooldown_ms, window_ms())
     }}
  end

  @impl true
  def handle_call({:check, address, login}, _from, state) do
    now = now_ms()

    result =
      case blocked(:ip, address, state, now) do
        nil -> blocked(:login, normalize_login(login), state, now) || :ok
        blocked -> blocked
      end

    {:reply, result, state}
  end

  def handle_call({:record_failure, address, login}, _from, state) do
    now = now_ms()
    bump(:ip, address, state, now)
    bump(:login, normalize_login(login), state, now)
    {:reply, :ok, state}
  end

  def handle_call({:record_success, login}, _from, state) do
    case normalize_login(login) do
      nil -> :ok
      login -> :ets.delete(@table, key(state.secret, :login, login))
    end

    {:reply, :ok, state}
  end

  def handle_call({:claim_confirmation_resend, login}, _from, state) do
    normalized = normalize_login(login)
    now = now_ms()

    case normalized do
      nil ->
        {:reply, true, state}

      login ->
        key = key(state.secret, :confirmation, login)

        case count(key, now) do
          nil ->
            :ets.insert(@table, {key, now + state.confirmation_cooldown_ms, 1})
            {:reply, true, state}

          _active ->
            {:reply, false, state}
        end
    end
  end

  def handle_call({:fingerprint, nil}, _from, state), do: {:reply, nil, state}

  def handle_call({:fingerprint, address}, _from, state) do
    fingerprint =
      state.secret
      |> key(:ip, address)
      |> Base.encode16(case: :lower)

    {:reply, fingerprint, state}
  end

  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    :ets.select_delete(@table, [{{:_, :"$1", :_}, [{:"=<", :"$1", now_ms()}], [true]}])
    Process.send_after(self(), :sweep, @sweep_interval)
    {:noreply, state}
  end

  defp blocked(_bucket, nil, _state, _now), do: nil

  defp blocked(bucket, value, state, now) do
    key = key(state.secret, bucket, value)
    limit = limit(bucket, state)

    case count(key, now) do
      {count, expires_at} when count >= limit ->
        {:throttled, bucket, max(expires_at - now, 0)}

      _ ->
        nil
    end
  end

  defp bump(_bucket, nil, _state, _now), do: :ok

  defp bump(bucket, value, state, now) do
    key = key(state.secret, bucket, value)

    case count(key, now) do
      {count, expires_at} ->
        :ets.insert(@table, {key, expires_at, count + 1})

      nil ->
        :ets.insert(@table, {key, now + state.window_ms, 1})
    end
  end

  defp count(key, now) do
    case :ets.lookup(@table, key) do
      [{^key, expires_at, count}] when expires_at > now ->
        {count, expires_at}

      [{^key, _expires_at, _count}] ->
        :ets.delete(@table, key)
        nil

      [] ->
        nil
    end
  end

  defp limit(:ip, state), do: state.max_per_ip
  defp limit(:login, state), do: state.max_per_login

  defp key(secret, bucket, value) do
    :crypto.mac(:hmac, :sha256, secret, [Atom.to_string(bucket), "|", value_binary(value)])
  end

  defp value_binary(value) when is_binary(value), do: value
  defp value_binary(value) when is_tuple(value), do: :erlang.term_to_binary(value)

  defp normalize_login(login) when is_binary(login) do
    case login |> String.trim() |> String.downcase() do
      "" -> nil
      login -> login
    end
  end

  defp normalize_login(_login), do: nil

  defp now_ms, do: System.system_time(:millisecond)
end
