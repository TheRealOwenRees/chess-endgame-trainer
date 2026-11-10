defmodule Chesstrainer.Endgames.Tablebase.Parser do
  @moduledoc """
  Fetch and parse tablebase data to fit the tablebase struct

  Lichess tablebase response from FEN string.
  https://lichess.org/api#tag/tablebase

  FEN must have spaces replaced by underscores to satisfy the Lichess API.
  """

  import Chesstrainer.Ratelimiters
  alias Chesstrainer.Endgames.Tablebase

  require Logger

  @lichess_tablebase_url "https://tablebase.lichess.ovh/standard?fen="

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
       category: Tablebase.normalize_category(map["category"]),
       checkmate: map["checkmate"],
       moves: Enum.map(map["moves"], &moves_from_map/1)
     }}
  end

  defp moves_from_map(map) do
    %Tablebase.Move{
      category: Tablebase.normalize_category(map["category"]),
      dtz: map["dtz"],
      san: map["san"],
      uci: map["uci"]
    }
  end

  # exposed for testing
  def parse_response(response) do
    case response do
      # Success
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      # Rate limiting (must precede the generic 4xx clause, or 429 is swallowed)
      {:ok, %Req.Response{status: 429, body: body}} ->
        lichess_add_cooldown()
        {:error, {:too_many_requests, 429, body}}

      # Client errors
      {:ok, %Req.Response{status: status, body: body}} when status in 400..499 ->
        {:error, {:client_error, status, body}}

      # Server errors
      {:ok, %Req.Response{status: status, body: body}} when status in 500..599 ->
        Logger.warning("tablebase fetch failed with HTTP #{status}", status: status)
        {:error, {:server_error, status, body}}

      # Catch‑all for other status codes
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      # Network / client‑side failure
      {:error, reason} ->
        Logger.warning("tablebase fetch failed: #{inspect(reason)}", reason: reason)
        {:error, reason}
    end
  end

  defp sanitise_fen(fen), do: String.replace(fen, " ", "_")
  defp build_request_string(fen), do: "#{@lichess_tablebase_url}#{fen}"
end
