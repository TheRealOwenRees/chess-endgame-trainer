defmodule Mix.Tasks.Mail.Check do
  use Mix.Task

  @shortdoc "Send test email through the configured mailer and SES simulators"

  @moduledoc """
  Sends a test message through the application mailer, applying the same house
  rules as real mail: From identity, Reply-To, and the SES configuration set.

      mix mail.check --to you@example.com

  By default it also sends to the SES mailbox simulator addresses so bounce and
  complaint wiring can be exercised without touching a real inbox:

    * `success@simulator.amazonses.com`
    * `bounce@simulator.amazonses.com`
    * `complaint@simulator.amazonses.com`

  The simulators only do something when the mailer is the SES adapter. Pass
  `--no-simulators` to send only to the given address.

  If `MAIL_REDIRECT_TO` is set, every recipient is rewritten to that address
  first (including the simulators), so this task cannot reach users even in
  production.
  """

  alias Chesstrainer.Mail

  @simulators [
    "success@simulator.amazonses.com",
    "bounce@simulator.amazonses.com",
    "complaint@simulator.amazonses.com"
  ]

  @impl true
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [to: :string, simulators: :boolean])

    recipient =
      opts[:to] ||
        Mix.raise("pass the address to check: mix mail.check --to you@example.com")

    Mix.Task.run("app.start")

    targets = if opts[:simulators] == false, do: [recipient], else: [recipient | @simulators]

    Mix.shell().info("adapter: #{inspect(adapter())}")

    if redirect(), do: Mix.shell().info("redirect: every message goes to #{redirect()}")

    Enum.each(targets, &send_message/1)
  end

  defp send_message(recipient) do
    email =
      Swoosh.Email.new()
      |> Swoosh.Email.to(recipient)
      |> Swoosh.Email.subject("Mail check #{DateTime.utc_now() |> DateTime.to_iso8601()}")
      |> Swoosh.Email.text_body(
        "This is a delivery check from the chess trainer. " <>
          "If you can read it, the mailer, sender identity and configuration set are wired up."
      )
      |> Mail.prepare()

    case Chesstrainer.Mailer.deliver(email) do
      {:ok, metadata} ->
        Mix.shell().info("sent    #{recipient} #{format_metadata(metadata)}")

      {:error, reason} ->
        Mix.shell().error("failed  #{recipient} #{inspect(reason)}")
    end
  end

  defp format_metadata(%{id: id}) when is_binary(id), do: "(message id #{id})"
  defp format_metadata(_metadata), do: ""

  defp adapter do
    :chesstrainer
    |> Application.get_env(Chesstrainer.Mailer, [])
    |> Keyword.get(:adapter)
  end

  defp redirect, do: Application.get_env(:chesstrainer, :mail_redirect_to)
end
