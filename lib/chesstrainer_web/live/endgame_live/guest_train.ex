defmodule ChesstrainerWeb.EndgameLive.GuestTrain do
  @moduledoc """
  Public training: play random endgame puzzles without an account.

  There is no difficulty selection and no session — each puzzle is drawn from
  the whole pool and "Next puzzle" draws another. Anonymous visitors get a
  daily budget of puzzles (see `Chesstrainer.GuestLimits`); when it runs out the
  page asks them to sign up. Signed-in visitors are sent to `/train`, where they
  can pick a difficulty. Move grading, opponent replies and review come from
  `ChesstrainerWeb.EndgameLive.PlayCore`.
  """

  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.GuestLimits
  alias ChesstrainerWeb.ClientAddress
  alias ChesstrainerWeb.EndgameLive.PlayCore
  alias ChesstrainerWeb.PlayComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Train
        <:subtitle>
          <%= if @endgame do %>
            A random endgame puzzle — {@endgame.color
            |> Atom.to_string()
            |> String.capitalize()} to move, rating {round(@endgame.rating)}.
          <% else %>
            Random endgame puzzles.
          <% end %>
          <span
            :if={@guest_remaining != nil}
            id="guest-remaining"
            class="mt-1 block text-xs text-muted"
          >
            {remaining_label(@guest_remaining, @limit)}
          </span>
          <span class="mt-1 block text-xs text-muted">
            <.link navigate={~p"/users/register"}>Create a free account</.link>
            to track your rating and train at your level.
          </span>
        </:subtitle>
      </.header>

      <section
        :if={@limit_reached}
        id="guest-limit"
        class="rounded-xl border border-hairline bg-canvas-raised p-6"
      >
        <h2 class="text-lg font-semibold">
          You've used your {@limit} free puzzles today
        </h2>
        <p class="mt-1 text-sm text-muted">
          Sign up for a free account to keep training. Your rating is tracked, so
          the puzzles match your level.
        </p>
        <p class="mt-1 text-sm text-muted">
          Free guest puzzles reset at 00:00 UTC (in {format_wait(@limit_reached)}).
        </p>
        <div class="mt-4 flex flex-wrap gap-2">
          <.button id="guest-sign-up" navigate={~p"/users/register"} variant="primary">
            <.icon name="hero-user-plus" /> Sign up free
          </.button>
          <.button navigate={~p"/users/log-in"}>Log in</.button>
        </div>
      </section>

      <PlayComponents.play_surface
        :if={@endgame}
        session={is_nil(@limit_reached)}
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
      />

      <p :if={@loading} class="text-base-content/70">Picking a random puzzle…</p>

      <p
        :if={not @loading and is_nil(@endgame) and is_nil(@limit_reached)}
        class="text-base-content/70"
      >
        No endgames are available yet. Please check back soon.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :limit, GuestLimits.limit())

    cond do
      signed_in?(socket) ->
        {:ok, redirect(socket, to: ~p"/train")}

      connected?(socket) ->
        take_puzzle(socket, ClientAddress.from_socket(socket))

      true ->
        {:ok,
         socket
         |> assign(:loading, true)
         |> assign(:endgame, nil)
         |> assign(:guest_remaining, nil)
         |> assign(:limit_reached, nil)
         |> assign(:guest_address, nil)}
    end
  end

  @impl true
  def handle_event("next_puzzle", _params, socket) do
    case GuestLimits.take(socket.assigns.guest_address) do
      {:ok, remaining} ->
        endgame =
          Endgames.random_endgame(exclude_ids: [socket.assigns.endgame.id]) ||
            Endgames.random_endgame()

        case endgame do
          nil ->
            {:noreply, put_flash(socket, :info, "No more puzzles are available right now.")}

          endgame ->
            {:noreply,
             socket
             |> assign(:guest_remaining, remaining)
             |> PlayCore.init(endgame, page_title: "Train")}
        end

      {:limit_reached, retry_ms} ->
        {:noreply,
         socket
         |> assign(:guest_remaining, nil)
         |> assign(:limit_reached, retry_ms)}
    end
  end

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

  defp take_puzzle(socket, address) do
    case GuestLimits.take(address) do
      {:ok, remaining} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:guest_address, address)
          |> assign(:guest_remaining, remaining)
          |> assign(:limit_reached, nil)

        {:ok, load_random_endgame(socket)}

      {:limit_reached, retry_ms} ->
        {:ok,
         socket
         |> assign(:loading, false)
         |> assign(:guest_address, address)
         |> assign(:guest_remaining, nil)
         |> assign(:limit_reached, retry_ms)
         |> assign(:endgame, nil)}
    end
  end

  defp load_random_endgame(socket) do
    case Endgames.random_endgame() do
      nil -> assign(socket, :endgame, nil)
      endgame -> PlayCore.init(socket, endgame, page_title: "Train")
    end
  end

  defp signed_in?(socket) do
    case socket.assigns.current_scope do
      %{user: %{}} -> true
      _ -> false
    end
  end

  defp remaining_label(0, _limit), do: "Last free puzzle today"

  defp remaining_label(remaining, limit),
    do: "#{remaining} of #{limit} free puzzles left today"

  defp format_wait(ms) when is_integer(ms) do
    minutes = max(div(ms + 59_999, 60_000), 1)
    hours = div(minutes, 60)
    mins = rem(minutes, 60)

    if hours > 0, do: "#{hours}h #{mins}m", else: "#{mins}m"
  end
end
