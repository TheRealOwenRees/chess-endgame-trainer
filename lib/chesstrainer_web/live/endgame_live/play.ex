defmodule ChesstrainerWeb.EndgameLive.Play do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Play endgame {@endgame.key}
        <:subtitle>
          {@endgame.color} to move · Result: {@endgame.result} · Rating: {@endgame.rating}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/endgames"}>
            <.icon name="hero-arrow-left" /> Back to endgames
          </.button>
        </:actions>
      </.header>

      <div class="bg-gray-100 p-4 rounded mb-4 flex justify-between items-center shadow-sm">
        <div>
          <p class="text-sm text-gray-600 font-semibold">Last Played Move:</p>
          <p class="text-lg font-mono text-blue-600">{@last_from_to}</p>
          <p class="text-lg font-mono text-blue-600">{@last_san}</p>
          <p class="text-lg font-mono text-emerald-600">
            {if @move_list == [] do
              "No Moves"
            else
              Enum.reverse(@move_list) |> Enum.join(", ")
            end}
          </p>
        </div>
        <div>
          <.button phx-click="reset" variant="primary">
            <.icon name="hero-arrow-path" /> Reset
          </.button>
        </div>
      </div>

      <div class="flex justify-center bg-gray-200 p-4 rounded-xl shadow-inner">
        <div
          id="endgame-board"
          phx-hook="ChessBoard"
          phx-update="ignore"
          data-endgame-id={@endgame.id}
          class="w-[400px] h-[400px]"
        >
        </div>
      </div>

      <.list>
        <:item title="Fen">{@endgame.fen}</:item>
        <:item title="Key">{@endgame.key}</:item>
        <:item title="Color">{@endgame.color}</:item>
        <:item title="Result">{@endgame.result}</:item>
        <:item title="Rating">{@endgame.rating}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    endgame = Endgames.get_endgame!(id)

    socket =
      socket
      |> assign(:page_title, "Play endgame")
      |> assign(:endgame, endgame)
      |> assign(:move_list, [])
      |> assign(:last_san, "None yet")
      |> assign(:last_from_to, "None yet")
      |> push_event("init_board", %{
        fen: endgame.fen,
        orientation: Atom.to_string(endgame.color),
        player_color: Atom.to_string(endgame.color)
      })

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "endgame_move_played",
        %{"from" => from, "to" => to, "san" => san},
        socket
      ) do
    # TODO: server-side legality check + tablebase evaluation when wired
    {:noreply,
     socket
     |> assign(:last_from_to, "#{from} ➔ #{to}")
     |> assign(:last_san, san)
     |> assign(:move_list, [san | socket.assigns.move_list])}
  end

  def handle_event("chess_fen_invalid", %{"fen" => fen, "message" => message}, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Endgame FEN is invalid and the board cannot be loaded: #{message} (#{fen})"
     )}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:move_list, [])
     |> assign(:last_san, "None yet")
     |> assign(:last_from_to, "None yet")
     |> push_event("init_board", %{
       fen: socket.assigns.endgame.fen,
       orientation: Atom.to_string(socket.assigns.endgame.color),
       player_color: Atom.to_string(socket.assigns.endgame.color)
     })}
  end
end
