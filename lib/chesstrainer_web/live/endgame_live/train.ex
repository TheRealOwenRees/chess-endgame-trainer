defmodule ChesstrainerWeb.EndgameLive.Train do
  @moduledoc """
  A training session: choose a difficulty, then play a run of puzzles in place.

  The session (difficulty, start time, rating baseline, completed count and
  timing) lives only in this LiveView. Each puzzle's move grading, opponent
  reply and review come from `ChesstrainerWeb.EndgameLive.PlayCore`.
  """

  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Puzzles
  alias ChesstrainerWeb.EndgameLive.PlayCore
  alias ChesstrainerWeb.PlayComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Train
        <:subtitle>
          <%= if @session do %>
            {difficulty_label(@session.difficulty)} · Play a run of endgame puzzles.
          <% else %>
            Choose a difficulty to start a session.
          <% end %>
        </:subtitle>
        <:actions>
          <.button :if={@session} phx-click="stop_session">
            <.icon name="hero-x-mark" /> Stop session
          </.button>
          <.button
            :if={Scope.premium?(@current_scope)}
            id="puzzle-search"
            navigate={~p"/endgames"}
          >
            <.icon name="hero-magnifying-glass" /> Puzzle Search
          </.button>
        </:actions>
      </.header>

      <%= if @session do %>
        <div
          id="session-bar"
          class="mb-4 flex flex-wrap items-center gap-x-6 gap-y-2 rounded-lg bg-canvas-raised p-3 text-sm"
        >
          <span>
            <span class="text-muted">Difficulty</span>
            <span class="font-semibold">{difficulty_label(@session.difficulty)}</span>
          </span>
          <span>
            <span class="text-muted">Time</span>
            <span
              id={"session-clock-#{@session.started_at_ms}"}
              phx-hook="SessionClock"
              data-started-at={@session.started_at_ms}
              class="font-mono"
            >
              {format_duration(elapsed_ms(@session))}
            </span>
          </span>
          <span>
            <span class="text-muted">Avg/puzzle</span>
            <span class="font-mono">{format_duration(avg_ms(@session))}</span>
          </span>
          <span class="flex items-center gap-2">
            <span class="text-muted">Rating</span>
            <span id="session-rating" class="font-mono font-semibold">{round(@user_rating)}</span>
            <.rating_change
              :if={@session.count > 0}
              id="session-rating-change"
              delta={net_gain(@session, @user_rating)}
            />
          </span>
        </div>

        <PlayComponents.play_surface
          session={true}
          endgame={@endgame}
          fen={@fen}
          status={@status}
          blocked_reason={@blocked_reason}
          best_move={@best_move}
          plies={@plies}
          line={@line}
          reviewing={@reviewing}
          review_index={@review_index}
          review_tablebase={@review_tablebase}
          review_blocked={@review_blocked}
          awaiting_reply={@awaiting_reply}
          last_grade={@last_grade}
          awaiting_best_line={@awaiting_best_line}
          move_input={@move_input}
          move_input_error={@move_input_error}
          last_check={@last_check}
          last_checkmate={@last_checkmate}
          rating={@user_rating}
          rating_delta={@last_rating_delta}
        />
      <% else %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div id="difficulty-picker" class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
            <div
              :if={@last_session}
              id="last-session"
              class="mb-4 rounded-lg bg-canvas-raised p-3 text-sm"
            >
              <p class="mb-1 font-semibold">Last session</p>
              <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs">
                <span>
                  <span class="text-muted">Difficulty</span>
                  <span class="font-semibold">{difficulty_label(@last_session.difficulty)}</span>
                </span>
                <span>
                  <span class="text-muted">Time</span>
                  <span class="font-mono">{format_duration(@last_session.duration_ms)}</span>
                </span>
                <span>
                  <span class="text-muted">Puzzles</span>
                  <span class="font-mono">{@last_session.count}</span>
                </span>
                <span>
                  <span class="text-muted">Avg/puzzle</span>
                  <span class="font-mono">{format_duration(@last_session.avg_ms)}</span>
                </span>
                <span class="flex items-center gap-2">
                  <span class="text-muted">Rating</span>
                  <span class="font-mono font-semibold">{round(@last_session.rating)}</span>
                  <.rating_change
                    :if={@last_session.count > 0}
                    delta={@last_session.gain}
                  />
                </span>
              </div>
            </div>

            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-lg font-semibold">Choose a difficulty</h2>
                <p class="mt-1 text-sm text-muted">
                  Difficulty bands are ±{Puzzles.band_width()} around your rating.
                </p>
              </div>
              <.link
                id="close-difficulty"
                navigate={~p"/"}
                aria-label="Close and return home"
                class="rounded-md p-1 text-muted hover:bg-base-200 hover:text-base-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </.link>
            </div>
            <div class="mt-4">
              <.rating_guide rating={@user_rating} deviation={@user_deviation} />
            </div>
            <div class="mt-4 grid gap-2">
              <%= for {difficulty, label, description} <- difficulty_options(@user_rating) do %>
                <.button
                  id={"difficulty-#{difficulty}"}
                  phx-click="start_session"
                  phx-value-difficulty={Atom.to_string(difficulty)}
                  variant={if difficulty == :medium, do: "primary", else: "secondary"}
                  class="w-full justify-between"
                >
                  <span>{label}</span>
                  <span class="text-xs font-normal opacity-80">{description}</span>
                </.button>
              <% end %>
            </div>
            <.button navigate={~p"/"} variant="ghost" class="mt-2 w-full justify-center">
              <.icon name="hero-arrow-left" />Return Home
            </.button>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Train")
     |> assign(:session, nil)
     |> assign(:last_session, nil)
     |> assign(:puzzle_started_mono, nil)
     |> assign(:puzzle_counted, false)
     |> assign(:user_rating, socket.assigns.current_scope.user.rating)
     |> assign(:user_deviation, socket.assigns.current_scope.user.rating_deviation)}
  end

  @impl true
  def handle_event("start_session", %{"difficulty" => difficulty}, socket) do
    difficulty = parse_difficulty(difficulty)

    case Puzzles.next_endgame(selection_user(socket), difficulty) do
      nil ->
        {:noreply, put_flash(socket, :error, "No puzzles are available right now.")}

      endgame ->
        session = %{
          difficulty: difficulty,
          started_at_ms: System.system_time(:millisecond),
          baseline: socket.assigns.user_rating,
          count: 0,
          sum_ms: 0
        }

        socket =
          socket
          |> assign(:session, session)
          |> assign(:puzzle_started_mono, System.monotonic_time(:millisecond))
          |> assign(:puzzle_counted, false)
          |> assign(:last_rating_delta, nil)
          |> PlayCore.init(endgame, page_title: "Train")

        {:noreply, socket}
    end
  end

  def handle_event("next_puzzle", _params, socket) do
    session = socket.assigns.session

    if session do
      case Puzzles.next_endgame(selection_user(socket), session.difficulty,
             exclude_ids: [socket.assigns.endgame.id]
           ) do
        nil ->
          {:noreply, put_flash(socket, :info, "No more puzzles at this difficulty.")}

        endgame ->
          socket =
            socket
            |> assign(:puzzle_started_mono, System.monotonic_time(:millisecond))
            |> assign(:puzzle_counted, false)
            |> assign(:last_rating_delta, nil)
            |> PlayCore.init(endgame, page_title: "Train")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("stop_session", _params, socket) do
    socket =
      case socket.assigns.session do
        nil -> socket
        session -> assign(socket, :last_session, summarise(session, socket.assigns.user_rating))
      end

    {:noreply, assign(socket, :session, nil)}
  end

  def handle_event("endgame_move_played", params, socket) do
    {:noreply, socket} = PlayCore.move_played(socket, params)
    {:noreply, account_completion(socket)}
  end

  def handle_event("submit_move", params, socket), do: PlayCore.submit_move(socket, params)

  def handle_event("move_input", params, socket), do: PlayCore.move_input_changed(socket, params)

  def handle_event("move_input_error", params, socket),
    do: PlayCore.move_input_error(socket, params)

  def handle_event("opponent_reply_applied", params, socket) do
    {:noreply, socket} = PlayCore.opponent_reply_applied(socket, params)
    {:noreply, account_completion(socket)}
  end

  def handle_event("chess_fen_invalid", params, socket),
    do: PlayCore.fen_invalid(socket, params)

  def handle_event("reset", _params, socket), do: PlayCore.reset(socket)

  def handle_event("review", _params, socket), do: PlayCore.review(socket)

  def handle_event("review_prev", _params, socket), do: PlayCore.review_prev(socket)

  def handle_event("review_next", _params, socket), do: PlayCore.review_next(socket)

  def handle_event("review_step", %{"index" => index}, socket),
    do: PlayCore.review_step(socket, index)

  def handle_event("review_start", _params, socket), do: PlayCore.review_start(socket)

  def handle_event("review_end", _params, socket), do: PlayCore.review_end(socket)

  def handle_event("review_move", params, socket), do: PlayCore.review_move(socket, params)

  def handle_event("play_best_line", _params, socket), do: PlayCore.play_best_line(socket)

  def handle_event("best_line_move_applied", params, socket),
    do: PlayCore.best_line_move_applied(socket, params)

  def handle_event("back_to_game", _params, socket), do: PlayCore.back_to_game(socket)

  # A completed puzzle contributes one first-attempt time to the average. A
  # retry happens after this point and is deliberately ignored.
  defp account_completion(socket) do
    session = socket.assigns.session
    status = socket.assigns.status
    started = socket.assigns.puzzle_started_mono

    if session && not socket.assigns.puzzle_counted && is_integer(started) &&
         status in [:solved, :failed] do
      duration = max(System.monotonic_time(:millisecond) - started, 0)
      count = session.count + 1
      sum_ms = session.sum_ms + duration

      socket
      |> assign(:session, %{session | count: count, sum_ms: sum_ms})
      |> assign(:puzzle_counted, true)
    else
      socket
    end
  end

  # Selection uses the rating this session has reached, not the stale rating the
  # scope carried in at mount.
  defp selection_user(socket) do
    user = socket.assigns.current_scope.user
    %{user | rating: socket.assigns.user_rating || user.rating}
  end

  defp summarise(session, rating) do
    %{
      difficulty: session.difficulty,
      duration_ms: elapsed_ms(session),
      count: session.count,
      avg_ms: avg_ms(session),
      gain: net_gain(session, rating),
      rating: rating
    }
  end

  defp parse_difficulty(value) when value in ~w(easy medium hard),
    do: String.to_existing_atom(value)

  defp parse_difficulty(_value), do: :medium

  defp difficulty_options(rating) do
    width = Puzzles.band_width()

    [
      {:easy, "Easy", "below #{round(rating - width)}"},
      {:medium, "Medium", "#{round(rating - width)}–#{round(rating + width)}"},
      {:hard, "Hard", "above #{round(rating + width)}"}
    ]
  end

  defp difficulty_label(:easy), do: "Easy"
  defp difficulty_label(:medium), do: "Medium"
  defp difficulty_label(:hard), do: "Hard"

  defp net_gain(%{baseline: baseline}, rating) when is_number(rating), do: rating - baseline
  defp net_gain(_session, _rating), do: nil

  defp avg_ms(%{count: 0}), do: nil
  defp avg_ms(%{count: count, sum_ms: sum}), do: div(sum, count)

  defp elapsed_ms(%{started_at_ms: started_at}),
    do: max(System.system_time(:millisecond) - started_at, 0)

  defp format_duration(nil), do: "—"

  defp format_duration(ms) when is_integer(ms) do
    total = div(max(ms, 0), 1000)
    minutes = String.pad_leading(Integer.to_string(div(total, 60)), 2, "0")
    seconds = String.pad_leading(Integer.to_string(rem(total, 60)), 2, "0")
    "#{minutes}:#{seconds}"
  end
end
