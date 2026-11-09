defmodule ChesstrainerWeb.MailingListControllerTest do
  use ChesstrainerWeb.ConnCase, async: false

  alias Chesstrainer.MailingList
  alias Chesstrainer.MailingList.Subscriber
  alias Chesstrainer.Repo
  alias ChesstrainerWeb.MailingListFormToken

  @salt "mailing_list_confirm"

  describe "POST /mailing-list" do
    test "sends a confirmation email for a new address", %{conn: conn} do
      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: form_token()}
        )

      assert redirected_to(conn) == "/#mailing-list"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your inbox"
      assert %Subscriber{confirmed_at: nil} = Repo.get_by(Subscriber, email: "player@example.com")

      assert_received {:email, email}
      assert email.subject == "Confirm your mailing list subscription"
      assert email.text_body =~ "/mailing-list/confirm/"
      assert email.reply_to == {"", "support@innersquare.app"}
    end

    test "re-confirms an address that previously unsubscribed", %{conn: conn} do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      {:ok, _subscriber} = MailingList.confirm("player@example.com")
      {:ok, _subscriber} = MailingList.unsubscribe("player@example.com")

      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: form_token()}
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your inbox"

      assert_received {:email, email}
      get(build_conn(), "/mailing-list/confirm/#{extract_token(email)}")

      subscriber = Repo.get_by(Subscriber, email: "player@example.com")
      assert subscriber.confirmed_at
      assert subscriber.unsubscribed_at == nil
      assert MailingList.count_confirmed_subscribers() == 1
    end

    test "does not resend confirmation while the cooldown is active", %{conn: conn} do
      post(conn, ~p"/mailing-list",
        subscriber: %{email: "player@example.com", form_token: form_token()}
      )

      assert_received {:email, _email}

      conn =
        post(build_conn(), ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: form_token()}
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your inbox"
      refute_received {:email, _email}
      assert Repo.aggregate(Subscriber, :count) == 1
    end

    test "resends confirmation after the cooldown", %{conn: conn} do
      post(conn, ~p"/mailing-list",
        subscriber: %{email: "player@example.com", form_token: form_token()}
      )

      assert_received {:email, _email}

      subscriber = Repo.get_by(Subscriber, email: "player@example.com")

      subscriber
      |> Ecto.Changeset.change(
        confirmation_sent_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
      )
      |> Repo.update!()

      post(conn, ~p"/mailing-list",
        subscriber: %{email: "player@example.com", form_token: form_token()}
      )

      assert_received {:email, _email}
    end

    test "silently accepts a honeypot submission", %{conn: conn} do
      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{
            email: "player@example.com",
            company: "spam.example",
            form_token: form_token()
          }
        )

      assert redirected_to(conn) == "/#mailing-list"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your inbox"
      refute_received {:email, _email}
      assert Repo.aggregate(Subscriber, :count) == 0
    end

    test "rejects a form token submitted too quickly", %{conn: conn} do
      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: MailingListFormToken.sign()}
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "refresh the page"
      refute_received {:email, _email}
      assert Repo.aggregate(Subscriber, :count) == 0
    end

    test "rejects an expired form token", %{conn: conn} do
      token = MailingListFormToken.sign(System.system_time(:second) - 3 * 60 * 60)

      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: token}
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "refresh the page"
      refute_received {:email, _email}
    end

    test "rejects an invalid form token", %{conn: conn} do
      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: "oops"}
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "refresh the page"
      refute_received {:email, _email}
    end

    test "does not email an address that has already confirmed", %{conn: conn} do
      post(conn, ~p"/mailing-list",
        subscriber: %{email: "player@example.com", form_token: form_token()}
      )

      assert_received {:email, email}
      get(build_conn(), "/mailing-list/confirm/#{extract_token(email)}")

      conn =
        post(build_conn(), ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: form_token()}
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "already on the mailing list"
      refute_received {:email, _email}
    end

    test "reports an invalid address", %{conn: conn} do
      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "not an email", form_token: form_token()}
        )

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

    test "rejects signups when the mailing list is disabled", %{conn: conn} do
      previous = Application.get_env(:chesstrainer, :mailing_list_enabled)
      on_exit(fn -> restore_env(:mailing_list_enabled, previous) end)
      Application.put_env(:chesstrainer, :mailing_list_enabled, false)

      conn =
        post(conn, ~p"/mailing-list",
          subscriber: %{email: "player@example.com", form_token: form_token()}
        )

      assert redirected_to(conn) == "/#mailing-list"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "isn't open yet"
      refute_received {:email, _email}
      assert Repo.aggregate(Subscriber, :count) == 0
    end
  end

  describe "GET /mailing-list/confirm/:token" do
    test "confirms the subscription from the emailed link", %{conn: conn} do
      post(conn, ~p"/mailing-list",
        subscriber: %{email: "player@example.com", form_token: form_token()}
      )

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

  defp form_token do
    MailingListFormToken.sign(System.system_time(:second) - 5)
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
