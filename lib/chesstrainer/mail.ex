defmodule Chesstrainer.Mail do
  @moduledoc """
  House rules for every outgoing email.

  Notifiers build the message body and hand it here, so the sender identity,
  reply-to address, SES configuration set and the test redirect are applied in
  exactly one place and no sender can forget them.

  The From address lives on the `mail.` subdomain so transactional mail is
  distinct from the addresses that receive mail on the apex domain. SES
  verification of the parent domain covers the subdomain, so no separate
  identity is required for the From header to be accepted.
  """

  alias Chesstrainer.Branding
  alias Chesstrainer.Mailer

  @default_configuration_set "my-first-configuration-set"

  @doc """
  Applies the house rules and delivers the email.

  Returns `{:ok, email}` so notifiers can report the message they sent.
  """
  def deliver(%Swoosh.Email{} = email) do
    email = prepare(email)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Applies the house rules without delivering.

  Exposed so tooling (such as `mix mail.check`) can inspect or send the exact
  message the application would send.
  """
  def prepare(%Swoosh.Email{} = email) do
    email
    |> Swoosh.Email.from({Branding.name(), Branding.mail_from()})
    |> Swoosh.Email.reply_to(Branding.support_email())
    |> Swoosh.Email.put_provider_option(:configuration_set_name, configuration_set())
    |> redirect()
  end

  defp configuration_set do
    Application.get_env(:chesstrainer, :ses_configuration_set, @default_configuration_set)
  end

  # Rewrites every recipient to one address so a staging or production smoke
  # test can send through real SES without reaching users. The original
  # recipients stay in the subject and in an `X-Original-To` header so the
  # redirected message explains itself.
  defp redirect(email) do
    case Application.get_env(:chesstrainer, :mail_redirect_to) do
      address when is_binary(address) and address != "" ->
        originals = recipients(email)

        require Logger

        Logger.warning("mail redirect: #{Enum.join(originals, ", ")} -> #{address}")

        %{email | to: [{"", address}], cc: [], bcc: []}
        |> Swoosh.Email.header("X-Original-To", Enum.join(originals, ", "))
        |> Swoosh.Email.subject("[→ #{Enum.join(originals, ", ")}] #{email.subject}")

      _unset ->
        email
    end
  end

  defp recipients(email) do
    [email.to, email.cc, email.bcc]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn
      {_name, address} -> address
      address when is_binary(address) -> address
    end)
  end
end
