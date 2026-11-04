defmodule ChesstrainerWeb.PageController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Endgames

  def home(conn, _params) do
    board_session =
      case Endgames.random_endgame() do
        %{public_code: code} -> %{"home_endgame_code" => code}
        _ -> %{}
      end

    render(conn, :home, board_session: board_session)
  end
end
