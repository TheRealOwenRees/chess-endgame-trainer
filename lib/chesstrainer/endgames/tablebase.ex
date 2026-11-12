defmodule Chesstrainer.Endgames.Tablebase do
  @moduledoc """
  All endgame tablebase related functions.

  Lookups are routed by piece count through `Tablebase.Router`, which picks the
  backend that can answer the position.

  The cached value carries only what the trainer reads: `category`,
  `checkmate`, and `moves`. Cursed-win/blessed-loss are normalised to `:draw` at
  parse time, and distance fields (`dtm`/`dtc`/`dtw`) are not kept because the
  local Syzygy backend cannot produce them.
  """

  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Backend.Fathom, as: FathomBackend
  alias Chesstrainer.FEN

  @type result :: :win | :draw | :loss | :unknown

  @type t :: %__MODULE__{
          category: result,
          checkmate: boolean(),
          moves: [Tablebase.Move.t()]
        }

  defstruct category: nil,
            checkmate: false,
            moves: nil

  @doc """
  Normalises a Lichess tablebase category string into a trainer result.

  `cursed-win` and `blessed-loss` are wins/losses only when the 50-move rule is
  ignored, so they are draws in play. Unrecognised values become `:unknown`
  rather than minting arbitrary atoms.
  """
  @spec normalize_category(term()) :: result()
  def normalize_category(category) when category in ["win", "syzygy-win", "maybe-win"], do: :win

  def normalize_category(category) when category in ["draw", "cursed-win", "blessed-loss"],
    do: :draw

  def normalize_category(category) when category in ["loss", "syzygy-loss", "maybe-loss"],
    do: :loss

  def normalize_category(_category), do: :unknown

  @doc """
  Normalises a Fathom WDL atom into a trainer result.

  Like `normalize_category/1`, cursed-win and blessed-loss are draws because the
  50-move rule prevents the decisive result.
  """
  @spec normalize_wdl(atom()) :: result()
  def normalize_wdl(:win), do: :win
  def normalize_wdl(:cursed_win), do: :draw
  def normalize_wdl(:draw), do: :draw
  def normalize_wdl(:blessed_loss), do: :draw
  def normalize_wdl(:loss), do: :loss
  def normalize_wdl(_wdl), do: :unknown

  @doc """
  Flips an outcome to the other side's perspective.
  """
  @spec flip(atom()) :: result()
  def flip(:win), do: :loss
  def flip(:loss), do: :win
  def flip(:draw), do: :draw
  def flip(_outcome), do: :unknown

  @doc """
  Probes a FEN using only the local Syzygy tablebase and returns the result
  from the side-to-move's perspective.

  Unlike `new/1` this never falls back to the remote backend and never reads or
  writes the cache. It is the primitive behind the admin bulk importer, so an
  imported result always comes from our own tablebases.
  """
  @spec probe_local_result(String.t()) ::
          {:ok, result()}
          | {:error, :not_configured | :illegal | :terminal | :unsupported}
  def probe_local_result(fen), do: FathomBackend.probe_result_local(fen)

  @spec new(String.t()) ::
          {:ok, t()}
          | {:cooldown, non_neg_integer()}
          | {:error, :invalid_endgame}
          | {:error, term()}
  def new(fen) do
    key = FEN.position_key(fen)

    case Tablebase.Cache.get(key) do
      {:ok, tablebase} ->
        {:ok, tablebase}

      _ ->
        case Tablebase.Router.probe(fen) do
          {:error, reason} ->
            {:error, reason}

          {:cooldown, remaining_ms} ->
            {:cooldown, remaining_ms}

          {:ok, tablebase} when tablebase.category == :unknown ->
            {:error, :invalid_endgame}

          {:ok, tablebase} ->
            # Local probes are cheap; only remote (Lichess) answers are cached.
            if Tablebase.Router.remote?(fen), do: Tablebase.Cache.put(key, tablebase)
            {:ok, tablebase}
        end
    end
  end
end
