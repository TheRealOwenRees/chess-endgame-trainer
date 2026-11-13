defmodule ChesstrainerWeb.EndgameLive.PlayCore do
  @moduledoc """
  Shared per-puzzle play logic.

  Used by `ChesstrainerWeb.EndgameLive.Play` (standalone play, optional auth)
  and `ChesstrainerWeb.EndgameLive.Train` (a session of puzzles). Every public
  function takes and returns the LiveView socket, or a `{:noreply, socket}`
  tuple, so each LiveView keeps its own `handle_event/3` entry points and
  delegates here.

  The board hook pushes events to whichever LiveView renders it, so this module
  never assumes a particular parent.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3, assign_new: 3]
  import Phoenix.LiveView, only: [connected?: 1, push_event: 3, put_flash: 3]

  alias Chesstrainer.Attempts
  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Ratings
  alias ChesstrainerWeb.RatingComponents

  require Logger

  @uci_pattern ~r/^[a-h][1-8][a-h][1-8][qrbn]?$/

  @typedoc """
  A blocked puzzle's user-facing state.

  `kind` names the failure class, `title` and `message` are the only copy shown
  to the player, and `retry` says whether fetching again can plausibly help.
  """
  @type blocked :: %{
          kind: :cooldown | :rate_limited | :not_covered | :unavailable,
          title: String.t(),
          message: String.t(),
          retry: boolean()
        }

  @doc """
  Loads `endgame` and starts an attempt on it.

  `:page_title` overrides the default "Play endgame". The user's rating is only
  assigned when it is not already present, so a session keeps the rating it has
  already advanced.
  """
  def init(socket, endgame, opts \\ []) do
    socket
    |> assign(:page_title, Keyword.get(opts, :page_title, "Play endgame"))
    |> assign(:endgame, endgame)
    |> assign_new(:user_rating, fn -> user_rating(socket.assigns.current_scope) end)
    |> assign_new(:user_deviation, fn -> user_deviation(socket.assigns.current_scope) end)
    |> assign(:fen, endgame.fen)
    |> assign(:tablebase, nil)
    |> assign(:status, :loading)
    |> assign(:blocked, nil)
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
    |> assign(:pending_move, nil)
    |> assign(:last_san, "None yet")
    |> assign(:last_from_to, "None yet")
    |> assign(:last_grade, nil)
    |> assign(:awaiting_reply, false)
    |> assign(:last_rating_delta, nil)
    |> assign(:last_check, false)
    |> assign(:last_checkmate, false)
    |> assign(:move_input, "")
    |> assign(:move_input_error, nil)
    |> load_attempt()
  end

  def move_played(socket, params) do
    %{"from" => from, "to" => to, "san" => san} = params
    promotion = params["promotion"]
    draw = params["draw"] || false
    check = params["check"] || false
    checkmate = params["checkmate"] || false
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
        grade_and_record(socket, from, to, promotion, san, fen_after, draw, check, checkmate)
    end
  end

  @doc """
  Plays the move typed into the keyboard move input.

  The tablebase already knows every legal move in the position, so matching SAN
  or UCI against it validates the input without a chess engine on the server.
  The board hook applies the move and reports it through the normal move events.
  """
  def submit_move(socket, %{"move" => input}) do
    cond do
      socket.assigns.reviewing ->
        move_input_rejected(socket, "Leave review to make a move.")

      socket.assigns.status != :playing ->
        move_input_rejected(socket, "This puzzle is not open for moves right now.")

      socket.assigns.awaiting_reply ->
        move_input_rejected(socket, "Wait for the opponent's reply.")

      true ->
        case parse_move_input(socket.assigns.tablebase, input) do
          %Tablebase.Move{} = move ->
            {:noreply,
             socket
             |> assign(:move_input, "")
             |> assign(:move_input_error, nil)
             |> push_event("apply_move", reply_payload(move))}

          _ ->
            move_input_rejected(
              socket,
              "Not a legal move here. Try SAN like Nf3, or squares like g1f3."
            )
        end
    end
  end

  def submit_move(socket, _params), do: {:noreply, socket}

  def move_input_changed(socket, %{"move" => value}) when is_binary(value) do
    {:noreply, socket |> assign(:move_input, value) |> assign(:move_input_error, nil)}
  end

  def move_input_changed(socket, _params), do: {:noreply, socket}

  def move_input_error(socket, %{"message" => message}) when is_binary(message) do
    {:noreply, assign(socket, :move_input_error, message)}
  end

  def move_input_error(socket, _params), do: {:noreply, socket}

  def opponent_reply_applied(socket, params) do
    %{"fen" => fen} = params
    draw = params["draw"] || false
    check = params["check"] || false
    checkmate = params["checkmate"] || false

    if socket.assigns.awaiting_reply do
      socket =
        socket
        |> record_opponent_ply(fen, params["san"])
        |> assign(:last_check, check)
        |> assign(:last_checkmate, checkmate)

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
             |> assign(:blocked, nil)
             |> assign(:move_input_error, nil)
             |> push_event("resume_board", %{})}

          other ->
            {:noreply,
             socket
             |> assign(:awaiting_reply, false)
             |> assign(:status, :blocked)
             |> assign(:blocked, blocked(other))}
        end
      end
    else
      {:noreply, socket}
    end
  end

  def fen_invalid(socket, %{"fen" => fen, "message" => message}) do
    Logger.warning("board.fen_invalid", fen: fen, message: message)

    {:noreply,
     put_flash(socket, :error, "The board couldn't load this position. Reset to try again.")}
  end

  def reset(socket) do
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
      |> assign(:pending_move, nil)
      |> assign(:last_san, "None yet")
      |> assign(:last_from_to, "None yet")
      |> assign(:last_grade, nil)
      |> assign(:last_rating_delta, nil)
      |> assign(:last_check, false)
      |> assign(:last_checkmate, false)
      |> assign(:move_input, "")
      |> assign(:move_input_error, nil)

    {:noreply, load_attempt(socket)}
  end

  def review(socket) do
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

  def review_prev(socket), do: step_review(socket, -1)

  def review_next(socket), do: step_review(socket, 1)

  def review_start(socket), do: review_step(socket, 0)

  def review_end(socket), do: review_step(socket, length(socket.assigns.line))

  def review_step(socket, index) do
    if socket.assigns.reviewing do
      last = length(socket.assigns.line)
      index = parse_index(index) |> max(0) |> min(last)

      {:noreply, push_review_position(set_review_index(socket, index))}
    else
      {:noreply, socket}
    end
  end

  def play_best_line(socket) do
    with true <- socket.assigns.reviewing,
         %Tablebase{} = tablebase <- socket.assigns.review_tablebase,
         %Tablebase.Move{} = move <- pick_best_move(tablebase) do
      play_review_move(socket, move, true)
    else
      _ -> {:noreply, socket}
    end
  end

  @doc """
  Plays one tablebase move from the reviewed position, branching the line.

  The move comes from a `phx-value-uci` on the tablebase table.
  """
  def review_move(socket, %{"uci" => uci}) do
    with true <- socket.assigns.reviewing,
         %Tablebase{} = tablebase <- socket.assigns.review_tablebase,
         %Tablebase.Move{} = move <- find_move_by_uci(tablebase, uci) do
      play_review_move(socket, move, false)
    else
      _ -> {:noreply, socket}
    end
  end

  # Branch the review line at the current position, then ask the board to play
  # the move; `best_line_move_applied/2` appends it once chess.js confirms it.
  defp play_review_move(socket, move, best_line?) do
    {:noreply,
     socket
     |> assign(:line, Enum.take(socket.assigns.line, socket.assigns.review_index))
     |> assign(:awaiting_best_line, true)
     |> assign(:pending_move, %{move: move, best_line: best_line?})
     |> push_event("best_line_move", reply_payload(move))}
  end

  def best_line_move_applied(socket, %{"fen" => fen}) do
    if socket.assigns.awaiting_best_line do
      %{move: move, best_line: best_line?} = socket.assigns.pending_move

      line =
        socket.assigns.line ++
          [
            %{
              index: length(socket.assigns.line),
              san: move.san,
              fen_after: fen,
              grade: nil,
              analysis: true,
              best_line: best_line?
            }
          ]

      socket =
        socket
        |> assign(:line, line)
        |> assign(:awaiting_best_line, false)
        |> assign(:pending_move, nil)
        |> set_review_index(length(line))

      {:noreply, push_review_position(socket)}
    else
      {:noreply, socket}
    end
  end

  def back_to_game(socket) do
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

  @doc "The best available move as a display string, or nil."
  def best_move_text(tablebase) do
    san =
      tablebase
      |> best_moves()
      |> Enum.map(& &1.san)
      |> Enum.reject(&is_nil/1)
      |> Enum.take(3)
      |> Enum.join(", ")

    if san == "", do: nil, else: san
  end

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
          |> assign(:blocked, nil)
          |> push_init_board(fen)

        other ->
          socket
          |> assign(:tablebase, nil)
          |> assign(:status, :blocked)
          |> assign(:blocked, blocked(other))
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

  @doc """
  Classifies a failed tablebase fetch into the copy the player sees.

  One message per failure class; the underlying reason never reaches the page.
  """
  @spec blocked(term()) :: blocked()
  def blocked({:cooldown, remaining_ms}) do
    seconds = max(div(remaining_ms + 999, 1000), 1)

    %{
      kind: :cooldown,
      title: "Tablebase cooling down",
      message: "The tablebase is rate-limited. Try again in about #{seconds}s.",
      retry: true
    }
  end

  def blocked({:error, {:too_many_requests, _, _}}) do
    %{
      kind: :rate_limited,
      title: "Tablebase rate-limited",
      message: "The tablebase is rate-limited. Try again in a minute.",
      retry: true
    }
  end

  def blocked({:error, {:client_error, 404, _}}), do: not_covered()
  def blocked({:error, :not_covered}), do: not_covered()
  def blocked({:error, :invalid_endgame}), do: not_covered()

  def blocked({:error, reason}) do
    Logger.warning("tablebase.unavailable", reason: inspect(reason))

    %{
      kind: :unavailable,
      title: "Tablebase unavailable",
      message: "The tablebase is unavailable right now. Try again in a moment.",
      retry: true
    }
  end

  defp not_covered do
    %{
      kind: :not_covered,
      title: "Position not covered",
      message: "This position isn't in the tablebase, so it can't be graded.",
      retry: false
    }
  end

  defp grade_and_record(socket, from, to, promotion, san, fen_after, draw, check, checkmate) do
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
          |> assign(:last_check, check)
          |> assign(:last_checkmate, checkmate)
          |> assign(:move_input, "")
          |> assign(:move_input_error, nil)
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
         |> assign(:blocked, blocked(other))}
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
          {:ok, %{user: user, endgame: endgame, user_delta: delta}} ->
            socket
            |> assign(:endgame, endgame)
            |> assign(:user_rating, user.rating)
            |> assign(:user_deviation, user.rating_deviation)
            |> assign(:last_rating_delta, delta)
            |> put_rating_flash(outcome, user.rating, delta)

          {:skipped, _attempt} ->
            socket
            |> assign(:last_rating_delta, nil)
            |> put_flash(
              :info,
              "Your rating is unchanged because you played this puzzle recently."
            )
        end

      _ ->
        assign(socket, :last_rating_delta, nil)
    end
  end

  # A finished rating change is shown as a flash so the player sees it
  # immediately, whether they are in a session or playing a single endgame.
  defp put_rating_flash(socket, outcome, rating, delta) do
    kind = if outcome == :solved, do: :success, else: :error
    put_flash(socket, kind, rating_change_message(socket, outcome, rating, delta))
  end

  defp rating_change_message(socket, :solved, rating, delta) do
    result = if socket.assigns.endgame.result == :draw, do: "Draw held", else: "Solved"

    "#{result}! Your rating is now #{round(rating)} " <>
      "(#{RatingComponents.format_delta(delta)})."
  end

  defp rating_change_message(_socket, :failed, rating, delta) do
    "Failed. Your rating is now #{round(rating)} (#{RatingComponents.format_delta(delta)})."
  end

  defp user_rating(%{user: %{rating: rating}}), do: rating
  defp user_rating(_), do: nil

  defp user_deviation(%{user: %{rating_deviation: deviation}}), do: deviation
  defp user_deviation(_), do: nil

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

  defp find_move_by_uci(%Tablebase{moves: moves}, uci) when is_list(moves) do
    Enum.find(moves, &(&1.uci == uci))
  end

  defp find_move_by_uci(_tablebase, _uci), do: nil

  defp parse_move_input(%Tablebase{} = tablebase, input) when is_binary(input) do
    normalized = input |> String.trim() |> String.downcase() |> String.replace(" ", "")
    uci = String.replace(normalized, "-", "")

    cond do
      normalized == "" -> nil
      Regex.match?(@uci_pattern, uci) -> find_move_by_uci(tablebase, uci)
      true -> find_move_by_san(tablebase, normalize_san(normalized))
    end
  end

  defp parse_move_input(_tablebase, _input), do: nil

  defp find_move_by_san(%Tablebase{moves: moves}, san) when is_list(moves) and is_binary(san) do
    Enum.find(moves, &(normalize_san(&1.san) == san))
  end

  defp find_move_by_san(_tablebase, _san), do: nil

  defp normalize_san(san) when is_binary(san) do
    san
    |> String.downcase()
    |> String.replace("=", "")
    |> String.replace(~r/[+#!?]/, "")
  end

  defp normalize_san(_san), do: nil

  defp move_input_rejected(socket, message) do
    {:noreply, assign(socket, :move_input_error, message)}
  end

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

  defp positions(start_fen, plies), do: [start_fen | Enum.map(plies, & &1.fen_after)]

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
          other -> {:unavailable, blocked(other), socket}
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
end
