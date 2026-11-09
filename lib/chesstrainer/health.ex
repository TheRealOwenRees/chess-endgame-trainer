defmodule Chesstrainer.Health do
  @moduledoc """
  Runtime health snapshot for deploy smoke tests and uptime monitors.

  The database is the only hard dependency. Tablebase status is informational:
  local Syzygy files are preferred, but falling back to Lichess is not an
  outage, so a missing or broken local cache reports `degraded` with HTTP 200.
  """

  alias Chesstrainer.Endgames.Tablebase.Local
  alias Chesstrainer.Repo

  @type status :: %{
          status: String.t(),
          db: String.t(),
          tablebase: String.t(),
          process: String.t()
        }

  @doc "Returns the current health status."
  @spec status() :: status()
  def status do
    db = if database_up?(), do: "ok", else: "down"
    tablebase = tablebase_status()

    overall =
      cond do
        db == "down" -> "down"
        tablebase == "local" -> "ok"
        true -> "degraded"
      end

    %{status: overall, db: db, tablebase: tablebase, process: "ok"}
  end

  defp database_up? do
    case Application.get_env(:chesstrainer, :health_database_check) do
      fun when is_function(fun, 0) -> fun.()
      _ -> default_database_up?()
    end
  end

  defp default_database_up? do
    case Repo.query("SELECT 1") do
      {:ok, _result} -> true
      _ -> false
    end
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  defp tablebase_status do
    case Local.check() do
      {:ok, largest} when largest > 0 -> "local"
      {:ok, _largest} -> "fallback"
      {:error, :not_configured} -> "not_configured"
      {:error, _reason} -> "fallback"
    end
  end
end
