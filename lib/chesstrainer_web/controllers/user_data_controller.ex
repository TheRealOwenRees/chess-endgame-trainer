defmodule ChesstrainerWeb.UserDataController do
  use ChesstrainerWeb, :controller

  require Logger

  alias Chesstrainer.Attempts
  alias Chesstrainer.Branding

  @user_columns ~w(user_username user_email user_rating user_rating_deviation user_plan user_joined_at)
  @attempt_columns ~w(played_at puzzle public_code color result outcome rated_at)
  @columns @user_columns ++ @attempt_columns

  def export(conn, %{"format" => format}) when format in ["csv", "json"] do
    user = conn.assigns.current_scope.user

    try do
      attempts = Attempts.list_attempts_for_user(user.id)
      filename = "lucid-chess-data-#{Date.utc_today()}.#{format}"

      conn
      |> put_resp_content_type(content_type(format))
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, body(format, user, attempts))
    rescue
      exception ->
        export_failed(conn, Exception.message(exception))
    catch
      :exit, reason ->
        export_failed(conn, inspect(reason))
    end
  end

  def export(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(ChesstrainerWeb.ErrorHTML)
    |> render("404.html")
  end

  defp export_failed(conn, reason) do
    Logger.error("profile.export_failed", reason: reason)

    conn
    |> put_flash(
      :error,
      "We couldn't build your export. Try again; if it keeps failing, email #{Branding.support_email()}."
    )
    |> redirect(to: ~p"/users/profile/data")
  end

  defp body("csv", user, attempts), do: to_csv(user, attempts)

  defp body("json", user, attempts) do
    %{user: user_map(user), attempts: Enum.map(attempts, &attempt_map/1)}
    |> Jason.encode!(pretty: true)
  end

  defp user_map(user) do
    %{
      username: user.username,
      email: user.email,
      rating: user.rating,
      rating_deviation: user.rating_deviation,
      plan: user.plan,
      joined_at: DateTime.to_iso8601(user.inserted_at)
    }
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

  defp to_csv(user, attempts) do
    rows =
      case attempts do
        [] -> [user_row(user) ++ empty_attempt_row()]
        attempts -> Enum.map(attempts, &(user_row(user) ++ attempt_row(&1)))
      end

    [@columns | rows]
    |> Enum.map_join("\n", fn row -> Enum.map_join(row, ",", &csv_field/1) end)
    |> Kernel.<>("\n")
  end

  defp user_row(user) do
    [
      user.username,
      user.email,
      user.rating,
      user.rating_deviation,
      user.plan,
      DateTime.to_iso8601(user.inserted_at)
    ]
  end

  defp attempt_row(attempt) do
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

  defp empty_attempt_row, do: List.duplicate(nil, length(@attempt_columns))

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
