defmodule ChesstrainerWeb.EndgameLive.PlayerIndex do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Endgames
        <:subtitle>Pick an endgame to play.</:subtitle>
      </.header>

      <.table
        id="player-endgames"
        rows={@streams.endgames}
      >
        <:col :let={{_id, endgame}} label="Key">{endgame.key}</:col>
        <:col :let={{_id, endgame}} label="Color">{endgame.color}</:col>
        <:col :let={{_id, endgame}} label="Result">{endgame.result}</:col>
        <:col :let={{_id, endgame}} label="Rating">{endgame.rating}</:col>
        <:action :let={{_id, endgame}}>
          <.link navigate={~p"/endgames/#{endgame}/play"}>Play</.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Endgames")
     |> stream(:endgames, Endgames.list_endgames())}
  end
end
