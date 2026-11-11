defmodule ChesstrainerWeb.UserSessionControllerTest do
  use ChesstrainerWeb.ConnCase, async: false

  @moduletag :capture_log

  import Chesstrainer.AccountsFixtures
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  alias ChesstrainerWeb.LoginThrottle

  setup do
    LoginThrottle.reset()
    %{user: user_fixture()}
  end

  describe "POST /users/log-in - email or username and password" do
    test "logs the user in with their email", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.username
      assert response =~ ~p"/users/profile"
      assert response =~ ~p"/users/log-out"
    end

    test "logs the user in with their username", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_chesstrainer_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invalid email, username or password"

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "does not log in an unconfirmed user and resends confirmation instructions once", %{
      conn: conn
    } do
      user = unconfirmed_user_fixture()

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invalid email, username or password"

      assert redirected_to(conn) == ~p"/users/log-in"
      assert_email_sent(subject: "Confirmation instructions")

      second =
        post(build_conn(), ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      refute get_session(second, :user_token)
      refute_email_sent()
    end

    test "blocks further attempts after the login limit is reached", %{
      conn: conn,
      user: user
    } do
      for _ <- 1..LoginThrottle.max_per_login() do
        blocked =
          post(conn, ~p"/users/log-in", %{
            "user" => %{"email" => user.email, "password" => "wrong password"}
          })

        assert Phoenix.Flash.get(blocked.assigns.flash, :error) ==
                 "Invalid email, username or password"
      end

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Too many attempts. Try again in 15 minutes."

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "the address bucket blocks spraying many logins", %{conn: conn, user: user} do
      for index <- 1..LoginThrottle.max_per_ip() do
        blocked =
          post(conn, ~p"/users/log-in", %{
            "user" => %{
              "email" => "unknown#{index}@example.com",
              "password" => "wrong password"
            }
          })

        assert Phoenix.Flash.get(blocked.assigns.flash, :error) ==
                 "Invalid email, username or password"
      end

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many attempts."
    end

    test "a successful login clears the login bucket", %{conn: conn, user: user} do
      for _ <- 1..(LoginThrottle.max_per_login() - 1) do
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "wrong password"}
        })
      end

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)

      post(build_conn(), ~p"/users/log-in", %{
        "user" => %{"email" => user.email, "password" => "wrong password"}
      })

      conn =
        post(build_conn(), ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
    end

    test "the admin login uses the same throttle", %{conn: conn, user: user} do
      for _ <- 1..LoginThrottle.max_per_login() do
        post(conn, ~p"/admin/log-in", %{
          "user" => %{"email" => user.email, "password" => "wrong password"}
        })
      end

      conn =
        post(conn, ~p"/admin/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many attempts."
    end

    test "log events contain no raw address or password", %{conn: conn, user: user} do
      log =
        capture_log(
          [format: "$message $metadata\n", metadata: [:ip, :reason]],
          fn ->
            post(conn, ~p"/users/log-in", %{
              "user" => %{"email" => user.email, "password" => "secret-wrong-password"}
            })
          end
        )

      assert log =~ "auth.login.failed"
      assert log =~ "invalid_credentials"
      refute log =~ "127.0.0.1"
      refute log =~ "secret-wrong-password"
      refute log =~ user.email
    end

    test "a throttled request logs auth.login.throttled", %{conn: conn, user: user} do
      for _ <- 1..LoginThrottle.max_per_login() do
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "wrong password"}
        })
      end

      log =
        capture_log(
          [format: "$message $metadata\n", metadata: [:ip, :reason]],
          fn ->
            post(conn, ~p"/users/log-in", %{
              "user" => %{"email" => user.email, "password" => valid_user_password()}
            })
          end
        )

      assert log =~ "auth.login.throttled"
      assert log =~ "login"
      refute log =~ "127.0.0.1"
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
