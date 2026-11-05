defmodule ChesstrainerWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use ChesstrainerWeb, :html

  embed_templates "page_html/*"

  defp play_path(nil), do: ~p"/endgames"
  defp play_path(%{public_code: public_code}), do: ~p"/endgames/#{public_code}/play"
end
