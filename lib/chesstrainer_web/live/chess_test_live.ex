defmodule ChesstrainerWeb.ChessTestLive do
  use ChesstrainerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, last_move: "None yet", san: "None yet", move_list: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl p-6">
      <h1 class="text-2xl font-bold mb-4">Chessground LiveView Test</h1>

      <form phx-submit="load_fen" class="mb-6 flex gap-2 bg-gray-50 p-4 rounded-lg shadow-sm">
        <div class="flex-1">
          <input
            type="text"
            name="fen"
            placeholder="Paste FEN string here (e.g., rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1)"
            class="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
            required
          />
        </div>
        <button
          type="submit"
          class="px-4 py-2 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 transition"
        >
          Load FEN
        </button>
      </form>

      <div class="bg-gray-100 p-4 rounded mb-4 flex justify-between items-center shadow-sm">
        <div>
          <p class="text-sm text-gray-600 font-semibold">Last Played Move:</p>
          <p class="text-lg font-mono text-blue-600">{@last_move}</p>
          <p class="text-lg font-mono text-blue-600">{@san}</p>
          <p class="text-lg font-mono text-emerald-600">
            {if length(@move_list) == 0 do
              "No Moves"
            else
              Enum.reverse(@move_list) |> Enum.join(", ")
            end}
          </p>
        </div>
      </div>

      <div class="flex justify-center bg-gray-200 p-4 rounded-xl shadow-inner">
        <div
          id="chessground-board"
          phx-hook="ChessBoard"
          phx-update="ignore"
          class="w-[400px] h-[400px]"
        >
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("load_fen", %{"fen" => fen}, socket) do
    clean_fen = String.trim(fen)

    {:noreply,
     socket
     |> assign(:last_move, "Position Loaded")
     |> assign(:san, "None yet")
     |> assign(:move_list, [])
     |> push_event("set_fen", %{fen: clean_fen})}
  end

  @impl true
  def handle_event(
        "move_played",
        %{"from" => from, "to" => to, "fen" => _fen, "san" => san},
        socket
      ) do
    current_moves = socket.assigns.move_list

    {:noreply,
     socket
     |> assign(:last_move, "#{from} ➔ #{to}")
     |> assign(:san, san)
     |> assign(:move_list, [san | current_moves])}
  end
end
