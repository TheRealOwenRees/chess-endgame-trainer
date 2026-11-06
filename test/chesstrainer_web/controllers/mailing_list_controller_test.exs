defmodule ChesstrainerWeb.MailingListControllerTest do
  use ChesstrainerWeb.ConnCase, async: true

  alias Chesstrainer.MailingList.Subscriber
  alias Chesstrainer.Repo

  @salt "mailing_list_confirm"

  describe "POST /mailing-list" do
    test "sends a confirmation email for a new address", %{conn: conn} do
      conn = post(conn, ~p"/mailing-list", subscriber: %{email: "player@example.com"})

      assert redirected_to(conn) == "/#mailing-list"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your inbox"
      assert %Subscriber{confirmed_at: nil} = Repo.get_by(Subscriber, email: "player@example.com")

      assert_received {:email, email}
      assert email.subject == "Confirm your mailing list subscription"
      assert email.text_body =~ "/mailing-list/confirm/"
    end

    test "resends confirmation for an address that has not confirmed yet", %{conn: conn} do
      post(conn, ~p"/mailing-list", subscriber: %{email: "player@example.com"})
      assert_received {:email, _email}

      conn = post(build_conn(), ~p"/mailing-list", subscriber: %{email: "player@example.com"})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your inbox"
      assert_received {:email, _email}
      assert Repo.aggregate(Subscriber, :count) == 1
    end

    test "does not email an address that has already confirmed", %{conn: conn} do
      post(conn, ~p"/mailing-list", subscriber: %{email: "player@example.com"})
      assert_received {:email, email}
      get(build_conn(), "/mailing-list/confirm/#{extract_token(email)}")

      conn = post(build_conn(), ~p"/mailing-list", subscriber: %{email: "player@example.com"})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "already on the mailing list"
      refute_received {:email, _email}
    end

    test "reports an invalid address", %{conn: conn} do
      conn = post(conn, ~p"/mailing-list", subscriber: %{email: "not an email"})

      assert redirected_to(conn) == "/#mailing-list"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "valid email address"
      refute_received {:email, _email}
      assert Repo.aggregate(Subscriber, :count) == 0
    end

    test "reports a missing email", %{conn: conn} do
      conn = post(conn, ~p"/mailing-list", %{})

      assert redirected_to(conn) == "/#mailing-list"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "valid email address"
    end
  end

  describe "GET /mailing-list/confirm/:token" do
    test "confirms the subscription from the emailed link", %{conn: conn} do
      post(conn, ~p"/mailing-list", subscriber: %{email: "player@example.com"})
      assert_received {:email, email}

      conn = get(build_conn(), "/mailing-list/confirm/#{extract_token(email)}")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "subscription is confirmed"
      assert redirected_to(conn) == "/#mailing-list"

      assert %Subscriber{confirmed_at: confirmed_at} =
               Repo.get_by(Subscriber, email: "player@example.com")

      assert confirmed_at
    end

    test "rejects an invalid token", %{conn: conn} do
      conn = get(conn, "/mailing-list/confirm/oops")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
      assert redirected_to(conn) == "/#mailing-list"
    end

    test "rejects an expired token", %{conn: conn} do
      signed_at = System.system_time(:second) - 8 * 24 * 60 * 60

      token =
        Phoenix.Token.sign(ChesstrainerWeb.Endpoint, @salt, "player@example.com",
          signed_at: signed_at
        )

      conn = get(conn, "/mailing-list/confirm/#{token}")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end

    test "reports an address that is no longer on the list", %{conn: conn} do
      token = Phoenix.Token.sign(ChesstrainerWeb.Endpoint, @salt, "nobody@example.com")

      conn = get(conn, "/mailing-list/confirm/#{token}")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "no longer on the mailing list"
    end
  end

  defp extract_token(email) do
    [_, token] = Regex.run(~r{/mailing-list/confirm/(\S+)}, email.text_body)
    token
  end
end
