defmodule Chesstrainer.Endgames.Tablebase.Fathom do
  @moduledoc """
  Low-level NIF wrapper around [Fathom](https://github.com/jdart1/Fathom), a
  Syzygy tablebase prober.

  `init/1` points Fathom at a directory of `.rtbw`/`.rtbz` files and returns the
  largest piece count it found. `probe/1` returns the raw probe result for a
  FEN. Probes are serialised inside the NIF because Fathom's root probe keeps
  global state and is not thread safe.

  This module is the probe primitive: mapping the raw result onto
  `Chesstrainer.Endgames.Tablebase` is the backend's job.
  """

  use Rustler, otp_app: :chesstrainer, crate: :fathom_nif

  @typedoc "An encoded move: `{wdl, from, to, promotes, ep, dtz}`."
  @type move ::
          {atom(), non_neg_integer(), non_neg_integer(), non_neg_integer(), 0 | 1,
           non_neg_integer()}

  @typedoc "The root result: an outcome atom or a move tuple."
  @type root :: :checkmate | :stalemate | :failed | move()

  @doc """
  Initialises Fathom against a tablebase directory.

  Returns the largest piece count available, or `0` when no files were found.
  """
  @spec init(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def init(_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Probes a FEN and returns `{:ok, {root, moves}}`.
  """
  @spec probe(String.t()) :: {:ok, {root(), [move()]}} | {:error, String.t()}
  def probe(_fen), do: :erlang.nif_error(:nif_not_loaded)
end
