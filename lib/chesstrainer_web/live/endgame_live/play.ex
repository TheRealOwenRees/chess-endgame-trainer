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
          {@endgame.color |> Atom.to_string() |> String.capitalize()} to move · Rating: {@endgame.rating}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/endgames"}>
            <.icon name="hero-arrow-left" /> Back to endgames
          </.button>
        </:actions>
      </.header>

      <div class="flex gap-2 bg-gray-200 p-4 rounded-xl shadow-inner">
        <div
          id="endgame-board"
          phx-hook="ChessBoard"
          phx-update="ignore"
          data-endgame-id={@endgame.id}
          class="w-100 h-100"
        >
        </div>

        <div class="w-48 h-100 flex flex-col gap-3">
          <div class="flex-1 min-h-0 flex flex-col bg-white rounded-lg p-3">
            <p class="text-sm text-gray-600 font-semibold mb-2">Moves:</p>
            <div class="flex-1 overflow-y-auto">
              <%= if @move_list == [] do %>
                <p class="text-sm text-gray-500">No Moves</p>
              <% else %>
                <%= for {[white_move, black_move], i} <- format_move_pairs(@move_list, @endgame.color) do %>
                  <div class="font-mono text-sm leading-6">
                    <span class="text-gray-500 mr-2">{i}.</span>
                    <span class="text-gray-900">{white_move || "..."}</span>
                    <%= if black_move do %>
                      <span class="text-gray-900 ml-2">{black_move}</span>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <div>Buttons</div>

          <div>
            <.button phx-click="reset" variant="primary">
              <.icon name="hero-arrow-path" /> Reset
            </.button>
          </div>
        </div>
      </div>
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
     |> assign(:move_list, socket.assigns.move_list ++ [san])}
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

  def format_move_pairs(move_list, color) do
    moves = if color in [:black, "black"], do: [nil | move_list], else: move_list

    moves
    |> Enum.chunk_every(2, 2, [nil])
    |> Enum.with_index(1)
  end
end
