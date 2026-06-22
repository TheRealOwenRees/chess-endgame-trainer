defmodule ChesstrainerWeb.Board.PieceComponent do
  @moduledoc """
  Chess pieces component
  """
  use Phoenix.Component

  attr :piece, :any, required: true
  attr :class, :string, default: ""

  def piece(assigns) do
    assigns = assign(assigns, :path, piece_path(assigns.piece))

    ~H"""
    <%= if @path do %>
      <img src={@path} class={@class} />
    <% end %>
    """
  end

  def piece_path({:king, :white, _square}), do: "/images/pieces/white/king.svg"
  def piece_path({:queen, :white, _square}), do: "/images/pieces/white/queen.svg"
  def piece_path({:rook, :white, _square}), do: "/images/pieces/white/rook.svg"
  def piece_path({:bishop, :white, _square}), do: "/images/pieces/white/bishop.svg"
  def piece_path({:knight, :white, _square}), do: "/images/pieces/white/knight.svg"
  def piece_path({:pawn, :white, _square}), do: "/images/pieces/white/pawn.svg"
  def piece_path({:king, :black, _square}), do: "/images/pieces/black/king.svg"
  def piece_path({:queen, :black, _square}), do: "/images/pieces/black/queen.svg"
  def piece_path({:rook, :black, _square}), do: "/images/pieces/black/rook.svg"
  def piece_path({:bishop, :black, _square}), do: "/images/pieces/black/bishop.svg"
  def piece_path({:knight, :black, _square}), do: "/images/pieces/black/knight.svg"
  def piece_path({:pawn, :black, _square}), do: "/images/pieces/black/pawn.svg"
  def piece_path(_), do: nil
end
