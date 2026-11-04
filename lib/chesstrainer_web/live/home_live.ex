defmodule ChesstrainerWeb.HomeLive do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames

  @impl true
  def mount(_params, _session, socket) do
    endgames = Endgames.curated_endgames()

    {:ok,
     socket
     |> assign(:endgames, endgames)
     |> assign(:active_endgame, List.first(endgames))}
  end

  @impl true
  def handle_event("select_endgame", %{"code" => code}, socket) do
    case Enum.find(socket.assigns.endgames, &(&1.public_code == code)) do
      nil -> {:noreply, socket}
      endgame -> {:noreply, assign(socket, :active_endgame, endgame)}
    end
  end

  def handle_event("select_first", _params, socket) do
    case List.first(socket.assigns.endgames) do
      nil -> {:noreply, socket}
      endgame -> {:noreply, assign(socket, :active_endgame, endgame)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <main>
      <section class="hero">
        <div class="hero-copy">
          <div class="eyebrow"></div>
          <h1>
            Learn to see the <em>winning move.</em>
          </h1>
          <p>
            Short, focused endgame sessions that build the instincts you need
            when every move matters.
          </p>
          <div class="hero-actions">
            <div class="rating-note">
              <span class="avatar-stack">
                <i>♟</i>
                <i>♙</i>
                <i>♜</i>
              </span>
              <span>
                <strong>12,400+</strong> players training
              </span>
            </div>
          </div>
        </div>
        <div class="board-stage" id="trainer">
          <div class="coral-orbit" />
          <div class="mint-orbit" />
          <.live_component
            module={ChesstrainerWeb.HomeBoardComponent}
            id="home-board"
            endgame={@active_endgame}
          />
          <div class="streak-card">
            <span>♨</span>
            <div>
              <strong>7 day streak</strong>
              <small>Keep it going</small>
            </div>
          </div>
        </div>
      </section>

      <section class="learning-strip" id="method">
        <p>Built for the part of chess that decides everything.</p>
        <div class="stat">
          <strong>10</strong>
          <span>minutes a day</span>
        </div>
        <div class="stat">
          <strong>240+</strong>
          <span>curated positions</span>
        </div>
        <div class="stat">
          <strong>3.2×</strong>
          <span>faster pattern recall</span>
        </div>
      </section>

      <section class="puzzle-section" id="puzzles">
        <div class="section-heading">
          <div>
            <span class="section-kicker">Choose your challenge</span>
            <h2>
              One position. <br /> One clear idea.
            </h2>
          </div>
          <p>
            No noise, no endless variations. Each exercise teaches a pattern
            you’ll recognize over the board.
          </p>
        </div>
        <div class="puzzle-grid">
          <%= for {endgame, index} <- Enum.with_index(@endgames) do %>
            <.puzzle_card
              endgame={endgame}
              index={index}
              active={@active_endgame && endgame.id == @active_endgame.id}
            />
          <% end %>
        </div>
      </section>

      <section class="progress-banner" id="progress">
        <div>
          <span class="section-kicker">A calmer way to improve</span>
          <h2>
            Make the endgame <br /> your strongest phase.
          </h2>
        </div>
        <.pill_button variant={:light} href="#trainer" phx-click="select_first">
          Begin with the basics <.icon_arrow />
        </.pill_button>
      </section>
    </main>
    """
  end
end
