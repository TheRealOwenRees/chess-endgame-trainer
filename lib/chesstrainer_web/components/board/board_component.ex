defmodule ChesstrainerWeb.Board.BoardComponent do
  @moduledoc """
  Chess board component
  """

  use Phoenix.Component
  import ChesstrainerWeb.Board.SquareComponent

  attr :game, :map, required: true

  attr :myself, :any, default: nil

  attr :interactive, :boolean,
    default: true,
    doc: "emit square-click events (only useful inside a board LiveView)"

  attr :class, :string,
    default: "w-[388px] mt-6",
    doc: "sizing and spacing for the board wrapper"

  def board(assigns) do
    files_list = [:a, :b, :c, :d, :e, :f, :g, :h]

    assigns =
      assigns
      |> assign(:files_list, files_list)
      |> assign(
        :files,
        case assigns.game.orientation do
          :white -> files_list
          :black -> Enum.reverse(files_list)
        end
      )
      |> assign(
        :ranks,
        case assigns.game.orientation do
          :white -> Enum.reverse(1..8)
          :black -> 1..8
        end
      )

    ~H"""
    <div class={["m-auto left-0 right-0", @class]}>
      <div class="border border-2 border-zinc-700 grid grid-rows-8 grid-cols-8">
        <%= for rank <- @ranks do %>
          <%= for file <- @files do %>
            <% square = {file, rank} %>
            <% piece = Map.get(@game.board, square) %>
            <.square
              file={file}
              rank={rank}
              piece={piece}
              files_list={@files_list}
              move_from_square={@game.move_from_square}
              myself={@myself}
              interactive={@interactive}
            />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
