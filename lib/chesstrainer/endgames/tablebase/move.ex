defmodule Chesstrainer.Endgames.Tablebase.Move do
  @moduledoc """
  Moves struct for the tablebase

  Carries only the fields the trainer reads: `category` and `dtz` for grading,
  and `san`/`uci` for display and matching. Terminal detection is structural
  (the next position's `checkmate` or its empty `moves`), so no per-move
  terminal flags are kept.
  """

  @type result :: :win | :draw | :loss | :unknown

  @type t :: %__MODULE__{
          category: result,
          dtz: integer() | nil,
          san: String.t() | nil,
          uci: String.t() | nil
        }

  defstruct category: nil,
            dtz: nil,
            san: nil,
            uci: nil
end
