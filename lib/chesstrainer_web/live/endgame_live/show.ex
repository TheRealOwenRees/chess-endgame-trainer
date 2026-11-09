defmodule ChesstrainerWeb.EndgameLive.Show do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.Game
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

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
    <Layouts.app flash={@flash} wide>
      <.header>
        Endgame {@endgame.id}
        <:subtitle>This is a endgame record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/endgames"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/endgames/#{@endgame.public_code}/play"}>
            <.icon name="hero-play" /> Play (opens trainer)
          </.button>
          <.button variant="primary" navigate={~p"/admin/endgames/#{@endgame.id}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit endgame
          </.button>
        </:actions>
      </.header>

      <.board game={@game} myself="board" interactive={false} />

      <.list>
        <:item title="Fen">{@endgame.fen}</:item>
        <:item title="Key">{@endgame.key}</:item>
        <:item title="Public code">
          <span id="public-code" class="select-all">{@endgame.public_code}</span>
          <button
            id="copy-public-code"
            type="button"
            phx-hook=".CopyPublicCode"
            data-code={@endgame.public_code}
            class="ml-2 inline-flex cursor-pointer items-center justify-center rounded p-1.5"
            title="Copy public code"
            aria-label="Copy public code to clipboard"
          >
            <.icon name="hero-document-duplicate" class="w-3.5 h-3.5" />
          </button>
        </:item>
        <:item title="Color">{@endgame.color}</:item>
        <:item title="Rating">{round(@endgame.rating)}</:item>
        <:item title="Message">{@endgame.message}</:item>
        <:item title="Notes">{@endgame.notes}</:item>
        <:item title="Result">{@endgame.result}</:item>
        <:item title="Themes">{Enum.join(Themes.names(@endgame.themes), ", ")}</:item>
        <:item title="Attempted">{@endgame.times_attempted}</:item>
        <:item title="Solved">{@endgame.times_solved}</:item>
      </.list>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyPublicCode">
        export default {
          mounted() {
            this.el.addEventListener("click", () => {
              navigator.clipboard.writeText(this.el.dataset.code)
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Endgame")
     |> assign(:endgame, Endgames.get_endgame!(id) |> Repo.preload(:themes))}
  end
end
