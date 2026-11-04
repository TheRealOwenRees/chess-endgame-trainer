defmodule ChesstrainerWeb.HomeBoardLive do
  @moduledoc """
  A compact, playable endgame board for the landing page.

  The board is server-rendered and driven with `Chex`; the tablebase grades the
  player's move and supplies the opponent's reply. This keeps the landing
  board's look while reusing the same tablebase the trainer uses.
  """
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Themes

  @files %{
    "a" => :a,
    "b" => :b,
    "c" => :c,
    "d" => :d,
    "e" => :e,
    "f" => :f,
    "g" => :g,
    "h" => :h
  }

  @promotions %{"q" => :queen, "r" => :rook, "b" => :bishop, "n" => :knight}

  @impl true
  def mount(_params, session, socket) do
    endgame = load_endgame(session)

    socket =
      socket
      |> assign(:endgame, endgame)
      |> base_assigns(endgame)

    if connected?(socket) and endgame do
      {:ok, load_position(socket)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="board-shell">
      <div class="board-topline">
        <div class="player">
          <span class="player-piece dark-piece">♚</span>
          <span>
            <small>To move</small>
            <strong>{turn_label(@game)}</strong>
          </span>
        </div>
        <span class="time-pill">∞</span>
      </div>

      <.board_grid
        :if={@fen}
        fen={@fen}
        orientation={@player_color}
        selected={@selected}
        targets={@targets}
        interactive={@status == :playing}
        disabled={@status != :playing}
      />
      <div :if={!@fen} class="chessboard board-empty">No position to play</div>

      <div class="board-caption">
        <div>
          <span>Today’s position</span>
          <strong>{title(@endgame)}</strong>
          <small :if={@themes != []} class="board-themes">{Enum.join(@themes, " · ")}</small>
        </div>
        <div class="board-status">
          <span class={status_class(@status)}>{status_text(@status, @blocked_reason)}</span>
          <small :if={@message} class="board-message">{@message}</small>
          <button :if={@status in [:solved, :failed, :blocked]} type="button" phx-click="reset">
            Try again
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("square", %{"square" => key}, socket) do
    if socket.assigns.status == :playing do
      handle_square(socket, key)
    else
      {:noreply, socket}
    end
  end

  def handle_event("reset", _params, socket) do
    socket = base_assigns(socket, socket.assigns.endgame)

    if socket.assigns.endgame do
      {:noreply, load_position(socket)}
    else
      {:noreply, socket}
    end
  end

  defp load_endgame(%{"home_endgame_code" => code}) when is_binary(code) do
    Endgames.get_endgame_by_public_code_with_themes!(code)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp load_endgame(_session), do: nil

  defp base_assigns(socket, nil) do
    assign(socket,
      game: nil,
      fen: nil,
      player_color: :white,
      themes: [],
      selected: nil,
      targets: [],
      status: :none,
      tablebase: nil,
      blocked_reason: nil,
      message: nil
    )
  end

  defp base_assigns(socket, endgame) do
    case Chex.Game.new(endgame.fen) do
      {:ok, game} ->
        assign(socket,
          game: game,
          fen: serialize(game),
          player_color: endgame.color,
          themes: Themes.names(endgame.themes),
          selected: nil,
          targets: [],
          status: :loading,
          tablebase: nil,
          blocked_reason: nil,
          message: nil
        )

      _other ->
        assign(socket,
          game: nil,
          fen: nil,
          player_color: endgame.color,
          themes: Themes.names(endgame.themes),
          selected: nil,
          targets: [],
          status: :blocked,
          tablebase: nil,
          blocked_reason: "This position could not be loaded.",
          message: nil
        )
    end
  end

  defp load_position(socket) do
    case Tablebase.new(socket.assigns.fen) do
      {:ok, tablebase} ->
        assign(socket, tablebase: tablebase, status: :playing, blocked_reason: nil)

      other ->
        assign(socket,
          tablebase: nil,
          status: :blocked,
          blocked_reason: blocked_reason(other)
        )
    end
  end

  defp handle_square(socket, key) do
    with {:ok, square} <- parse_square(key) do
      game = socket.assigns.game
      player_color = socket.assigns.player_color
      selected = socket.assigns.selected

      cond do
        is_nil(game) ->
          {:noreply, socket}

        is_nil(selected) ->
          select_or_ignore(socket, game, square, player_color, key)

        selected == key ->
          {:noreply, socket |> assign(:selected, nil) |> assign(:targets, [])}

        true ->
          with {:ok, from} <- parse_square(selected) do
            play_move(socket, from, square)
          end
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp select_or_ignore(socket, game, square, player_color, key) do
    if game.active_color == player_color and Chex.get_piece_color(game, square) == player_color do
      {:noreply,
       socket
       |> assign(:selected, key)
       |> assign(:targets, target_keys(game, square))}
    else
      {:noreply, socket}
    end
  end

  defp play_move(socket, from, to) do
    game = socket.assigns.game
    moving_piece = Chex.get_piece_name(game, from)

    case Chex.Game.move(game, {from, to}) do
      {:ok, new_game} ->
        promotion = if moving_piece == :pawn and elem(to, 1) in [1, 8], do: "q"
        grade_and_continue(socket, from, to, promotion, new_game)

      {:error, _reason} ->
        reselect(socket, game, to)
    end
  end

  defp reselect(socket, game, square) do
    if game.active_color == socket.assigns.player_color and
         Chex.get_piece_color(game, square) == socket.assigns.player_color do
      {:noreply,
       socket
       |> assign(:selected, square_key(square))
       |> assign(:targets, target_keys(game, square))}
    else
      {:noreply, socket |> assign(:selected, nil) |> assign(:targets, [])}
    end
  end

  defp grade_and_continue(socket, from, to, promotion, new_game) do
    tablebase = socket.assigns.tablebase
    uci = square_key(from) <> square_key(to) <> (promotion || "")
    move = find_move(tablebase, uci)
    grade = if move, do: grade_move(tablebase, move), else: :unknown

    socket =
      socket
      |> assign(:game, new_game)
      |> assign(:fen, serialize(new_game))
      |> assign(:selected, nil)
      |> assign(:targets, [])

    cond do
      grade == :losing ->
        {:noreply,
         assign(socket, status: :failed, message: failure_message(socket.assigns.endgame))}

      solved?(socket, new_game, promotion) ->
        {:noreply,
         assign(socket, status: :solved, message: solved_message(socket.assigns.endgame))}

      true ->
        reply(socket, new_game)
    end
  end

  defp solved?(socket, game, promotion) do
    endgame = socket.assigns.endgame
    player = socket.assigns.player_color
    result = Chex.Game.result(game)

    cond do
      result == player -> true
      result == :draw -> endgame.result == :draw
      result != nil -> false
      endgame.result == :win and promotion != nil -> true
      true -> false
    end
  end

  defp reply(socket, game) do
    fen = serialize(game)

    case Tablebase.new(fen) do
      {:ok, %Tablebase{checkmate: true}} ->
        {:noreply,
         assign(socket, status: :solved, message: solved_message(socket.assigns.endgame))}

      {:ok, tablebase} ->
        case best_moves(tablebase) do
          [best | _] ->
            apply_reply(socket, game, best)

          [] ->
            if socket.assigns.endgame.result == :draw do
              {:noreply,
               assign(socket, status: :solved, message: solved_message(socket.assigns.endgame))}
            else
              {:noreply, assign(socket, status: :failed, message: "No reply is available.")}
            end
        end

      other ->
        {:noreply,
         assign(socket,
           tablebase: nil,
           status: :blocked,
           blocked_reason: blocked_reason(other)
         )}
    end
  end

  defp apply_reply(socket, game, %Tablebase.Move{uci: uci}) do
    with {:ok, from, to, promotion} <- parse_uci(uci),
         {:ok, new_game} <- move_with_promotion(game, from, to, promotion) do
      socket =
        socket
        |> assign(:game, new_game)
        |> assign(:fen, serialize(new_game))

      case Tablebase.new(socket.assigns.fen) do
        {:ok, tablebase} ->
          {:noreply, assign(socket, tablebase: tablebase, status: :playing, blocked_reason: nil)}

        other ->
          {:noreply,
           assign(socket,
             tablebase: nil,
             status: :blocked,
             blocked_reason: blocked_reason(other)
           )}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp move_with_promotion(game, from, to, nil), do: Chex.Game.move(game, {from, to})

  defp move_with_promotion(game, from, to, promotion),
    do: Chex.Game.move(game, {from, to, promotion})

  defp parse_square(<<file::binary-size(1), rank::binary-size(1)>>) do
    with file_atom when is_atom(file_atom) <- Map.get(@files, file),
         {rank_int, ""} <- Integer.parse(rank),
         true <- rank_int in 1..8 do
      {:ok, {file_atom, rank_int}}
    else
      _ -> :error
    end
  end

  defp parse_square(_key), do: :error

  defp parse_uci(
         <<from_file::binary-size(1), from_rank::binary-size(1), to_file::binary-size(1),
           to_rank::binary-size(1)>> <> promotion
       ) do
    with {:ok, from} <- parse_square(from_file <> from_rank),
         {:ok, to} <- parse_square(to_file <> to_rank) do
      {:ok, from, to, normalize_promotion(promotion)}
    else
      _ -> :error
    end
  end

  defp parse_uci(_uci), do: :error

  defp normalize_promotion(""), do: nil
  defp normalize_promotion(<<char::binary-size(1)>>), do: Map.get(@promotions, char)
  defp normalize_promotion(_promotion), do: nil

  defp serialize(game) do
    {:ok, fen} = Chex.Parser.FEN.serialize(game)
    fen
  end

  defp square_key({file, rank}), do: "#{file}#{rank}"

  defp target_keys(game, square) do
    game |> Chex.possible_moves(square) |> Enum.map(&square_key/1)
  end

  defp find_move(%Tablebase{moves: moves}, uci) when is_list(moves) do
    Enum.find(moves, &(&1.uci == uci))
  end

  defp find_move(_tablebase, _uci), do: nil

  defp best_moves(%Tablebase{moves: moves} = tablebase) when is_list(moves) do
    case {outcome_rank(tablebase.category), moves} do
      {nil, _} ->
        []

      {_rank, []} ->
        []

      {best_rank, [best | _]} ->
        Enum.filter(moves, fn move ->
          outcome_rank(mover_outcome(move.category)) == best_rank and move.dtz == best.dtz
        end)
    end
  end

  defp best_moves(_tablebase), do: []

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

  defp mover_outcome(:loss), do: :win
  defp mover_outcome(:win), do: :loss
  defp mover_outcome(:draw), do: :draw
  defp mover_outcome(_), do: :unknown

  defp outcome_rank(:win), do: 2
  defp outcome_rank(:draw), do: 1
  defp outcome_rank(:loss), do: 0
  defp outcome_rank(_), do: nil

  defp blocked_reason({:cooldown, remaining_ms}) do
    seconds = max(div(remaining_ms + 999, 1000), 1)
    "The tablebase is rate-limited. Try again in about #{seconds}s."
  end

  defp blocked_reason({:error, {:too_many_requests, _, _}}),
    do: "The tablebase is rate-limited. Try again in a minute."

  defp blocked_reason({:error, {:client_error, 404, _}}),
    do: "This position is not covered by the tablebase."

  defp blocked_reason({:error, :not_covered}),
    do: "This position is not covered by the tablebase."

  defp blocked_reason({:error, reason}),
    do: "The tablebase is unavailable (#{inspect(reason)})."

  defp blocked_reason(_reason), do: "The tablebase is unavailable."

  defp turn_label(nil), do: "—"
  defp turn_label(%{active_color: :white}), do: "White"
  defp turn_label(%{active_color: :black}), do: "Black"
  defp turn_label(_game), do: "—"

  defp title(nil), do: "No position"
  defp title(%{key: key}) when is_binary(key) and key != "", do: key
  defp title(%{message: message}) when is_binary(message) and message != "", do: message
  defp title(_endgame), do: "Featured position"

  defp solved_message(%{result: :draw}), do: "Draw held!"
  defp solved_message(_endgame), do: nil

  defp failure_message(%{result: :draw}), do: "That move loses the draw."
  defp failure_message(_endgame), do: "That move throws away the win."

  defp status_text(:loading, _reason), do: "Loading…"
  defp status_text(:playing, _reason), do: "Your move"
  defp status_text(:solved, _reason), do: "Solved!"
  defp status_text(:failed, _reason), do: "Failed"
  defp status_text(:blocked, reason), do: reason || "Tablebase unavailable"
  defp status_text(:none, _reason), do: "No endgames yet"
  defp status_text(_status, _reason), do: ""

  defp status_class(:solved), do: "status-solved"
  defp status_class(:failed), do: "status-failed"
  defp status_class(:blocked), do: "status-blocked"
  defp status_class(_status), do: "status-neutral"
end
