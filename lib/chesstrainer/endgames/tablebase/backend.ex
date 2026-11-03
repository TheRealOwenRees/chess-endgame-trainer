defmodule Chesstrainer.Endgames.Tablebase.Backend do
  @moduledoc """
  A backend answers a tablebase probe for one position.

  The router chooses a backend by piece count, so the play flow never depends on
  which one answered. Every backend returns the same shape.
  """

  alias Chesstrainer.Endgames.Tablebase

  @type result ::
          {:ok, Tablebase.t()}
          | {:cooldown, non_neg_integer()}
          | {:error, term()}

  @callback probe(String.t()) :: result()
end
