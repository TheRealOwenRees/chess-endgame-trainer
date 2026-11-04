defmodule ChesstrainerWeb.LandingComponents do
  @moduledoc """
  Presentational primitives for the marketing landing page.

  Kept separate from `ChesstrainerWeb.CoreComponents`: the landing page uses a
  distinct pill-button language, while CoreComponents provides the compact
  admin and auth UI.
  """
  use Phoenix.Component

  alias Chesstrainer.FEN

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
  Renders a static board preview for the landing page.

  Accepts an endgame map with `:fen`, `:color` and `:key`; falls back to a
  neutral position when no endgame is given. For an interactive board inside a
  LiveView, use `board_grid/1` directly.
  """
  attr :endgame, :map, default: nil

  def board_preview(assigns) do
    endgame = assigns.endgame

    assigns =
      assign(assigns,
        fen: fen_for(endgame),
        turn: turn_label(endgame),
        title: title(endgame)
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
        <span class="time-pill">∞</span>
      </div>

      <.board_grid fen={@fen} orientation={:white} />

      <div class="board-caption">
        <div>
          <span>Today’s position</span>
          <strong>{@title}</strong>
        </div>
        <button type="button" aria-label="Reset selected square">Reset</button>
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

  def board_grid(assigns) do
    rows = FEN.board(assigns.fen) || FEN.board(@fallback_fen)
    squares = board_squares(rows, assigns.orientation, assigns.selected, assigns.targets)

    assigns = assign(assigns, :squares, squares)

    ~H"""
    <div class="chessboard" aria-label="Chess position">
      <%= for square <- @squares do %>
        <button
          type="button"
          class={[
            "square",
            if(square.light, do: "light", else: "dark"),
            square.selected? && "selected",
            square.target? && "target"
          ]}
          phx-click={@interactive && "square"}
          phx-value-square={@interactive && square.key}
          disabled={@interactive && @disabled}
          aria-label={square_label(square)}
        >
          <span :if={square.label_rank} class="rank">{square.rank}</span>
          <span :if={square.label_file} class="file">{square.file}</span>
          <span
            :if={square.piece}
            class={["piece", if(square.white, do: "white-piece", else: "black-piece")]}
          >
            {square.glyph}
          </span>
        </button>
      <% end %>
    </div>
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

  defp square_label(%{piece: piece} = square) when is_binary(piece) do
    "#{square.key}, #{square.glyph}"
  end

  defp square_label(square), do: square.key

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
end
