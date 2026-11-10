defmodule Chesstrainer.Cache.Persist do
  @moduledoc """
  Persistence for the cache. Backup and restore functions.

  A backup is written to a temporary DETS file in the same directory and then
  atomically renamed into place. A crash during the write therefore leaves the
  previous backup untouched instead of a truncated file that fails to restore.

  A backup that cannot be opened at boot is logged and skipped, so a damaged
  file does not stop the application from starting with an empty cache.
  """

  require Logger

  @backup_path "priv/static/backups"
  @format_version "v2"

  @doc """
  Writes the `table` to its backup file. Returns `:ok` or `{:error, reason}`.
  """
  def backup(table) do
    File.mkdir_p!(@backup_path)
    path = backup_path(table)

    :global.trans(
      {__MODULE__, table},
      fn -> write(table, path <> ".tmp", path) end,
      [node()],
      :infinity
    )
  end

  @doc """
  Restores the backup file for `table`, if a readable one exists.
  """
  def restore(table) do
    File.mkdir_p!(@backup_path)
    drop_legacy_backup(table)

    path = backup_path(table)

    if File.exists?(path) do
      name = String.to_charlist(path)

      case :dets.open_file(table, file: name, type: :set) do
        {:ok, ^table} ->
          :dets.foldl(
            fn
              {key, value, frequency, last_access}, :ok when is_integer(frequency) ->
                :ets.insert(table, {key, value, frequency, last_access})
                :ok

              _entry, :ok ->
                :ok
            end,
            :ok,
            table
          )

          :dets.close(table)

        {:error, reason} ->
          Logger.warning("cache backup restore failed", table: table, reason: reason)
          :ok
      end
    end

    :ok
  end

  @doc """
  The path of the backup file for `table`.
  """
  def backup_path(table), do: Path.join(@backup_path, "#{table}.#{@format_version}.det")

  defp write(table, temp, path) do
    # Remove a stale temporary file left by an earlier crash; if the path is
    # unusable the open below fails and the existing backup stays in place.
    _ = File.rm(temp)

    result =
      with {:ok, dets_table} <- :dets.open_file(String.to_charlist(temp), type: :set) do
        try do
          _ = :ets.to_dets(table, dets_table)
          :dets.sync(dets_table)
        after
          :dets.close(dets_table)
        end
      end

    case result do
      :ok ->
        case File.rename(temp, path) do
          :ok ->
            :ok

          {:error, reason} ->
            _ = File.rm(temp)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp drop_legacy_backup(table) do
    legacy = Path.join(@backup_path, "#{table}.det")
    if File.exists?(legacy), do: File.rm(legacy)
  end
end
