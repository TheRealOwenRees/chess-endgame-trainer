defmodule Chesstrainer.Endgames.Tablebase.Move do
  @moduledoc """
  Moves struct for the tablebase
  """

  @type result :: :win | :draw | :loss

  @type t :: %__MODULE__{
          category: result,
          checkmate: boolean(),
          conversion: boolean(),
          dtc: integer() | nil,
          dtm: integer() | nil,
          dtw: integer() | nil,
          dtz: integer() | nil,
          precise_dtz: integer() | nil,
          san: String.t() | nil,
          stalemate: boolean(),
          uci: String.t() | nil,
          variant_loss: boolean(),
          variant_win: boolean(),
          zeroing: boolean(),
          insufficient_material: boolean()
        }

  defstruct category: nil,
            checkmate: false,
            conversion: false,
            dtc: nil,
            dtm: nil,
            dtw: nil,
            dtz: nil,
            precise_dtz: nil,
            san: nil,
            stalemate: false,
            uci: nil,
            variant_loss: false,
            variant_win: false,
            zeroing: false,
            insufficient_material: false
end
