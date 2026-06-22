defmodule ChesstrainerWeb.Board.SquareComponent do
  @moduledoc """
  Renders a single chess square with optional piece and highlighting.
  """
  use Phoenix.Component
  import ChesstrainerWeb.Board.PieceComponent

  attr :file, :atom, required: true
  attr :rank, :integer, required: true
  attr :piece, :any, default: nil
  attr :files_list, :list, required: true
  attr :move_from_square, :any, default: nil
  attr :myself, :any, required: true

  def square(assigns) do
    current_square = {assigns.file, assigns.rank}

    assigns =
      assigns
      |> assign(:highlight_square, current_square === assigns.move_from_square)

    ~H"""
    <div
      class={[
        "w-12 h-12 flex items-center justify-center",
        background(
          Enum.find_index(@files_list, fn f -> f == @file end),
          @rank - 1
        ),
        highlight_square(@highlight_square)
      ]}
      phx-click="square-click"
      phx-value-file={@file}
      phx-value-rank={@rank}
      phx-value-type="move"
      phx-target={@myself}
    >
      <.piece piece={@piece} class="w-10 h-10" />
    </div>
    """
  end

  def background(file_idx, rank_idx) when rem(file_idx + rank_idx, 2) != 0, do: "bg-boardwhite"
  def background(_, _), do: "bg-boardblack"

  def highlight_square(true), do: "ring-inset ring-2 ring-yellow-400"
  def highlight_square(false), do: ""
end
