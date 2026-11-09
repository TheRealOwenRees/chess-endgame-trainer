defmodule ChesstrainerWeb.PlayComponents do
  @moduledoc """
  The shared board and side panel for playing an endgame.

  Used by the standalone play screen and by a training session, which adds the
  "Next puzzle" action via `session={true}`.
  """

  use ChesstrainerWeb, :html

  alias ChesstrainerWeb.Board.PositionText
  alias ChesstrainerWeb.EndgameLive.PlayCore

  attr :endgame, :any, required: true
  attr :fen, :string, default: nil
  attr :status, :atom, required: true
  attr :blocked_reason, :string, default: nil
  attr :best_move, :string, default: nil
  attr :plies, :list, required: true
  attr :line, :list, required: true
  attr :reviewing, :boolean, required: true
  attr :review_index, :integer, required: true
  attr :review_tablebase, :any, default: nil
  attr :review_blocked, :string, default: nil
  attr :awaiting_reply, :boolean, required: true
  attr :last_grade, :atom, default: nil
  attr :awaiting_best_line, :boolean, default: false
  attr :session, :boolean, default: false
  attr :move_input, :string, default: ""
  attr :move_input_error, :string, default: nil
  attr :last_check, :boolean, default: false
  attr :last_checkmate, :boolean, default: false

  def play_surface(assigns) do
    assigns =
      assigns
      |> assign(
        :can_input,
        assigns.status == :playing and not assigns.awaiting_reply and not assigns.reviewing
      )
      |> assign(:move_hint, move_hint(assigns.status, assigns.awaiting_reply))

    ~H"""
    <div class="flex flex-col gap-2 rounded-xl bg-base-200 p-4 shadow-inner sm:flex-row">
      <div class="flex w-full flex-col gap-2 sm:w-100">
        <div class="relative">
          <div
            id="endgame-board"
            phx-hook="ChessBoard"
            phx-update="ignore"
            data-endgame-id={@endgame.id}
            class="aspect-square w-full"
            aria-hidden="true"
          >
          </div>
        </div>

        <div
          id="board-announcer"
          role="status"
          aria-live="polite"
          aria-atomic="true"
          class="sr-only"
        >
          {board_announcement(assigns)}
        </div>
        <div id="position-summary" class="sr-only">
          {PositionText.summary(position_fen(assigns))}
        </div>

        <form
          :if={not @reviewing}
          id="move-input-form"
          phx-submit="submit_move"
          phx-change="move_input"
          phx-debounce="200"
          class="flex items-start gap-2"
        >
          <div class="min-w-0 flex-1">
            <.input
              id="move-input"
              name="move"
              value={@move_input}
              label="Your move"
              placeholder="Nf3 or g1f3"
              autocomplete="off"
              aria-describedby="move-input-help"
              disabled={not @can_input}
              class="font-mono"
            />
            <p id="move-input-help" class="mt-1 text-xs text-muted">
              SAN or UCI, e.g. <span class="font-mono">Nf3</span>
              or <span class="font-mono">g1f3</span>.
            </p>
            <p :if={@move_hint} class="mt-1 text-xs text-muted" role="status">{@move_hint}</p>
            <p
              :if={@move_input_error}
              id="move-input-error"
              role="alert"
              class="mt-1 text-sm text-error-text"
            >
              {@move_input_error}
            </p>
          </div>
          <.button type="submit" class="mt-6" disabled={not @can_input}>Play move</.button>
        </form>

        <div
          :if={@reviewing}
          id="review-controls"
          class="flex items-center gap-2"
          role="group"
          aria-label="Review navigation"
        >
          <.button
            id="review-start"
            phx-click="review_start"
            disabled={@review_index <= 0}
            title="Back to start"
            aria-label="Back to start"
          >
            {"<<"}
          </.button>
          <.button
            id="review-prev"
            phx-click="review_prev"
            disabled={@review_index <= 0}
            title="Previous position"
            aria-label="Previous position"
          >
            ←
          </.button>
          <.button
            id="review-next"
            phx-click="review_next"
            disabled={@review_index >= length(@line)}
            title="Next position"
            aria-label="Next position"
          >
            →
          </.button>
          <.button
            id="review-end"
            phx-click="review_end"
            disabled={@review_index >= length(@line)}
            title="Go to end"
            aria-label="Go to end"
          >
            {">>"}
          </.button>
        </div>

        <div class="flex flex-wrap gap-2" role="group" aria-label="Puzzle actions">
          <.button
            :if={(@reviewing and @review_tablebase) && PlayCore.best_move_text(@review_tablebase)}
            phx-click="play_best_line"
            disabled={@awaiting_best_line}
          >
            Play best line
          </.button>
          <.button :if={@reviewing and @line != @plies} phx-click="back_to_game">
            Back to game
          </.button>
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
          <.button
            :if={@session and @status in [:solved, :failed]}
            id="next-puzzle-button"
            phx-click="next_puzzle"
            variant="primary"
          >
            Next puzzle
          </.button>
        </div>
      </div>

      <div class="relative w-full sm:w-48">
        <div class="flex flex-col gap-3 sm:absolute sm:inset-0">
          <%= if @reviewing do %>
            <div
              id="best-move-panel"
              class="flex-1 min-h-0 overflow-y-auto rounded-lg bg-canvas-raised p-3 text-sm"
            >
              <%= cond do %>
                <% @review_blocked -> %>
                  <p class="text-muted">Best move unavailable here</p>
                  <p class="text-muted">{@review_blocked}</p>
                <% @review_tablebase -> %>
                  <p class="text-muted font-semibold mb-1">Best move:</p>
                  <p class="text-success-text">{PlayCore.best_move_text(@review_tablebase) || "—"}</p>
                  <%= if played_ply = played_ply_at(@line, @review_index) do %>
                    <p class={["mt-1", grade_class(played_ply.grade)]}>Played: {played_ply.san}</p>
                  <% end %>
                  <.tablebase_options tablebase={@review_tablebase} />
                <% true -> %>
                  <p class="text-muted">No best move.</p>
              <% end %>
            </div>
          <% else %>
            <div class="rounded-lg bg-canvas-raised p-3 text-sm">
              <%= cond do %>
                <% @status == :loading -> %>
                  <p class="text-muted">Loading tablebase…</p>
                <% @status == :blocked -> %>
                  <p class="font-semibold text-error-text">Tablebase unavailable</p>
                  <p class="text-error-text">{@blocked_reason}</p>
                <% @status == :solved -> %>
                  <p class="font-semibold text-success-text">
                    {if @endgame.result == :draw, do: "Draw held!", else: "Solved!"}
                  </p>
                <% @status == :failed -> %>
                  <p class="font-semibold text-error-text">Failed</p>
                  <p class="text-error-text">
                    {if @endgame.result == :draw,
                      do: "That move loses the draw.",
                      else: "That move throws away the win."}
                  </p>
                  <%= if @best_move && @plies != [] do %>
                    <p class="text-muted">
                      You played {List.last(@plies).san}; best was: {@best_move}
                    </p>
                  <% end %>
                <% @awaiting_reply -> %>
                  <p class="text-muted">Thinkin...</p>
                <% @last_grade == :optimal -> %>
                  <p class="font-semibold text-success-text">Optimal move</p>
                <% @last_grade == :winning -> %>
                  <p class="font-semibold text-warning-text">
                    {if @endgame.result == :draw,
                      do: "Keeps the draw — but not the sharpest",
                      else: "Winning — but not the sharpest"}
                  </p>
                <% @last_grade == :losing -> %>
                  <p class="font-semibold text-error-text">
                    {if @endgame.result == :draw,
                      do: "Losing move — this loses the draw",
                      else: "Losing move — this throws away the win"}
                  </p>
                <% @last_grade == :unknown -> %>
                  <p class="font-semibold text-muted">Could not grade that move</p>
                <% true -> %>
                  <p class="text-muted font-bold">Make a move.</p>
                  <p class="text-muted">You play {colour_name(@endgame.color)}</p>
              <% end %>
              <p :if={@status in [:solved, :failed]} class="mt-1 text-xs text-muted">
                Puzzle rating: {round(@endgame.rating)}
              </p>
            </div>

            <div
              id="move-list"
              role="region"
              aria-label="Moves"
              class="flex-1 min-h-0 flex flex-col bg-canvas-raised rounded-lg p-3"
            >
              <% plies = display_plies(@reviewing, @line, @plies) %>
              <p class="text-sm text-muted font-semibold mb-2">Moves:</p>
              <div class="flex-1 overflow-y-auto">
                <%= if plies == [] do %>
                  <p class="text-sm text-muted">No Moves</p>
                <% else %>
                  <%= for {[white_ply, black_ply], move_no} <- move_rows(plies, @endgame.color) do %>
                    <div class="font-mono text-sm leading-6">
                      <span class="text-muted mr-2">{move_no}.</span>
                      <%= if white_ply do %>
                        <.ply
                          ply={white_ply}
                          reviewing={@reviewing}
                          review_index={@review_index}
                          result={@endgame.result}
                        />
                      <% else %>
                        <span class="text-body">...</span>
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
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :tablebase, :any, required: true

  # The reviewed position's moves grouped like lichess's tablebase explorer:
  # each heading is the outcome for the side to move, one table per outcome.
  defp tablebase_options(assigns) do
    assigns = assign(assigns, :groups, tablebase_groups(assigns.tablebase))

    ~H"""
    <div :if={@groups != []} class="mt-3 border-t border-base-200 pt-2">
      <p class="text-muted font-semibold mb-1">Tablebase</p>
      <div :for={{label, class, moves} <- @groups} class="mt-2 first:mt-0">
        <p class={["text-xs font-semibold", class]}>{label}</p>
        <table class="w-full text-left text-xs font-mono">
          <tbody>
            <tr :for={move <- moves}>
              <td class={["py-0.5 pr-2", class]}>
                <button
                  type="button"
                  phx-click="review_move"
                  phx-value-uci={move.uci}
                  class="text-left hover:underline"
                  title={"Play #{move.san}"}
                  aria-label={"Play #{move.san}"}
                >
                  {move.san}
                </button>
              </td>
              <td class="py-0.5 text-right text-muted" title="Distance to zeroing (DTZ)">
                {dtz_text(move)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp tablebase_groups(%{moves: moves}) when is_list(moves) do
    [
      {"Winning", "text-success-text", :win},
      {"Drawn", "text-muted", :draw},
      {"Losing", "text-error-text", :loss},
      {"Unknown", "text-muted", :unknown}
    ]
    |> Enum.flat_map(fn {label, class, outcome} ->
      case Enum.filter(moves, &(mover_outcome(&1.category) == outcome)) do
        [] -> []
        moves -> [{label, class, moves}]
      end
    end)
  end

  defp tablebase_groups(_tablebase), do: []

  # A move's category is the outcome for the side to move *after* the move, so
  # the mover's outcome is its flip.
  defp mover_outcome(:loss), do: :win
  defp mover_outcome(:win), do: :loss
  defp mover_outcome(:draw), do: :draw
  defp mover_outcome(_), do: :unknown

  defp dtz_text(%{dtz: nil}), do: ""

  defp dtz_text(%{dtz: dtz}), do: "DTZ #{abs(dtz)}"

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
        aria-current={current_ply?(@ply, @review_index) && "step"}
        data-grade={@ply.grade}
      >
        {@ply.san}
        <span :if={ply_title(@ply, @result)} class="sr-only"> — {ply_title(@ply, @result)}</span>
      </button>
    <% else %>
      <span
        class={["ml-2", ply_class(@ply)]}
        title={ply_title(@ply, @result)}
        data-grade={@ply.grade}
      >
        {@ply.san}
        <span :if={ply_title(@ply, @result)} class="sr-only"> — {ply_title(@ply, @result)}</span>
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

  defp display_plies(true, line, _plies), do: line
  defp display_plies(false, _line, plies), do: plies

  defp colour_name(:white), do: "White"
  defp colour_name(:black), do: "Black"
  defp colour_name(colour), do: colour |> to_string() |> String.capitalize()

  defp current_ply?(%{index: index}, review_index), do: index + 1 == review_index

  defp played_ply_at(line, review_index) do
    case Enum.at(line, review_index) do
      %{analysis: true} -> nil
      ply -> ply
    end
  end

  defp ply_class(%{best_line: true}), do: "text-info italic"
  defp ply_class(%{analysis: true}), do: "text-info"
  defp ply_class(ply), do: grade_class(ply.grade)

  defp ply_title(%{best_line: true}, _result), do: "Best line"
  defp ply_title(%{analysis: true}, _result), do: "Tablebase move"
  defp ply_title(ply, result), do: grade_label(ply.grade, result)

  defp grade_class(:optimal), do: "text-success-text"
  defp grade_class(:winning), do: "text-warning-text"
  defp grade_class(:losing), do: "text-error-text"
  defp grade_class(_), do: "text-body"

  defp grade_label(nil, _result), do: nil
  defp grade_label(:optimal, _result), do: "Optimal move"
  defp grade_label(:winning, :draw), do: "Keeps the draw — but not the sharpest"
  defp grade_label(:winning, _result), do: "Winning — but not the sharpest"
  defp grade_label(:losing, :draw), do: "Loses the draw"
  defp grade_label(:losing, _result), do: "Throws away the win"
  defp grade_label(:unknown, _result), do: "Not graded"

  defp move_hint(:loading, _awaiting), do: "Loading the tablebase…"

  defp move_hint(:blocked, _awaiting),
    do: "The tablebase is unavailable, so moves cannot be entered."

  defp move_hint(status, _awaiting) when status in [:solved, :failed],
    do: "This puzzle is finished. Reset or try again."

  defp move_hint(_status, true), do: "Waiting for the opponent's reply."
  defp move_hint(_status, _awaiting), do: nil

  # While the opponent's move is in flight the server's `fen` still points at
  # the position before it, so describe the move the player just made instead.
  defp position_fen(%{awaiting_reply: true, plies: plies}) do
    case List.last(plies) do
      %{fen_after: fen} -> fen
      _ -> nil
    end
  end

  defp position_fen(%{fen: fen}) when is_binary(fen), do: fen

  defp position_fen(%{endgame: %{fen: fen}}), do: fen

  defp board_announcement(assigns) do
    cond do
      assigns.status == :loading ->
        "Loading the tablebase."

      assigns.status == :blocked ->
        "Tablebase unavailable. #{assigns.blocked_reason || "Moves cannot be graded."}"

      assigns.reviewing ->
        review_announcement(assigns)

      assigns.status == :solved ->
        join_sentences([solved_sentence(assigns), check_sentence(assigns)])

      assigns.status == :failed ->
        join_sentences(["Failed.", failure_sentence(assigns), best_move_sentence(assigns)])

      assigns.awaiting_reply ->
        join_sentences([
          "Move #{length(assigns.plies)}: you played #{last_san(assigns.plies)}.",
          grade_sentence(assigns),
          check_sentence(assigns),
          "Waiting for the opponent's reply."
        ])

      assigns.plies == [] ->
        "You play #{colour_name(assigns.endgame.color)}. #{colour_name(assigns.endgame.color)} to move."

      true ->
        case List.last(assigns.plies) do
          %{grade: nil} ->
            join_sentences([
              "Move #{length(assigns.plies)}: opponent played #{last_san(assigns.plies)}.",
              check_sentence(assigns),
              "Your move."
            ])

          _ ->
            join_sentences([
              "Move #{length(assigns.plies)}: you played #{last_san(assigns.plies)}.",
              grade_sentence(assigns),
              check_sentence(assigns),
              "Your move."
            ])
        end
    end
  end

  defp review_announcement(assigns) do
    previous = Enum.at(assigns.line, assigns.review_index - 1)

    position =
      cond do
        assigns.review_index <= 0 -> "Starting position."
        previous -> "After #{previous.san}."
        true -> "Final position."
      end

    "Reviewing position #{assigns.review_index} of #{length(assigns.line)}. #{position}"
  end

  defp failure_sentence(%{endgame: %{result: :draw}}), do: "That move loses the draw."
  defp failure_sentence(_assigns), do: "That move throws away the win."

  defp solved_sentence(%{endgame: %{result: :draw}}), do: "Draw held!"
  defp solved_sentence(_assigns), do: "Solved!"

  defp best_move_sentence(%{best_move: nil}), do: ""
  defp best_move_sentence(%{best_move: best}), do: "Best was #{best}."

  defp grade_sentence(%{plies: plies, endgame: endgame}) do
    case List.last(plies) do
      %{grade: grade} ->
        case grade_label(grade, endgame.result) do
          nil -> ""
          label -> "#{label}."
        end

      _ ->
        ""
    end
  end

  defp check_sentence(%{last_checkmate: true}), do: "Checkmate."
  defp check_sentence(%{last_check: true}), do: "Check."
  defp check_sentence(_assigns), do: ""

  defp last_san(plies) do
    case List.last(plies) do
      %{san: san} when is_binary(san) -> san
      _ -> "a move"
    end
  end

  defp join_sentences(sentences) do
    sentences
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end
end
