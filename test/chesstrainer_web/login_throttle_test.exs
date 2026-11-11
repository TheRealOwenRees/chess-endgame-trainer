defmodule ChesstrainerWeb.LoginThrottleTest do
  use ExUnit.Case, async: false

  alias ChesstrainerWeb.LoginThrottle

  @address {203, 0, 113, 7}
  @other_address {198, 51, 100, 9}
  @login "someone@example.com"

  setup do
    LoginThrottle.reset()
    :ok
  end

  test "uses the tightened limits and a 15 minute window" do
    assert LoginThrottle.max_per_login() == 5
    assert LoginThrottle.max_per_ip() == 10
    assert LoginThrottle.window_ms() == :timer.minutes(15)
  end

  test "blocks the next attempt after the login limit is reached" do
    for _ <- 1..(LoginThrottle.max_per_login() - 1) do
      assert :ok = LoginThrottle.record_failure(@address, @login)
    end

    assert :ok = LoginThrottle.check(@address, @login)

    assert :ok = LoginThrottle.record_failure(@address, @login)

    assert {:throttled, :login, retry_in_ms} = LoginThrottle.check(@address, @login)
    assert retry_in_ms > 0
  end

  test "blocks the next attempt after the address limit is reached across logins" do
    for index <- 1..LoginThrottle.max_per_ip() do
      assert :ok = LoginThrottle.record_failure(@address, "user#{index}@example.com")
    end

    assert {:throttled, :ip, retry_in_ms} =
             LoginThrottle.check(@address, "fresh@example.com")

    assert retry_in_ms > 0
  end

  test "a successful login clears only the login bucket" do
    for _ <- 1..(LoginThrottle.max_per_login() - 1) do
      LoginThrottle.record_failure(@address, @login)
    end

    assert :ok = LoginThrottle.record_success(@login)

    for _ <- 1..(LoginThrottle.max_per_login() - 1) do
      LoginThrottle.record_failure(@address, @login)
    end

    assert :ok = LoginThrottle.check(@address, @login)
  end

  test "addresses are independent" do
    for index <- 1..LoginThrottle.max_per_ip() do
      LoginThrottle.record_failure(@address, "user#{index}@example.com")
    end

    assert {:throttled, :ip, _} = LoginThrottle.check(@address, "fresh@example.com")
    assert :ok = LoginThrottle.check(@other_address, "fresh@example.com")
  end

  test "log fingerprints are stable and do not expose the address" do
    fingerprint = LoginThrottle.fingerprint(@address)

    assert is_binary(fingerprint)
    assert fingerprint == LoginThrottle.fingerprint(@address)
    refute fingerprint =~ "203.0.113.7"
  end

  test "confirmation resends are claimed at most once per cooldown" do
    assert LoginThrottle.claim_confirmation_resend(@login)
    refute LoginThrottle.claim_confirmation_resend(@login)
    assert LoginThrottle.claim_confirmation_resend("another@example.com")
  end

  test "reset clears every bucket" do
    for index <- 1..LoginThrottle.max_per_ip() do
      LoginThrottle.record_failure(@address, "user#{index}@example.com")
    end

    assert {:throttled, :ip, _} = LoginThrottle.check(@address, "fresh@example.com")

    LoginThrottle.reset()

    assert :ok = LoginThrottle.check(@address, "fresh@example.com")
  end
end
