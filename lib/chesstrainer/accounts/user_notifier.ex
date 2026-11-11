defmodule Chesstrainer.Accounts.UserNotifier do
  import Swoosh.Email

  alias Chesstrainer.Branding
  alias Chesstrainer.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({Branding.name(), Branding.mail_from()})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver an invitation to choose a password.

  Admins create the account without a password; the invitation link uses the
  same reset-password token flow so the recipient can set one.
  """
  def deliver_invite_instructions(user, url) do
    deliver(user.email, "You're invited to #{Branding.name()}", """

    ==============================

    Hi #{user.username},

    An administrator has created an account for you on #{Branding.name()}.

    Choose your password by visiting the URL below:

    #{url}

    If you weren't expecting this invitation, please ignore this email.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
