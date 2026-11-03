defmodule ChesstrainerWeb.EndgameLive.Play do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Attempts
  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Ratings

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Play endgame {@endgame.key}
        <:subtitle>
          {@endgame.color |> Atom.to_string() |> String.capitalize()} to move · Rating: {round(
            @endgame.rating
          )} · Attempts: {@endgame.times_attempted ||
            0} · Solved: {@endgame.times_solved || 0}<span :if={@user_rating}> · Your rating: {round(
            @user_rating
          )}</span>
          <p class="text-xs text-gray-500 flex items-center mt-1">
            <span>FEN: {@endgame.fen}</span>
            <button
              id="copy-fen-btn"
              phx-hook="CopyFen"
              data-fen={@endgame.fen}
              class="inline-flex items-center cursor-pointer"
              title="Copy FEN to clipboard"
            >
              <.icon name="hero-document-duplicate" class="w-3.5 h-3.5" />
            </button>
          </p>
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
              <% @status == :solved -> %>
                <p class="font-semibold text-emerald-600">
                  {if @endgame.result == :draw, do: "Draw held!", else: "Solved!"}
                </p>
              <% @status == :failed -> %>
                <p class="font-semibold text-red-600">Failed</p>
                <p class="text-red-500">
                  {if @endgame.result == :draw,
                    do: "That move loses the draw.",
                    else: "That move throws away the win."}
                </p>
                <%= if @best_move && @plies != [] do %>
                  <p class="text-gray-600">
                    You played {List.last(@plies).san}; best was: {@best_move}
                  </p>
                <% end %>
              <% @awaiting_reply -> %>
                <p class="text-gray-500">Opponent is replying…</p>
              <% @last_grade == :optimal -> %>
                <p class="font-semibold text-emerald-600">Optimal move</p>
              <% @last_grade == :winning -> %>
                <p class="font-semibold text-amber-600">
                  {if @endgame.result == :draw,
                    do: "Keeps the draw — but not the sharpest",
                    else: "Winning — but not the sharpest"}
                </p>
              <% @last_grade == :losing -> %>
                <p class="font-semibold text-red-600">
                  {if @endgame.result == :draw,
                    do: "Losing move — this loses the draw",
                    else: "Losing move — this throws away the win"}
                </p>
              <% @last_grade == :unknown -> %>
                <p class="font-semibold text-gray-600">Could not grade that move</p>
              <% true -> %>
                <p class="text-gray-500">Make a move to have it graded.</p>
            <% end %>
          </div>

          <div :if={@reviewing} id="best-move-panel" class="rounded-lg bg-white p-3 text-sm">
            <%= cond do %>
              <% @review_blocked -> %>
                <p class="text-gray-500">Best move unavailable here</p>
                <p class="text-gray-400">{@review_blocked}</p>
              <% @review_tablebase -> %>
                <p class="text-gray-600 font-semibold mb-1">Best move:</p>
                <p class="text-emerald-600">{best_move_text(@review_tablebase) || "—"}</p>
                <%= if played_ply = played_ply_at(@line, @review_index) do %>
                  <p class={["mt-1", grade_class(played_ply.grade)]}>Played: {played_ply.san}</p>
                <% end %>
              <% true -> %>
                <p class="text-gray-500">No best move.</p>
            <% end %>
          </div>

          <div id="move-list" class="flex-1 min-h-0 flex flex-col bg-white rounded-lg p-3">
            <% plies = display_plies(@reviewing, @line, @plies) %>
            <p class="text-sm text-gray-600 font-semibold mb-2">Moves:</p>
            <div class="flex-1 overflow-y-auto">
              <%= if plies == [] do %>
                <p class="text-sm text-gray-500">No Moves</p>
              <% else %>
                <%= for {[white_ply, black_ply], move_no} <- move_rows(plies, @endgame.color) do %>
                  <div class="font-mono text-sm leading-6">
                    <span class="text-gray-500 mr-2">{move_no}.</span>
                    <%= if white_ply do %>
                      <.ply
                        ply={white_ply}
                        reviewing={@reviewing}
                        review_index={@review_index}
                        result={@endgame.result}
                      />
                    <% else %>
                      <span class="text-gray-900">...</span>
                    <% end %>
                    <%= if black_ply do %>
                      <.ply
                        ply={black_ply}
                        reviewing={@reviewing}
                        review_index={@review_index}
                        result={@endgame.result}
                      />
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <div class="flex gap-2">
            <.button
              :if={@status in [:solved, :failed] and not @reviewing}
              phx-click="review"
            >
              <.icon name="hero-eye" /> Review
            </.button>
            <.button phx-click="reset" variant="primary">
              <.icon name="hero-arrow-path" />
              {if @status in [:solved, :failed], do: "Try again", else: "Reset"}
            </.button>
          </div>

          <div :if={@reviewing} id="review-controls" class="flex flex-wrap gap-2">
            <.button phx-click="review_prev" disabled={@review_index <= 0}>←</.button>
            <.button phx-click="review_next" disabled={@review_index >= length(@line)}>→</.button>
            <.button
              :if={@review_tablebase && best_move_text(@review_tablebase)}
              phx-click="play_best_line"
              disabled={@awaiting_best_line}
            >
              Play best line
            </.button>
            <.button :if={@line != @plies} phx-click="back_to_game">Back to game</.button>
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
      |> assign(:user_rating, user_rating(socket.assigns.current_scope))
      |> assign(:fen, endgame.fen)
      |> assign(:tablebase, nil)
      |> assign(:status, :loading)
      |> assign(:blocked_reason, nil)
      |> assign(:best_move, nil)
      |> assign(:plies, [])
      |> assign(:reviewing, false)
      |> assign(:review_index, 0)
      |> assign(:pending_reply, nil)
      |> assign(:snapshots, %{})
      |> assign(:line, [])
      |> assign(:review_tablebase, nil)
      |> assign(:review_blocked, nil)
      |> assign(:awaiting_best_line, false)
      |> assign(:pending_best_move, nil)
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
    draw = params["draw"] || false
    prev_fen = params["prev_fen"] || socket.assigns.fen
    fen_after = params["fen"] || socket.assigns.fen

    cond do
      socket.assigns.status == :blocked ->
        {:noreply,
         put_flash(socket, :error, "The tablebase is unavailable, so this move cannot be graded.")}

      socket.assigns.status != :playing ->
        {:noreply, socket}

      not same_position?(prev_fen, socket.assigns.fen) ->
        {:noreply,
         put_flash(socket, :error, "That move is out of sequence. Press Reset to try again.")}

      true ->
        grade_and_record(socket, from, to, promotion, san, fen_after, draw)
    end
  end

  def handle_event("opponent_reply_applied", params, socket) do
    %{"fen" => fen} = params
    draw = params["draw"] || false

    cond do
      not socket.assigns.awaiting_reply ->
        {:noreply, socket}

      true ->
        socket = record_opponent_ply(socket, fen, params["san"])

        if draw and socket.assigns.endgame.result == :draw do
          solve_attempt(socket)
        else
          case Tablebase.new(fen) do
            {:ok, tablebase} ->
              {:noreply,
               socket
               |> assign(:fen, fen)
               |> assign(:tablebase, tablebase)
               |> snapshot(fen, tablebase)
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
        end
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
      |> assign(:plies, [])
      |> assign(:reviewing, false)
      |> assign(:review_index, 0)
      |> assign(:pending_reply, nil)
      |> assign(:snapshots, %{})
      |> assign(:line, [])
      |> assign(:review_tablebase, nil)
      |> assign(:review_blocked, nil)
      |> assign(:awaiting_best_line, false)
      |> assign(:pending_best_move, nil)
      |> assign(:last_san, "None yet")
      |> assign(:last_from_to, "None yet")
      |> assign(:last_grade, nil)

    {:noreply, load_attempt(socket)}
  end

  def handle_event("review", _params, socket) do
    if socket.assigns.status in [:solved, :failed] do
      socket =
        socket
        |> assign(:reviewing, true)
        |> assign(:line, socket.assigns.plies)
        |> set_review_index(length(socket.assigns.plies))

      {:noreply, push_review_position(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("review_prev", _params, socket), do: step_review(socket, -1)

  def handle_event("review_next", _params, socket), do: step_review(socket, 1)

  def handle_event("review_step", %{"index" => index}, socket) do
    if socket.assigns.reviewing do
      last = length(socket.assigns.line)
      index = parse_index(index) |> max(0) |> min(last)

      {:noreply, push_review_position(set_review_index(socket, index))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("play_best_line", _params, socket) do
    with true <- socket.assigns.reviewing,
         %Tablebase{} = tablebase <- socket.assigns.review_tablebase,
         %Tablebase.Move{} = move <- pick_best_move(tablebase) do
      # Branch the review line at the current position, then play one best move.
      {:noreply,
       socket
       |> assign(:line, Enum.take(socket.assigns.line, socket.assigns.review_index))
       |> assign(:awaiting_best_line, true)
       |> assign(:pending_best_move, move)
       |> push_event("best_line_move", reply_payload(move))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("best_line_move_applied", %{"fen" => fen}, socket) do
    if socket.assigns.awaiting_best_line do
      move = socket.assigns.pending_best_move

      line =
        socket.assigns.line ++
          [
            %{
              index: length(socket.assigns.line),
              san: move.san,
              fen_after: fen,
              grade: nil,
              best_line: true
            }
          ]

      socket =
        socket
        |> assign(:line, line)
        |> assign(:awaiting_best_line, false)
        |> assign(:pending_best_move, nil)
        |> set_review_index(length(line))

      {:noreply, push_review_position(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("back_to_game", _params, socket) do
    if socket.assigns.reviewing do
      socket =
        socket
        |> assign(:line, socket.assigns.plies)
        |> set_review_index(length(socket.assigns.plies))

      {:noreply, push_review_position(socket)}
    else
      {:noreply, socket}
    end
  end

  attr :ply, :map, required: true
  attr :reviewing, :boolean, required: true
  attr :review_index, :integer, required: true
  attr :result, :atom, required: true

  defp ply(assigns) do
    ~H"""
    <%= if @reviewing do %>
      <button
        type="button"
        phx-click="review_step"
        phx-value-index={@ply.index + 1}
        class={[
          "ml-2",
          ply_class(@ply),
          current_ply?(@ply, @review_index) && "underline"
        ]}
        title={ply_title(@ply, @result)}
        data-grade={@ply.grade}
      >
        {@ply.san}
      </button>
    <% else %>
      <span
        class={["ml-2", ply_class(@ply)]}
        title={ply_title(@ply, @result)}
        data-grade={@ply.grade}
      >
        {@ply.san}
      </span>
    <% end %>
    """
  end

  defp move_rows(plies, color) do
    padded = if color in [:black, "black"], do: [nil | plies], else: plies

    padded
    |> Enum.chunk_every(2, 2, [nil])
    |> Enum.with_index(1)
  end

  defp positions(start_fen, plies), do: [start_fen | Enum.map(plies, & &1.fen_after)]

  defp display_plies(true, line, _plies), do: line
  defp display_plies(false, _line, plies), do: plies

  defp push_review_position(socket) do
    fen =
      socket.assigns.endgame.fen
      |> positions(socket.assigns.line)
      |> Enum.at(socket.assigns.review_index)

    push_event(socket, "review_position", %{fen: fen})
  end

  defp set_review_index(socket, index) do
    socket
    |> assign(:review_index, index)
    |> update_review_tablebase()
  end

  defp update_review_tablebase(socket) do
    fen =
      socket.assigns.endgame.fen
      |> positions(socket.assigns.line)
      |> Enum.at(socket.assigns.review_index)

    case snapshot_or_fetch(socket, fen) do
      {:ok, tablebase, socket} ->
        assign(socket, review_tablebase: tablebase, review_blocked: nil)

      {:unavailable, reason, socket} ->
        assign(socket, review_tablebase: nil, review_blocked: reason)
    end
  end

  defp snapshot_or_fetch(socket, fen) do
    case Map.fetch(socket.assigns.snapshots, fen) do
      {:ok, tablebase} ->
        {:ok, tablebase, socket}

      :error ->
        case Tablebase.new(fen) do
          {:ok, tablebase} -> {:ok, tablebase, snapshot(socket, fen, tablebase)}
          other -> {:unavailable, blocked_reason(other), socket}
        end
    end
  end

  defp snapshot(socket, fen, tablebase) do
    assign(socket, :snapshots, Map.put(socket.assigns.snapshots, fen, tablebase))
  end

  defp step_review(socket, delta) do
    if socket.assigns.reviewing do
      last = length(socket.assigns.line)
      index = (socket.assigns.review_index + delta) |> max(0) |> min(last)

      {:noreply, socket |> set_review_index(index) |> push_review_position()}
    else
      {:noreply, socket}
    end
  end

  defp parse_index(index) when is_integer(index), do: index
  defp parse_index(index) when is_binary(index), do: String.to_integer(index)

  defp current_ply?(%{index: index}, review_index), do: index + 1 == review_index

  defp played_ply_at(line, review_index) do
    case Enum.at(line, review_index) do
      %{best_line: true} -> nil
      ply -> ply
    end
  end

  defp ply_class(%{best_line: true}), do: "text-sky-600 italic"
  defp ply_class(ply), do: grade_class(ply.grade)

  defp ply_title(%{best_line: true}, _result), do: "Best line"
  defp ply_title(ply, result), do: grade_label(ply.grade, result)

  defp grade_class(:optimal), do: "text-emerald-600"
  defp grade_class(:winning), do: "text-amber-600"
  defp grade_class(:losing), do: "text-red-600"
  defp grade_class(_), do: "text-gray-900"

  defp grade_label(nil, _result), do: nil
  defp grade_label(:optimal, _result), do: "Optimal move"
  defp grade_label(:winning, :draw), do: "Keeps the draw — but not the sharpest"
  defp grade_label(:winning, _result), do: "Winning — but not the sharpest"
  defp grade_label(:losing, :draw), do: "Loses the draw"
  defp grade_label(:losing, _result), do: "Throws away the win"
  defp grade_label(:unknown, _result), do: "Not graded"

  defp load_attempt(socket) do
    fen = socket.assigns.endgame.fen

    socket =
      socket
      |> assign(:fen, fen)
      |> assign(:awaiting_reply, false)
      |> assign(:best_move, nil)

    if connected?(socket) do
      case Tablebase.new(fen) do
        {:ok, tablebase} ->
          {:ok, endgame} = Endgames.record_attempt(socket.assigns.endgame)

          socket
          |> assign(:endgame, endgame)
          |> assign(:tablebase, tablebase)
          |> snapshot(fen, tablebase)
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

  defp blocked_reason({:error, :not_covered}) do
    "This position is not covered by the tablebase."
  end

  defp blocked_reason({:error, reason}) do
    "The tablebase is unavailable (#{inspect(reason)})."
  end

  defp grade_and_record(socket, from, to, promotion, san, fen_after, draw) do
    case find_move(socket.assigns.tablebase, from, to, promotion) do
      nil ->
        {:noreply, put_flash(socket, :error, "Could not identify that move in the tablebase.")}

      move ->
        grade = grade_move(socket.assigns.tablebase, move)

        ply = %{
          index: length(socket.assigns.plies),
          san: san,
          fen_after: fen_after,
          grade: grade
        }

        socket =
          socket
          |> assign(:last_from_to, "#{from} ➔ #{to}")
          |> assign(:last_san, san)
          |> assign(:last_grade, grade)
          |> assign(:plies, socket.assigns.plies ++ [ply])

        cond do
          grade == :losing ->
            fail_attempt(socket)

          grade not in [:optimal, :winning] ->
            {:noreply, socket}

          draw and socket.assigns.endgame.result == :draw ->
            # A drawn-by-rule position is the goal of a draw puzzle.
            solve_attempt(socket)

          socket.assigns.endgame.result == :win and not is_nil(promotion) ->
            # Conversion cutoff: a promotion that keeps the win ends a win puzzle.
            solve_attempt(socket)

          not same_position?(fen_after, socket.assigns.fen) ->
            start_opponent_reply(socket, fen_after)

          true ->
            {:noreply, socket}
        end
    end
  end

  defp start_opponent_reply(socket, fen_after) do
    case Tablebase.new(fen_after) do
      {:ok, tablebase} ->
        socket = snapshot(socket, fen_after, tablebase)
        reply_to(socket, tablebase)

      other ->
        {:noreply,
         socket
         |> assign(:status, :blocked)
         |> assign(:blocked_reason, blocked_reason(other))}
    end
  end

  defp reply_to(socket, %Tablebase{checkmate: true}), do: solve_attempt(socket)

  defp reply_to(socket, %Tablebase{moves: [reply | _]}) do
    {:noreply,
     socket
     |> assign(:awaiting_reply, true)
     |> assign(:pending_reply, %{san: reply.san, uci: reply.uci})
     |> push_event("opponent_move", reply_payload(reply))}
  end

  defp reply_to(socket, %Tablebase{}) do
    # Terminal non-mate position (stalemate/insufficient): no reply to play.
    {:noreply, socket}
  end

  defp solve_attempt(socket) do
    {:ok, endgame} = Endgames.record_solve(socket.assigns.endgame)

    socket =
      socket
      |> assign(:endgame, endgame)
      |> record_attempt(:solved)

    {:noreply,
     socket
     |> assign(:status, :solved)
     |> assign(:awaiting_reply, false)
     |> assign(:best_move, nil)}
  end

  defp fail_attempt(socket) do
    socket = record_attempt(socket, :failed)

    {:noreply,
     socket
     |> assign(:status, :failed)
     |> assign(:awaiting_reply, false)
     |> assign(:best_move, best_move_text(socket.assigns.tablebase))}
  end

  defp record_attempt(socket, outcome) do
    case Attempts.record_attempt(socket.assigns.current_scope, socket.assigns.endgame, outcome) do
      {:ok, attempt} ->
        case Ratings.rate_attempt(attempt) do
          {:ok, %{user: user, endgame: endgame}} ->
            socket
            |> assign(:endgame, endgame)
            |> assign(:user_rating, user.rating)

          {:skipped, _attempt} ->
            put_flash(
              socket,
              :info,
              "Replay recorded. Your rating is unchanged because you played this recently."
            )
        end

      _ ->
        socket
    end
  end

  defp user_rating(%{user: %{rating: rating}}), do: rating
  defp user_rating(_), do: nil

  defp best_move_text(tablebase) do
    san =
      tablebase
      |> best_moves()
      |> Enum.map(& &1.san)
      |> Enum.reject(&is_nil/1)
      |> Enum.take(3)
      |> Enum.join(", ")

    if san == "", do: nil, else: san
  end

  defp pick_best_move(tablebase), do: tablebase |> best_moves() |> List.first()

  defp best_moves(%Tablebase{moves: moves} = tablebase) when is_list(moves) do
    case {outcome_rank(tablebase.category), moves} do
      {nil, _} ->
        []

      {_best_rank, []} ->
        []

      {best_rank, [best | _]} ->
        Enum.filter(moves, fn move ->
          outcome_rank(mover_outcome(move.category)) == best_rank and move.dtz == best.dtz
        end)
    end
  end

  defp best_moves(_tablebase), do: []

  defp record_opponent_ply(socket, fen, client_san) do
    san =
      case socket.assigns.pending_reply do
        %{san: san} when is_binary(san) -> san
        _ -> client_san || "…"
      end

    ply = %{
      index: length(socket.assigns.plies),
      san: san,
      fen_after: fen,
      grade: nil
    }

    socket
    |> assign(:plies, socket.assigns.plies ++ [ply])
    |> assign(:pending_reply, nil)
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
