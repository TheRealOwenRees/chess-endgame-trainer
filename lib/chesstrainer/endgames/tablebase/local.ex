defmodule Chesstrainer.Endgames.Tablebase.Local do
  @moduledoc """
  Local Syzygy tablebase configuration and verification.

  The directory is read from `TABLEBASE_PATH` (see `config/runtime.exs`), so the
  same release can point at a different location on a dev machine and on a VPS
  without a rebuild. When it is unset the local backend stays disabled and
  lookups fall back to Lichess.

  On boot this logs whether the local tablebases loaded and how many pieces they
  cover, so a misconfigured path is visible in the logs.
  """

  use GenServer
  require Logger

  alias Chesstrainer.Endgames.Tablebase.Fathom

  @spec path() :: String.t() | nil
  def path do
    case Application.get_env(:chesstrainer, :tablebase_path) do
      path when is_binary(path) and path != "" -> path
      _ -> nil
    end
  end

  @doc """
  Initialises Fathom against the configured directory.

  Returns `{:ok, largest}` where `largest` is the biggest piece count available
  (`0` when the directory has no tablebase files), or `{:error, :not_configured}`
  when `TABLEBASE_PATH` is unset.
  """
  @spec check() :: {:ok, non_neg_integer()} | {:error, term()}
  def check do
    with path when is_binary(path) <- path(),
         {:ok, largest} <- Fathom.init(path) do
      {:ok, largest}
    else
      nil -> {:error, :not_configured}
      {:error, _reason} = error -> error
    end
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    log_status()
    {:ok, %{}}
  end

  defp log_status do
    case check() do
      {:ok, 0} ->
        Logger.warning("local Syzygy tablebases at #{path()} contain no files")

      {:ok, largest} ->
        Logger.info("local Syzygy tablebases ready at #{path()} (largest=#{largest})")

      {:error, :not_configured} ->
        Logger.info("local Syzygy tablebases disabled (TABLEBASE_PATH unset)")

      {:error, reason} ->
        Logger.warning("local Syzygy tablebases failed: #{inspect(reason)}")
    end
  end
end
