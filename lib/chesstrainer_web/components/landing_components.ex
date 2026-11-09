defmodule ChesstrainerWeb.LandingComponents do
  @moduledoc """
  Presentational primitives for the marketing landing page.

  Kept separate from `ChesstrainerWeb.CoreComponents`: the landing page uses a
  distinct pill-button language, while CoreComponents provides the compact
  admin and auth UI.
  """
  use Phoenix.Component

  import Phoenix.Controller, only: [get_csrf_token: 0]

  alias Chesstrainer.FEN
  alias Chesstrainer.Themes
  alias ChesstrainerWeb.Board.PositionText
  alias ChesstrainerWeb.MailingListFormToken

  @button_variants %{
    nav: "nav-cta",
    primary: "primary-button",
    light: "light-button"
  }

  @files ~w(a b c d e f g h)

  @piece_glyphs %{
    "K" => "♔",
    "Q" => "♕",
    "R" => "♖",
    "B" => "♗",
    "N" => "♘",
    "P" => "♙",
    "k" => "♚",
    "q" => "♛",
    "r" => "♜",
    "b" => "♝",
    "n" => "♞",
    "p" => "♟"
  }

  @fallback_fen "8/5k2/8/3K4/8/6R1/8/8 w - - 0 1"

  @doc """
  Renders a landing-page pill button.

  Renders a link when given `href`, `navigate`, or `patch`; otherwise a button.

  ## Examples

      <.pill_button variant={:nav} href="/#trainer">Start training</.pill_button>
      <.pill_button variant={:primary} phx-click="go">Go</.pill_button>
  """
  attr :rest, :global, include: ~w(href navigate patch method type disabled)
  attr :variant, :atom, values: [:nav, :primary, :light], default: :nav
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def pill_button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [Map.fetch!(@button_variants, assigns.variant), assigns.class])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders the mailing-list signup band.

  The form posts to `POST /mailing-list` and the controller redirects back to
  the `#mailing-list` anchor with a flash. Keeping it a plain form means the
  landing page needs no LiveView to collect an address.
  """
  def mailing_list_signup(assigns) do
    ~H"""
    <section class="mailing-list" id="mailing-list">
      <div class="mailing-list-copy">
        <span class="section-kicker">Mailing list</span>
        <h2>Stay in the loop.</h2>
        <p>
          Get occasional endgame ideas, new puzzles, and feature updates delivered to your inbox. (Please confirm your email after signing up.)
        </p>
      </div>

      <form action="/mailing-list" method="post" id="mailing-list-form" class="mailing-list-form">
        <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
        <input type="hidden" name="subscriber[form_token]" value={MailingListFormToken.sign()} />

        <div class="mailing-list-honeypot" aria-hidden="true">
          <label for="mailing-list-company">Company</label>
          <input
            id="mailing-list-company"
            type="text"
            name="subscriber[company]"
            tabindex="-1"
            autocomplete="off"
          />
        </div>

        <label for="mailing-list-email">Email address</label>
        <div class="mailing-list-row">
          <input
            id="mailing-list-email"
            type="email"
            name="subscriber[email]"
            placeholder="you@example.com"
            autocomplete="email"
            required
          />
          <.pill_button variant={:primary} type="submit">Join the list</.pill_button>
        </div>
      </form>
    </section>
    """
  end

  @doc """
  Renders a static board preview for the landing page.

  Accepts an endgame map with `:fen`, `:color` and `:key`; falls back to a
  neutral position when no endgame is given. For an interactive board inside a
  LiveView, use `board_grid/1` directly.
  """
  attr :endgame, :map, default: nil
  attr :date, :any, default: nil

  def board_preview(assigns) do
    endgame = assigns.endgame

    assigns =
      assign(assigns,
        fen: fen_for(endgame),
        turn: turn_label(endgame),
        title: title(endgame),
        themes: theme_names(endgame),
        orientation: orientation(endgame),
        date: Calendar.strftime(assigns.date || Date.utc_today(), "%d %b %Y")
      )

    ~H"""
    <div class="board-shell">
      <div class="board-topline">
        <div class="player">
          <span class="player-piece dark-piece">♚</span>
          <span>
            <small>To move</small>
            <strong>{@turn}</strong>
          </span>
        </div>
        <div>{@date}</div>
      </div>

      <.board_grid fen={@fen} orientation={@orientation} />

      <div class="board-caption">
        <div>
          <span>Today’s position</span>
          <strong>{@title}</strong>
          <small :if={@themes != []} class="board-themes">{Enum.join(@themes, " · ")}</small>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the squares of a chess position.

  Set `interactive` inside a LiveView to emit `phx-click="square"` events with
  `phx-value-square` (for example `"e4"`). `selected` and `targets` are square
  keys in algebraic notation.
  """
  attr :fen, :string, required: true
  attr :orientation, :atom, values: [:white, :black], default: :white
  attr :selected, :string, default: nil
  attr :targets, :list, default: []
  attr :interactive, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :target, :any, default: nil

  def board_grid(assigns) do
    rows = FEN.board(assigns.fen) || FEN.board(@fallback_fen)
    squares = board_squares(rows, assigns.orientation, assigns.selected, assigns.targets)

    assigns = assign(assigns, :squares, squares)

    ~H"""
    <div
      class="chessboard"
      role="img"
      aria-label={"Chess position. #{PositionText.summary(assigns.fen)}"}
    >
      <%= for square <- @squares do %>
        <div
          class={[
            "square",
            if(square.light, do: "light", else: "dark"),
            square.selected? && "selected",
            square.target? && "target"
          ]}
          aria-hidden="true"
        >
          <span :if={square.label_rank} class="rank">{square.rank}</span>
          <span :if={square.label_file} class="file">{square.file}</span>
          <span
            :if={square.piece}
            class={["piece", if(square.white, do: "white-piece", else: "black-piece")]}
          >
            {square.glyph}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a curated endgame card for the landing-page grid.

  The card links straight to the puzzle's player-facing play route.
  """
  attr :endgame, :map, required: true
  attr :index, :integer, required: true
  attr :active, :boolean, default: false

  def puzzle_card(assigns) do
    ~H"""
    <.link
      navigate={"/endgames/#{@endgame.public_code}/play"}
      class={["puzzle-card", @active && "active"]}
    >
      <span class="card-number">{card_number(@index)}</span>
      <span class="mini-piece">{mini_piece(@endgame)}</span>
      <span class="difficulty">{difficulty(@endgame.rating)}</span>
      <strong>{title(@endgame)}</strong>
      <small>{meta(@endgame)}</small>
      <span class="card-arrow"><.icon_arrow /></span>
    </.link>
    """
  end

  @doc """
  Formats a landing-page stat count.

  Counts below 100 are shown exactly. Larger counts are floored to the nearest
  hundred or thousand and suffixed with `+`, so the claim is never overstated.
  """
  def count_label(count) when is_integer(count) and count < 100 do
    Integer.to_string(count)
  end

  def count_label(count) when is_integer(count) and count < 1000 do
    "#{div(count, 100) * 100}+"
  end

  def count_label(count) when is_integer(count) do
    "#{div(count, 1000) * 1000}+"
  end

  @doc "The spark used by the landing-page eyebrow."
  def icon_spark(assigns) do
    ~H"""
    <svg aria-hidden="true" viewBox="0 0 20 20" fill="none">
      <path
        d="M10 1.75c.33 3.25 1.85 4.77 5.1 5.1-3.25.33-4.77 1.85-5.1 5.1-.33-3.25-1.85-4.77-5.1-5.1 3.25-.33 4.77-1.85 5.1-5.1Z"
        fill="currentColor"
      />
      <path
        d="M15.25 11.5c.18 1.8.95 2.57 2.75 2.75-1.8.18-2.57.95-2.75 2.75-.18-1.8-.95-2.57-2.75-2.75 1.8-.18 2.57-.95 2.75-2.75Z"
        fill="currentColor"
      />
    </svg>
    """
  end

  @doc "The arrow used by landing-page CTAs."
  def icon_arrow(assigns) do
    ~H"""
    <svg aria-hidden="true" viewBox="0 0 20 20" fill="none">
      <path
        d="M4 10h11m-4.5-4.5L15 10l-4.5 4.5"
        stroke="currentColor"
        stroke-width="1.7"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  defp board_squares(rows, orientation, selected, targets) do
    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, r} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {piece, c} ->
        rank = 8 - r
        file = Enum.at(@files, c)
        key = "#{file}#{rank}"

        %{
          key: key,
          rank: rank,
          file: file,
          file_index: c,
          light: rem(c + rank, 2) == 0,
          piece: piece,
          glyph: piece_glyph(piece),
          white: piece != nil and piece == String.upcase(piece),
          selected?: selected == key,
          target?: key in targets,
          label_rank: (orientation == :black and c == 7) or (orientation != :black and c == 0),
          label_file:
            (orientation == :black and rank == 8) or (orientation != :black and rank == 1)
        }
      end)
    end)
    |> Enum.sort_by(&display_key(&1, orientation))
  end

  defp display_key(square, :black), do: {square.rank - 1, 7 - square.file_index}
  defp display_key(square, _orientation), do: {8 - square.rank, square.file_index}

  defp piece_glyph(nil), do: nil
  defp piece_glyph(piece), do: Map.get(@piece_glyphs, piece)

  defp fen_for(%{fen: fen}) when is_binary(fen), do: fen
  defp fen_for(_endgame), do: @fallback_fen

  defp turn_label(:black), do: "Black"
  defp turn_label(:white), do: "White"
  defp turn_label(%{color: color}), do: turn_label(color)
  defp turn_label(%{fen: fen}) when is_binary(fen), do: turn_label(FEN.color_from_fen(fen))
  defp turn_label(_endgame), do: "White"

  defp title(%{key: key}) when is_binary(key) and key != "", do: key
  defp title(%{message: message}) when is_binary(message) and message != "", do: message
  defp title(_endgame), do: "Featured position"

  defp theme_names(%{themes: themes}) when is_list(themes), do: Themes.names(themes)
  defp theme_names(_endgame), do: []

  defp orientation(%{color: color}) when color in [:white, :black], do: color
  defp orientation(_endgame), do: :white

  defp card_number(index), do: (index + 1) |> Integer.to_string() |> String.pad_leading(2, "0")

  defp mini_piece(%{key: key}) when is_binary(key) do
    cond do
      String.contains?(key, "Q") -> "♛"
      String.contains?(key, "R") -> "♖"
      String.contains?(key, "B") -> "♗"
      String.contains?(key, "N") -> "♘"
      true -> "♙"
    end
  end

  defp mini_piece(_endgame), do: "♙"

  defp difficulty(rating) when is_number(rating) and rating < 1600, do: "Beginner"
  defp difficulty(rating) when is_number(rating) and rating < 1900, do: "Intermediate"
  defp difficulty(_rating), do: "Advanced"

  defp meta(%{themes: themes, rating: rating}) when is_list(themes) do
    case Themes.names(themes) do
      [] -> rating_label(rating)
      names -> Enum.join(names, " · ")
    end
  end

  defp meta(%{rating: rating}), do: rating_label(rating)

  defp rating_label(nil), do: "Unrated"
  defp rating_label(rating), do: "Rating #{round(rating)}"
end
