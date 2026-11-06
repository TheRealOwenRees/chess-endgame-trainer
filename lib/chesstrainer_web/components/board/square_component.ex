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
  attr :myself, :any, default: nil
  attr :interactive, :boolean, default: true

  def square(assigns) do
    current_square = {assigns.file, assigns.rank}

    assigns =
      assigns
      |> assign(:highlight_square, current_square === assigns.move_from_square)

    ~H"""
    <div
      class={[
        "w-full aspect-square flex items-center justify-center",
        background(
          Enum.find_index(@files_list, fn f -> f == @file end),
          @rank - 1
        ),
        highlight_square(@highlight_square)
      ]}
      phx-click={@interactive && "square-click"}
      phx-value-file={@interactive && @file}
      phx-value-rank={@interactive && @rank}
      phx-value-type={@interactive && "move"}
      phx-target={@interactive && @myself}
    >
      <.piece piece={@piece} class="w-[83%] h-[83%]" />
    </div>
    """
  end

  def background(file_idx, rank_idx) when rem(file_idx + rank_idx, 2) != 0, do: "bg-boardwhite"
  def background(_, _), do: "bg-boardblack"

  def highlight_square(true), do: "ring-inset ring-2 ring-yellow-400"
  def highlight_square(false), do: ""
end
