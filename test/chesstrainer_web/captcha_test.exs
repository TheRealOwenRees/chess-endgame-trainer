defmodule ChesstrainerWeb.CaptchaTest do
  use ChesstrainerWeb.ConnCase, async: true

  import ChesstrainerWeb.CaptchaFixtures

  alias ChesstrainerWeb.Captcha

  describe "challenge endpoint" do
    test "serves a signed challenge", %{conn: conn} do
      conn = get(conn, ~p"/altcha/challenge")

      assert conn.status == 200

      assert %{"parameters" => %{"nonce" => _}, "signature" => signature} =
               Jason.decode!(conn.resp_body)

      assert is_binary(signature)
    end
  end

  describe "verified?/1" do
    test "accepts a solved challenge" do
      assert Captcha.verified?(%{"altcha" => altcha_token()})
    end

    test "rejects a payload with no solution" do
      refute Captcha.verified?(%{"user" => %{"email" => "player@example.com"}})
    end

    test "rejects an undecodable payload" do
      refute Captcha.verified?(%{"altcha" => "not-a-real-token"})
    end

    test "rejects a payload signed with a different secret" do
      refute Captcha.verified?(%{"altcha" => altcha_token(secret: "some-other-secret")})
    end

    test "rejects an expired challenge" do
      expired_at = DateTime.add(DateTime.utc_now(), -60)

      refute Captcha.verified?(%{"altcha" => altcha_token(expires_at: expired_at)})
    end
  end
end
