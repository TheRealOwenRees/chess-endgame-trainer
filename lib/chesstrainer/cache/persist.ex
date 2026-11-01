defmodule Chesstrainer.Cache.Persist do
  @moduledoc """
  Persistence for the cache. Backup and restore functions.
  """

  @backup_path "priv/static/backups"
  @format_version "v2"

  def backup(table) do
    File.mkdir_p!(@backup_path)
    name = backup_filename(table) |> String.to_charlist()
    {:ok, dets_table} = :dets.open_file(name, type: :set)
    :ets.to_dets(table, dets_table)
    :dets.sync(dets_table)
    :dets.close(dets_table)
  end

  def restore(table) do
    File.mkdir_p!(@backup_path)
    drop_legacy_backup(table)

    path = backup_filename(table)

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

        {:error, _} ->
          :ok
      end
    end

    :ok
  end

  defp backup_filename(table), do: Path.join(@backup_path, "#{table}.#{@format_version}.det")

  defp drop_legacy_backup(table) do
    legacy = Path.join(@backup_path, "#{table}.det")
    if File.exists?(legacy), do: File.rm(legacy)
  end
end
