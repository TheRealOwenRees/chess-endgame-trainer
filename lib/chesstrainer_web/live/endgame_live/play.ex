defmodule ChesstrainerWeb.EndgameLive.Play do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Endgames
  alias ChesstrainerWeb.EndgameLive.PlayCore
  alias ChesstrainerWeb.PlayComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <header class="flex flex-wrap items-start justify-between gap-4 pb-4">
        <div>
          <h1 class="settings-header">Play endgame {@endgame.key}</h1>
          <p class="settings-subtitle mt-4">
            {@endgame.color |> Atom.to_string() |> String.capitalize()} to move · Rating: {round(
              @endgame.rating
            )} · Attempts: {@endgame.times_attempted ||
              0} · Solved: {@endgame.times_solved || 0}
          </p>
          <p class="text-xs text-muted flex items-center mt-1">
            <span>FEN: {@endgame.fen}</span>
            <button
              id="copy-fen-btn"
              type="button"
              phx-hook="CopyFen"
              data-fen={@endgame.fen}
              class="inline-flex items-center justify-center rounded p-1.5 cursor-pointer"
              title="Copy FEN to clipboard"
              aria-label="Copy FEN to clipboard"
            >
              <.icon name="hero-document-duplicate" class="w-3.5 h-3.5" />
            </button>
          </p>
        </div>
        <div class="flex flex-none gap-2">
          <.button :if={Scope.premium?(@current_scope)} navigate={~p"/endgames"}>
            <.icon name="hero-arrow-left" /> Back to endgames
          </.button>
          <.button :if={!Scope.premium?(@current_scope)} navigate={~p"/"}>
            <.icon name="hero-arrow-left" /> Back home
          </.button>
        </div>
      </header>

      <PlayComponents.play_surface
        endgame={@endgame}
        fen={@fen}
        status={@status}
        blocked={@blocked}
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

      <div :if={@user_rating} class="mb-4">
        <.rating_guide rating={@user_rating} deviation={@user_deviation} />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"public_code" => public_code}, _session, socket) do
    endgame = Endgames.get_endgame_by_public_code!(public_code)

    {:ok, PlayCore.init(socket, endgame)}
  end

  @impl true
  def handle_event("endgame_move_played", params, socket),
    do: PlayCore.move_played(socket, params)

  def handle_event("submit_move", params, socket), do: PlayCore.submit_move(socket, params)

  def handle_event("move_input", params, socket), do: PlayCore.move_input_changed(socket, params)

  def handle_event("move_input_error", params, socket),
    do: PlayCore.move_input_error(socket, params)

  def handle_event("opponent_reply_applied", params, socket),
    do: PlayCore.opponent_reply_applied(socket, params)

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
end
