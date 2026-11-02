defmodule Chesstrainer.Cache.BackupSchedule do
  @moduledoc """
  Daily off-peak schedule for cache backups.

  The cache backs up once a day at a configurable UTC time (03:00 by default).
  The delay is computed from the wall clock, so restarts and clock drift do not
  shift the run towards peak hours the way a fixed interval from boot would.

  This module only computes the schedule; writing the backup is
  `Chesstrainer.Cache.Persist.backup/1`.
  """

  @default_time {3, 0}

  @doc """
  Parses a backup time given as `{hour, minute}` or an `"HH:MM"` string.
  """
  def parse_time({hour, minute}) when hour in 0..23 and minute in 0..59,
    do: {:ok, {hour, minute}}

  def parse_time(value) when is_binary(value) do
    with [hour, minute] <- String.split(value, ":"),
         {hour, ""} <- Integer.parse(hour),
         {minute, ""} <- Integer.parse(minute),
         true <- hour in 0..23 and minute in 0..59 do
      {:ok, {hour, minute}}
    else
      _ -> :error
    end
  end

  def parse_time(_value), do: :error

  @doc """
  Normalises a backup time, falling back to #{inspect(@default_time)} UTC when
  no time is configured.
  """
  def time!(nil), do: @default_time

  def time!(value) do
    case parse_time(value) do
      {:ok, time} ->
        time

      :error ->
        raise ArgumentError, "invalid cache backup time: #{inspect(value)}"
    end
  end

  @doc """
  Milliseconds from `now` until the next occurrence of `time`, in UTC.

  When `now` is exactly the scheduled time the next run is a full day away, so
  a run always re-arms the following day rather than firing twice.
  """
  def next_delay(time, now \\ DateTime.utc_now()) do
    {hour, minute} = time!(time)

    today = DateTime.new!(DateTime.to_date(now), Time.new!(hour, minute, 0))

    next_run =
      if DateTime.compare(today, now) == :gt do
        today
      else
        DateTime.add(today, 1, :day)
      end

    DateTime.diff(next_run, now, :millisecond)
  end
end
