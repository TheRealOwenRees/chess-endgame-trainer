defmodule Chesstrainer.JSONLogFormatter do
  @moduledoc """
  An OTP logger formatter that emits one JSON object per log line.

  Production uses this formatter (see `config/prod.exs`), while development and
  test keep `Logger.Formatter`'s readable output. Every line carries a
  timestamp, level and message, plus a request id when one is in the logger
  metadata. Access lines add `method`, `path`, `status` and `duration_ms`;
  exceptions and OTP crash reports add an `error` object with `kind`, `reason`
  and `stacktrace`.

  The formatter is defensive. Metadata is sanitised into JSON-safe values, and
  an event that cannot be encoded still produces a single JSON line instead of
  taking the logger down. Email addresses and credentials found in metadata,
  params or the rendered message are replaced with `[REDACTED]`.
  """

  @max_message_bytes 8_096
  @max_stacktrace_entries 50
  @redacted "[REDACTED]"

  @email_regex ~r/[A-Za-z0-9.!#$%&'*+\/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+/
  @secret_assignment_regex ~r/\b(token|password|secret|api[_-]?key|authorization)=([^&\s"']+)/i

  @sensitive_key_fragments ~w(password secret token authorization cookie api_key private_key credential)
  @sensitive_email_keys ~w(email email_address user_email contact_email recipient)

  # These are unpacked into the line itself rather than copied as metadata.
  @internal_keys [
    :time,
    :gl,
    :report_cb,
    :error_logger,
    :exception,
    :stacktrace,
    :crash_reason,
    :reason,
    :kind,
    :conn,
    :socket
  ]

  # Fixed fields always win over a metadata key with the same name.
  @reserved_keys [
    :timestamp,
    :level,
    :message,
    :error,
    :request_id,
    :method,
    :path,
    :status,
    :duration_ms
  ]

  @doc """
  Formats a `:logger` event as a newline-terminated JSON object.
  """
  @spec format(:logger.log_event(), :logger.formatter_config()) :: iodata()
  def format(event, _config) do
    event
    |> build()
    |> Jason.encode!()
    |> then(&[&1, ?\n])
  rescue
    exception -> fallback(exception)
  catch
    kind, reason -> fallback({kind, reason})
  end

  defp build(event) do
    meta = event.meta || %{}

    %{
      "timestamp" => timestamp(meta),
      "level" => to_string(event.level),
      "message" => message(event)
    }
    |> put_access(meta)
    |> put_metadata(meta)
    |> put_error(meta)
  end

  defp timestamp(%{time: time}) when is_integer(time) do
    time
    |> DateTime.from_unix!(:microsecond)
    |> DateTime.to_iso8601()
  end

  defp timestamp(_meta), do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp message(event) do
    event
    |> Logger.Formatter.format_event(@max_message_bytes)
    |> Logger.Formatter.prune()
    |> IO.iodata_to_binary()
    |> redact_text()
  rescue
    _exception ->
      event.msg
      |> inspect(limit: 20, printable_limit: @max_message_bytes)
      |> redact_text()
  catch
    _kind, reason ->
      {event.msg, reason}
      |> inspect(limit: 20, printable_limit: @max_message_bytes)
      |> redact_text()
  end

  defp put_access(entry, meta) do
    entry
    |> put_if_present("request_id", meta[:request_id])
    |> put_if_present("method", meta[:method])
    |> put_if_present("path", meta[:path])
    |> put_if_present("status", meta[:status])
    |> put_if_present("duration_ms", meta[:duration_ms])
  end

  defp put_if_present(entry, _key, nil), do: entry

  defp put_if_present(entry, key, value) do
    Map.put(entry, key, sanitize(value, key))
  end

  defp put_metadata(entry, meta) do
    Enum.reduce(meta, entry, fn
      {key, _value}, acc when key in @internal_keys ->
        acc

      {key, _value}, acc when key in @reserved_keys ->
        acc

      {key, value}, acc ->
        Map.put(acc, key |> key_string() |> redact_text(), metadata_value(key, value))
    end)
  end

  defp metadata_value(:mfa, {module, function, arity})
       when is_atom(module) and is_atom(function) and is_integer(arity) do
    Exception.format_mfa(module, function, arity)
  end

  defp metadata_value(key, value), do: sanitize(value, key)

  # Only the first exception/reason source is rendered. OTP crash reports carry
  # `crash_reason`, while Logger.error(..., exception: ..., stacktrace: ...)
  # carries the two keys directly.
  defp put_error(entry, meta) do
    case error(meta) do
      nil -> entry
      error when map_size(error) == 0 -> entry
      error -> Map.put(entry, "error", error)
    end
  end

  defp error(%{exception: %{__exception__: true} = exception} = meta) do
    %{
      "kind" => inspect(exception.__struct__),
      "reason" => Exception.message(exception),
      "stacktrace" => stacktrace(meta[:stacktrace])
    }
    |> drop_nil()
  end

  defp error(%{crash_reason: crash_reason} = meta) do
    {reason, trace} = split_crash_reason(crash_reason, meta[:stacktrace])

    %{
      "kind" => error_kind(reason),
      "reason" => error_reason(reason),
      "stacktrace" => stacktrace(trace)
    }
    |> drop_nil()
  end

  defp error(meta) do
    if meta[:reason] || meta[:stacktrace] do
      %{
        "kind" => meta[:kind] && to_string(meta[:kind]),
        "reason" => error_reason(meta[:reason]),
        "stacktrace" => stacktrace(meta[:stacktrace])
      }
      |> drop_nil()
    end
  end

  defp split_crash_reason({reason, trace}, _fallback) when is_list(trace), do: {reason, trace}
  defp split_crash_reason(reason, fallback), do: {reason, fallback}

  defp error_kind(%{__exception__: true} = exception), do: inspect(exception.__struct__)
  defp error_kind(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_kind(reason) when is_tuple(reason), do: reason |> elem(0) |> error_kind()
  defp error_kind(_reason), do: nil

  defp error_reason(nil), do: nil
  defp error_reason(%{__exception__: true} = exception), do: Exception.message(exception)
  defp error_reason(reason) when is_binary(reason), do: redact_text(reason)

  defp error_reason(reason) do
    reason
    |> inspect(limit: 30, printable_limit: 2_000)
    |> redact_text()
  end

  defp stacktrace(stacktrace) when is_list(stacktrace) and stacktrace != [] do
    stacktrace
    |> Enum.take(@max_stacktrace_entries)
    |> Enum.map(&format_stacktrace_entry/1)
    |> Enum.map(&redact_text/1)
  end

  defp stacktrace(_stacktrace), do: nil

  defp format_stacktrace_entry(entry) do
    Exception.format_stacktrace_entry(entry)
  rescue
    _exception -> inspect(entry, limit: 10, printable_limit: 1_000)
  end

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_string(key) when is_binary(key), do: key
  defp key_string(key), do: inspect(key)

  defp sanitize(nil, _key), do: nil
  defp sanitize(value, _key) when is_boolean(value), do: value
  defp sanitize(value, _key) when is_integer(value) or is_float(value), do: value

  defp sanitize(value, key) when is_binary(value) do
    cond do
      sensitive_key?(key) -> @redacted
      String.valid?(value) -> redact_text(value)
      true -> inspect(value)
    end
  end

  defp sanitize(value, _key) when is_atom(value), do: Atom.to_string(value)

  defp sanitize(value, _key) when is_struct(value) do
    value
    |> inspect(limit: 20, printable_limit: 2_000)
    |> redact_text()
  end

  defp sanitize(value, key) when is_list(value) do
    cond do
      sensitive_key?(key) -> @redacted
      value != [] and List.ascii_printable?(value) -> value |> List.to_string() |> redact_text()
      true -> Enum.map(value, &sanitize(&1, nil))
    end
  end

  defp sanitize(value, _key) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&sanitize(&1, nil))
  end

  defp sanitize(value, _key) when is_map(value) do
    Enum.into(value, %{}, fn {key, nested} ->
      {key |> key_string() |> redact_text(), sanitize(nested, key)}
    end)
  end

  defp sanitize(value, _key) do
    value
    |> inspect(limit: 20, printable_limit: 2_000)
    |> redact_text()
  end

  defp sensitive_key?(nil), do: false

  defp sensitive_key?(key) do
    key = key |> key_string() |> String.downcase()

    key in @sensitive_email_keys or String.ends_with?(key, "_email") or
      Enum.any?(@sensitive_key_fragments, &String.contains?(key, &1))
  end

  defp redact_text(text) when is_binary(text) do
    text = if String.valid?(text), do: text, else: inspect(text)

    text
    |> then(&Regex.replace(@email_regex, &1, @redacted))
    |> then(&Regex.replace(@secret_assignment_regex, &1, "\\1=#{@redacted}"))
  end

  defp fallback(reason) do
    entry = %{
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "level" => "error",
      "message" => "could not format log event",
      "error" => %{
        "reason" => reason |> inspect(limit: 10, printable_limit: 1_000) |> redact_text()
      }
    }

    json =
      case Jason.encode(entry) do
        {:ok, json} -> json
        {:error, _reason} -> ~s({"level":"error","message":"could not format log event"})
      end

    [json, ?\n]
  end
end
