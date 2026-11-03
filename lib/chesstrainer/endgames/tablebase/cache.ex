defmodule Chesstrainer.Endgames.Tablebase.Cache do
  @moduledoc """
  A cache of tablebases keyed by position.

  The key is a FEN's position fields (see `Chesstrainer.FEN.position_key/1`), so
  transpositions and clock-only differences share an entry.
  """

  alias Chesstrainer.Cache

  @table :tablebase

  def put(key, tablebase), do: Cache.put(@table, key, tablebase)

  def get(key), do: Cache.get(@table, key)

  def delete(key), do: Cache.delete(@table, key)
  def show, do: Cache.show(@table)
  def size, do: Cache.size(@table)
end
