defmodule Chesstrainer.Endgames.Tablebase.Parser do
  @moduledoc """
  Fetch and parse tablebase data to fit the tablebase struct

  Lichess tablebase response from FEN string.
  https://lichess.org/api#tag/tablebase

  FEN must have spaces replaced by underscores to satisfy the Lichess API.
  """

  import Chesstrainer.Ratelimiters
  alias Chesstrainer.Endgames.Tablebase

  @lichess_tablebase_url "http://tablebase.lichess.ovh/standard?fen="

  @spec from_fen(String.t()) ::
          {:ok, Tablebase.t()} | {:cooldown, non_neg_integer()} | {:error, term()}
  def from_fen(fen) do
    case lichess_check_cooldown() do
      {:ok, 0} -> tablebase_response(fen)
      {:cooldown, remaining_ms} -> {:cooldown, remaining_ms}
    end
  end

  @spec tablebase_response(String.t()) :: {:ok, Tablebase.t()} | {:error, term()}
  defp tablebase_response(fen) do
    response =
      fen
      |> sanitise_fen()
      |> build_request_string()
      |> Req.get()
      |> parse_response()

    case response do
      {:ok, body} -> from_map(body)
      {:error, reason} -> {:error, reason}
    end
  end

  # exposed for testing
  def from_map(map) do
    {:ok,
     %Tablebase{
       category: map["category"] |> String.to_atom(),
       checkmate: map["checkmate"],
       dtc: map["dtc"],
       dtm: map["dtm"],
       dtw: map["dtw"],
       dtz: map["dtz"],
       insufficient_material: map["insufficient_material"],
       moves: Enum.map(map["moves"], &moves_from_map/1)
     }}
  end

  defp moves_from_map(map) do
    %Tablebase.Move{
      category: map["category"] |> String.to_atom(),
      checkmate: map["checkmate"],
      conversion: map["conversion"],
      dtc: map["dtc"],
      dtm: map["dtm"],
      dtw: map["dtw"],
      dtz: map["dtz"],
      insufficient_material: map["insufficient_material"],
      precise_dtz: map["precise_dtz"],
      san: map["san"],
      stalemate: map["stalemate"],
      uci: map["uci"],
      variant_loss: map["variant_loss"],
      variant_win: map["variant_win"],
      zeroing: map["zeroing"]
    }
  end

  defp parse_response(response) do
    case response do
      # Success
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      # Client errors
      {:ok, %Req.Response{status: status, body: body}} when status in 400..499 ->
        {:error, {:client_error, status, body}}

      # Rate limiting
      {:ok, %Req.Response{status: 429, body: body}} ->
        lichess_add_cooldown()
        {:error, {:too_many_requests, 429, body}}

      # Server errors
      {:ok, %Req.Response{status: status, body: body}} when status in 500..599 ->
        {:error, {:server_error, status, body}}

      # Catch‑all for other status codes
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      # Network / client‑side failure
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sanitise_fen(fen), do: String.replace(fen, " ", "_")
  defp build_request_string(fen), do: "#{@lichess_tablebase_url}#{fen}"
end
