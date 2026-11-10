defmodule ChesstrainerWeb.RequestLogger do
  @moduledoc """
  Emits one structured access line per HTTP request.

  The line carries the method, path, status, duration in milliseconds and the
  request id when one is available. Query parameters and bodies are never
  logged. Path segments that look like tokens or identifiers (20 or more
  URL-safe characters) are replaced with `[REDACTED]`.

  `Phoenix.Logger`'s own endpoint start/stop lines are disabled in
  `ChesstrainerWeb.Endpoint` so each request produces exactly one line.
  """

  require Logger

  @event [:phoenix, :endpoint, :stop]
  @handler_id {__MODULE__, :access_log}
  @token_segment ~r/\A[A-Za-z0-9_.-]{20,}\z/

  @doc false
  def install do
    case :telemetry.attach(@handler_id, @event, &__MODULE__.handle_event/4, :ok) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @doc false
  def handle_event(_event, measurements, metadata, _config) do
    conn = metadata.conn
    duration_ms = duration_ms(measurements.duration)
    path = redact_path(conn.request_path)
    status = conn.status || 0

    metadata =
      [
        method: conn.method,
        path: path,
        status: status,
        duration_ms: duration_ms
      ]
      |> put_request_id(conn.assigns[:request_id])

    Logger.info("#{conn.method} #{path} #{status} in #{duration_ms}ms", metadata)
  end

  defp duration_ms(native) do
    native
    |> System.convert_time_unit(:native, :microsecond)
    |> Kernel./(1000)
    |> Float.round(1)
  end

  defp put_request_id(metadata, nil), do: metadata
  defp put_request_id(metadata, request_id), do: Keyword.put(metadata, :request_id, request_id)

  defp redact_path(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", &redact_segment/1)
  end

  defp redact_segment(segment) do
    if Regex.match?(@token_segment, segment), do: "[REDACTED]", else: segment
  end
end
