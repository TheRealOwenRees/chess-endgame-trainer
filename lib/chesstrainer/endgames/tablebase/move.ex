defmodule Chesstrainer.Endgames.Tablebase.Move do
  @moduledoc """
  Moves struct for the tablebase

  Carries only the fields the trainer reads: `category` and `dtz` for grading,
  `san`/`uci` for display and matching, and `dtm`/`dtc` as small distance
  hedges. Terminal detection is structural (the next position's `checkmate` or
  its empty `moves`), so no per-move terminal flags are kept.
  """

  @type result :: :win | :draw | :loss | :unknown

  @type t :: %__MODULE__{
          category: result,
          dtc: integer() | nil,
          dtm: integer() | nil,
          dtz: integer() | nil,
          san: String.t() | nil,
          uci: String.t() | nil
        }

  defstruct category: nil,
            dtc: nil,
            dtm: nil,
            dtz: nil,
            san: nil,
            uci: nil
end
