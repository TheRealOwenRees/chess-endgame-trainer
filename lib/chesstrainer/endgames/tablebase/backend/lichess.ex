defmodule Chesstrainer.Endgames.Tablebase.Backend.Lichess do
  @moduledoc """
  The Lichess tablebase API backend (covers up to seven pieces).
  """

  @behaviour Chesstrainer.Endgames.Tablebase.Backend

  alias Chesstrainer.Endgames.Tablebase.Parser

  @impl true
  def probe(fen), do: Parser.from_fen(fen)
end
