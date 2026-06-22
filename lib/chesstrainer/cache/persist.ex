defmodule Chesstrainer.Cache.Persist do
  @moduledoc """
  Persistance for cache. Backup and restore functions.
  """

  @backup_path "priv/static/backups"

  def backup(table) do
    File.mkdir_p!(@backup_path)
    filename = Path.join(@backup_path, "#{table}.det") |> String.to_charlist()
    {:ok, dets_table} = :dets.open_file(filename, type: :set)
    :ets.to_dets(table, dets_table)
    :dets.sync(dets_table)
  end

  def restore(table) do
    File.mkdir_p!(@backup_path)
    filename = Path.join(@backup_path, "#{table}.det") |> String.to_charlist()

    case :dets.open_file(table, file: filename, type: :set) do
      {:ok, ^table} ->
        :dets.foldl(fn entry, _ -> :ets.insert(table, entry) end, :ok, table)
        :dets.close(table)

      {:error, _} ->
        :ok
    end
  end
end
