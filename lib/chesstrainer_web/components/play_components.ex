defmodule ChesstrainerWeb.PlayComponents do
  @moduledoc """
  The shared board and side panel for playing an endgame.

  Used by the standalone play screen and by a training session, which adds the
  "Next puzzle" action via `session={true}`.
  """

  use ChesstrainerWeb, :html

  alias ChesstrainerWeb.EndgameLive.PlayCore

  attr :endgame, :any, required: true
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

  def play_surface(assigns) do
    ~H"""
    <div class="flex gap-2 bg-base-200 p-4 rounded-xl shadow-inner">
      <div class="w-100 flex flex-col gap-2">
        <div
          id="endgame-board"
          phx-hook="ChessBoard"
          phx-update="ignore"
          data-endgame-id={@endgame.id}
          class="w-100 h-100"
        >
        </div>

        <div :if={@reviewing} id="review-controls" class="flex items-center gap-2">
          <.button
            id="review-start"
            phx-click="review_start"
            disabled={@review_index <= 0}
            title="Back to start"
          >
            {"<<"}
          </.button>
          <.button
            id="review-prev"
            phx-click="review_prev"
            disabled={@review_index <= 0}
            title="Previous position"
          >
            ←
          </.button>
          <.button
            id="review-next"
            phx-click="review_next"
            disabled={@review_index >= length(@line)}
            title="Next position"
          >
            →
          </.button>
          <.button
            id="review-end"
            phx-click="review_end"
            disabled={@review_index >= length(@line)}
            title="Go to end"
          >
            {">>"}
          </.button>
        </div>

        <div class="flex flex-wrap gap-2">
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

      <div class="relative w-48">
        <div class="absolute inset-0 flex flex-col gap-3">
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
              <p class="flex items-center justify-between gap-2 font-semibold">
                <span>{turn_label(@status, @awaiting_reply)}</span>
                <span class="text-xs font-normal text-muted">
                  You play {colour_name(@endgame.color)}
                </span>
              </p>
            </div>

            <div class="rounded-lg bg-canvas-raised p-3 text-sm">
              <%= cond do %>
                <% @status == :loading -> %>
                  <p class="text-muted">Loading tablebase…</p>
                <% @status == :blocked -> %>
                  <p class="font-semibold text-error">Tablebase unavailable</p>
                  <p class="text-error">{@blocked_reason}</p>
                <% @status == :solved -> %>
                  <p class="font-semibold text-success-text">
                    {if @endgame.result == :draw, do: "Draw held!", else: "Solved!"}
                  </p>
                <% @status == :failed -> %>
                  <p class="font-semibold text-error">Failed</p>
                  <p class="text-error">
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
                  <p class="text-muted">Opponent is replying…</p>
                <% @last_grade == :optimal -> %>
                  <p class="font-semibold text-success-text">Optimal move</p>
                <% @last_grade == :winning -> %>
                  <p class="font-semibold text-warning">
                    {if @endgame.result == :draw,
                      do: "Keeps the draw — but not the sharpest",
                      else: "Winning — but not the sharpest"}
                  </p>
                <% @last_grade == :losing -> %>
                  <p class="font-semibold text-error">
                    {if @endgame.result == :draw,
                      do: "Losing move — this loses the draw",
                      else: "Losing move — this throws away the win"}
                  </p>
                <% @last_grade == :unknown -> %>
                  <p class="font-semibold text-muted">Could not grade that move</p>
                <% true -> %>
                  <p class="text-muted">Make a move to have it graded.</p>
              <% end %>
              <p :if={@status in [:solved, :failed]} class="mt-1 text-xs text-muted">
                Puzzle rating: {round(@endgame.rating)}
              </p>
            </div>

            <div
              id="move-list"
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
            <tr
              :for={move <- moves}
              phx-click="review_move"
              phx-value-uci={move.uci}
              class="cursor-pointer hover:bg-base-200"
              title={"Play #{move.san}"}
            >
              <td class={["py-0.5 pr-2", class]}>{move.san}</td>
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
      {"Losing", "text-error", :loss},
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

  defp display_plies(true, line, _plies), do: line
  defp display_plies(false, _line, plies), do: plies

  defp turn_label(:playing, false), do: "Your move"
  defp turn_label(:playing, true), do: "Opponent's move"
  defp turn_label(:solved, _awaiting_reply), do: "Solved"
  defp turn_label(:failed, _awaiting_reply), do: "Finished"
  defp turn_label(:blocked, _awaiting_reply), do: "Unavailable"
  defp turn_label(_status, _awaiting_reply), do: "Loading…"

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
  defp grade_class(:winning), do: "text-warning"
  defp grade_class(:losing), do: "text-error"
  defp grade_class(_), do: "text-body"

  defp grade_label(nil, _result), do: nil
  defp grade_label(:optimal, _result), do: "Optimal move"
  defp grade_label(:winning, :draw), do: "Keeps the draw — but not the sharpest"
  defp grade_label(:winning, _result), do: "Winning — but not the sharpest"
  defp grade_label(:losing, :draw), do: "Loses the draw"
  defp grade_label(:losing, _result), do: "Throws away the win"
  defp grade_label(:unknown, _result), do: "Not graded"
end
