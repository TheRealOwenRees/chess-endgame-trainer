defmodule ChesstrainerWeb.EndgameLive.Show do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.Game

  import ChesstrainerWeb.Board.BoardComponent

  @impl true
  def render(assigns) do
    game =
      case Game.game_from_fen(assigns.endgame.fen, :endgame) do
        {:ok, g} -> g
        {:error, :invalid_fen, g} -> g
      end

    # TODO once we return {:error, :invalid_fen, game}, then put flash to show it is invalid
    # write tests for this

    assigns =
      assigns
      |> assign(:game, game)
      |> assign(:game_type, :endgame)

    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Endgame {@endgame.id}
        <:subtitle>This is a endgame record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/endgames"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/endgames/#{@endgame}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit endgame
          </.button>
        </:actions>
      </.header>

      <.board game={@game} myself="board" />

      <.list>
        <:item title="Fen">{@endgame.fen}</:item>
        <:item title="Key">{@endgame.key}</:item>
        <:item title="Color">{@endgame.color}</:item>
        <:item title="Rating">{@endgame.rating}</:item>
        <:item title="Message">{@endgame.message}</:item>
        <:item title="Notes">{@endgame.notes}</:item>
        <:item title="Result">{@endgame.result}</:item>
        <:item title="Attempted">{@endgame.times_attempted}</:item>
        <:item title="Solved">{@endgame.times_solved}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Endgame")
     |> assign(:endgame, Endgames.get_endgame!(id))}
  end
end
