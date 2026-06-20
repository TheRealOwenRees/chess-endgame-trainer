defmodule ChesstrainerWeb.ChessTestLive do
  use ChesstrainerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, last_move: "None yet", total_moves: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl p-6">
      <h1 class="text-2xl font-bold mb-4">Chessground LiveView Test</h1>

      <div class="bg-gray-100 p-4 rounded mb-4 flex justify-between items-center shadow-sm">
        <div>
          <p class="text-sm text-gray-600 font-semibold">Last Played Move:</p>
          <p class="text-lg font-mono text-blue-600">{@last_move}</p>
        </div>
        <div>
          <p class="text-sm text-gray-600 font-semibold">Total Moves:</p>
          <p class="text-lg font-bold">{@total_moves}</p>
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
  def handle_event("move_played", %{"from" => from, "to" => to, "fen" => _fen}, socket) do
    # Receive the payload sent from the client JS Hook via this.pushEvent
    {:noreply,
     socket
     |> assign(:last_move, "#{from} ➔ #{to}")
     |> assign(:total_moves, socket.assigns.total_moves + 1)}
  end
end
