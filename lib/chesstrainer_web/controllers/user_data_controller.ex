defmodule ChesstrainerWeb.UserDataController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Attempts

  @columns ~w(played_at puzzle public_code color result outcome rated_at)

  def export(conn, %{"format" => format}) when format in ["csv", "json"] do
    attempts = Attempts.list_attempts_for_user(conn.assigns.current_scope.user.id)
    filename = "lucid-chess-attempts-#{Date.utc_today()}.#{format}"

    conn
    |> put_resp_content_type(content_type(format))
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, body(format, attempts))
  end

  def export(conn, _params), do: send_resp(conn, 404, "Unknown export format")

  defp body("csv", attempts), do: attempts |> Enum.map(&row/1) |> to_csv()

  defp body("json", attempts) do
    attempts
    |> Enum.map(&attempt_map/1)
    |> Jason.encode!(pretty: true)
  end

  defp attempt_map(attempt) do
    %{
      played_at: DateTime.to_iso8601(attempt.inserted_at),
      puzzle: attempt.endgame.key,
      public_code: attempt.endgame.public_code,
      color: attempt.endgame.color,
      result: attempt.endgame.result,
      outcome: attempt.outcome,
      rated_at: attempt.rated_at && DateTime.to_iso8601(attempt.rated_at)
    }
  end

  defp row(attempt) do
    [
      DateTime.to_iso8601(attempt.inserted_at),
      attempt.endgame.key,
      attempt.endgame.public_code,
      attempt.endgame.color,
      attempt.endgame.result,
      attempt.outcome,
      attempt.rated_at && DateTime.to_iso8601(attempt.rated_at)
    ]
  end

  defp to_csv(rows) do
    [@columns | rows]
    |> Enum.map_join("\n", fn row -> Enum.map_join(row, ",", &csv_field/1) end)
    |> Kernel.<>("\n")
  end

  defp csv_field(nil), do: ""

  defp csv_field(value) do
    value = to_string(value)

    if String.contains?(value, [",", "\"", "\n"]) do
      ~s("#{String.replace(value, "\"", "\"\"")}")
    else
      value
    end
  end

  defp content_type("csv"), do: "text/csv"
  defp content_type("json"), do: "application/json"
end
