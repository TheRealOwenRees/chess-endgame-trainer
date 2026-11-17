defmodule Chesstrainer.MailingList.Notifier do
  @moduledoc """
  Emails for the mailing list.
  """

  import Swoosh.Email

  alias Chesstrainer.Branding
  alias Chesstrainer.Mail

  @doc """
  Delivers the confirmation email for a mailing-list subscription.
  """
  def deliver_confirmation_instructions(email, url) do
    deliver(email, "Confirm your mailing list subscription", """

    ==============================

    Hi #{email},

    You asked to receive occasional endgame tips and site news from
    #{Branding.name()}. Confirm your subscription by visiting the URL below:

    #{url}

    If you didn't ask for this, ignore this email and we won't add you.

    ==============================
    """)
  end

  defp deliver(recipient, subject, body) do
    new()
    |> to(recipient)
    |> subject(subject)
    |> text_body(body)
    |> Mail.deliver()
  end
end
