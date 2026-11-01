defmodule ChesstrainerWeb.EndgameLive.Play do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase

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
          <div class="rounded-lg bg-white p-3 text-sm">
            <%= cond do %>
              <% @status == :loading -> %>
                <p class="text-gray-500">Loading tablebase…</p>
              <% @status == :blocked -> %>
                <p class="font-semibold text-red-600">Tablebase unavailable</p>
                <p class="text-red-500">{@blocked_reason}</p>
              <% @awaiting_reply -> %>
                <p class="text-gray-500">Opponent is replying…</p>
              <% @last_grade == :optimal -> %>
                <p class="font-semibold text-emerald-600">Optimal move</p>
              <% @last_grade == :winning -> %>
                <p class="font-semibold text-amber-600">Winning — but not the sharpest</p>
              <% @last_grade == :losing -> %>
                <p class="font-semibold text-red-600">Losing move — this throws away the win</p>
              <% @last_grade == :unknown -> %>
                <p class="font-semibold text-gray-600">Could not grade that move</p>
              <% true -> %>
                <p class="text-gray-500">Make a move to have it graded.</p>
            <% end %>
          </div>

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
      |> assign(:fen, endgame.fen)
      |> assign(:tablebase, nil)
      |> assign(:status, :loading)
      |> assign(:blocked_reason, nil)
      |> assign(:move_list, [])
      |> assign(:last_san, "None yet")
      |> assign(:last_from_to, "None yet")
      |> assign(:last_grade, nil)
      |> assign(:awaiting_reply, false)

    {:ok, load_attempt(socket)}
  end

  @impl true
  def handle_event("endgame_move_played", params, socket) do
    %{"from" => from, "to" => to, "san" => san} = params
    promotion = params["promotion"]
    prev_fen = params["prev_fen"] || socket.assigns.fen
    fen_after = params["fen"] || socket.assigns.fen

    cond do
      socket.assigns.status != :playing ->
        {:noreply,
         put_flash(socket, :error, "The tablebase is unavailable, so this move cannot be graded.")}

      not same_position?(prev_fen, socket.assigns.fen) ->
        {:noreply,
         put_flash(socket, :error, "That move is out of sequence. Press Reset to try again.")}

      true ->
        grade_and_record(socket, from, to, promotion, san, fen_after)
    end
  end

  def handle_event("opponent_reply_applied", %{"fen" => fen}, socket) do
    if socket.assigns.awaiting_reply do
      case Tablebase.new(fen) do
        {:ok, tablebase} ->
          {:noreply,
           socket
           |> assign(:fen, fen)
           |> assign(:tablebase, tablebase)
           |> assign(:awaiting_reply, false)
           |> assign(:status, :playing)
           |> assign(:blocked_reason, nil)
           |> push_event("resume_board", %{})}

        other ->
          {:noreply,
           socket
           |> assign(:awaiting_reply, false)
           |> assign(:status, :blocked)
           |> assign(:blocked_reason, blocked_reason(other))}
      end
    else
      {:noreply, socket}
    end
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
    socket =
      socket
      |> assign(:move_list, [])
      |> assign(:last_san, "None yet")
      |> assign(:last_from_to, "None yet")
      |> assign(:last_grade, nil)

    {:noreply, load_attempt(socket)}
  end

  def format_move_pairs(move_list, color) do
    moves = if color in [:black, "black"], do: [nil | move_list], else: move_list

    moves
    |> Enum.chunk_every(2, 2, [nil])
    |> Enum.with_index(1)
  end

  defp load_attempt(socket) do
    fen = socket.assigns.endgame.fen
    socket = socket |> assign(:fen, fen) |> assign(:awaiting_reply, false)

    if connected?(socket) do
      case Tablebase.new(fen) do
        {:ok, tablebase} ->
          socket
          |> assign(:tablebase, tablebase)
          |> assign(:status, :playing)
          |> assign(:blocked_reason, nil)
          |> push_init_board(fen)

        other ->
          socket
          |> assign(:tablebase, nil)
          |> assign(:status, :blocked)
          |> assign(:blocked_reason, blocked_reason(other))
          |> push_init_board(fen)
      end
    else
      assign(socket, :status, :loading)
    end
  end

  defp push_init_board(socket, fen) do
    push_event(socket, "init_board", %{
      fen: fen,
      orientation: Atom.to_string(socket.assigns.endgame.color),
      player_color: Atom.to_string(socket.assigns.endgame.color),
      blocked: socket.assigns.status == :blocked
    })
  end

  defp blocked_reason({:cooldown, remaining_ms}) do
    seconds = max(div(remaining_ms + 999, 1000), 1)
    "The tablebase is rate-limited. Try again in about #{seconds}s."
  end

  defp blocked_reason({:error, {:too_many_requests, _, _}}) do
    "The tablebase is rate-limited. Try again in a minute."
  end

  defp blocked_reason({:error, {:client_error, 404, _}}) do
    "This position is not covered by the tablebase."
  end

  defp blocked_reason({:error, reason}) do
    "The tablebase is unavailable (#{inspect(reason)})."
  end

  defp grade_and_record(socket, from, to, promotion, san, fen_after) do
    case find_move(socket.assigns.tablebase, from, to, promotion) do
      nil ->
        {:noreply, put_flash(socket, :error, "Could not identify that move in the tablebase.")}

      move ->
        grade = grade_move(socket.assigns.tablebase, move)

        socket =
          socket
          |> assign(:last_from_to, "#{from} ➔ #{to}")
          |> assign(:last_san, san)
          |> assign(:last_grade, grade)
          |> assign(:move_list, socket.assigns.move_list ++ [san])

        if grade in [:optimal, :winning] and
             not same_position?(fen_after, socket.assigns.fen) do
          start_opponent_reply(socket, fen_after)
        else
          {:noreply, socket}
        end
    end
  end

  defp start_opponent_reply(socket, fen_after) do
    case Tablebase.new(fen_after) do
      {:ok, %Tablebase{moves: [reply | _]}} ->
        {:noreply,
         socket
         |> assign(:awaiting_reply, true)
         |> push_event("opponent_move", reply_payload(reply))}

      {:ok, %Tablebase{moves: []}} ->
        # Terminal position (checkmate/stalemate): there is no reply to play.
        {:noreply, socket}

      other ->
        {:noreply,
         socket
         |> assign(:status, :blocked)
         |> assign(:blocked_reason, blocked_reason(other))}
    end
  end

  defp reply_payload(%Tablebase.Move{uci: uci, san: san}) do
    %{
      from: String.slice(uci, 0, 2),
      to: String.slice(uci, 2, 2),
      promotion: String.at(uci, 4),
      san: san
    }
  end

  defp find_move(%Tablebase{moves: moves}, from, to, promotion) when is_list(moves) do
    uci = "#{from}#{to}#{promotion || ""}"
    Enum.find(moves, &(&1.uci == uci))
  end

  defp find_move(_tablebase, _from, _to, _promotion), do: nil

  # Compare only the board and side to move: chess.js may normalise the rest
  # (castling/en-passant/halfmove/fullmove) differently from the stored FEN.
  defp same_position?(fen_a, fen_b), do: position_key(fen_a) == position_key(fen_b)

  defp position_key(fen) do
    case String.split(fen, " ") do
      [board, active | _] -> {board, active}
      _ -> fen
    end
  end

  defp grade_move(%Tablebase{moves: []}, _move), do: :unknown

  defp grade_move(%Tablebase{category: position_category, moves: [best | _]}, move) do
    best_rank = outcome_rank(position_category)
    move_rank = outcome_rank(mover_outcome(move.category))

    cond do
      is_nil(best_rank) or is_nil(move_rank) -> :unknown
      move_rank < best_rank -> :losing
      move.dtz == best.dtz -> :optimal
      true -> :winning
    end
  end

  # The mover's outcome is the flip of `category`, which is reported from the
  # perspective of the side to move *after* the move.
  defp mover_outcome(:loss), do: :win
  defp mover_outcome(:win), do: :loss
  defp mover_outcome(:draw), do: :draw
  defp mover_outcome(_), do: :unknown

  defp outcome_rank(:win), do: 2
  defp outcome_rank(:draw), do: 1
  defp outcome_rank(:loss), do: 0
  defp outcome_rank(_), do: nil
end
