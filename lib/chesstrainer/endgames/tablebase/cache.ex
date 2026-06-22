defmodule Chesstrainer.Endgames.Tablebase.Cache do
  @moduledoc """
  A cache of tablebases by FEN.
  """

  alias Chesstrainer.Cache

  @table :tablebase

  def put(fen, tablebase), do: Cache.put(@table, fen, tablebase)

  def get(fen), do: Cache.get(@table, fen)

  def delete(fen), do: Cache.delete(@table, fen)
  def show, do: Cache.show(@table)
  def size, do: Cache.size(@table)
end
