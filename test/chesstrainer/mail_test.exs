defmodule Chesstrainer.MailTest do
  use ExUnit.Case, async: false

  import Swoosh.TestAssertions

  alias Chesstrainer.Branding
  alias Chesstrainer.Mail

  setup do
    previous_redirect = Application.get_env(:chesstrainer, :mail_redirect_to)
    previous_set = Application.get_env(:chesstrainer, :ses_configuration_set)

    on_exit(fn ->
      restore_env(:mail_redirect_to, previous_redirect)
      restore_env(:ses_configuration_set, previous_set)
    end)

    :ok
  end

  defp simple_email(recipient \\ "player@example.com") do
    Swoosh.Email.new()
    |> Swoosh.Email.to(recipient)
    |> Swoosh.Email.subject("Confirmation instructions")
    |> Swoosh.Email.text_body("Hello")
  end

  test "sends from the no-reply address on the mail subdomain" do
    {:ok, email} = Mail.deliver(simple_email())

    assert email.from == {Branding.name(), "no-reply@mail.innersquare.app"}
    assert email.reply_to == {"", "support@innersquare.app"}
  end

  test "stamps the SES configuration set on the provider options" do
    {:ok, email} = Mail.deliver(simple_email())

    assert email.provider_options[:configuration_set_name] == "my-first-configuration-set"
  end

  test "the configuration set can be overridden by config" do
    Application.put_env(:chesstrainer, :ses_configuration_set, "staging-set")

    {:ok, email} = Mail.deliver(simple_email())

    assert email.provider_options[:configuration_set_name] == "staging-set"
  end

  test "redirects every recipient when a test address is configured" do
    Application.put_env(:chesstrainer, :mail_redirect_to, "ops@example.com")

    email = simple_email("player@example.com")

    {:ok, sent} = Mail.deliver(email)

    assert sent.to == [{"", "ops@example.com"}]
    assert sent.bcc == []
    assert sent.cc == []
    assert sent.subject == "[→ player@example.com] Confirmation instructions"
    assert {"X-Original-To", "player@example.com"} in sent.headers
  end

  test "delivers the message it returns" do
    {:ok, email} = Mail.deliver(simple_email())

    assert_email_sent(to: "player@example.com", subject: "Confirmation instructions")
    assert email.to == [{"", "player@example.com"}]
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
