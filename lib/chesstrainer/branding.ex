defmodule Chesstrainer.Branding do
  @moduledoc """
  Public-facing branding, read from `config :chesstrainer, :branding`.

  Keeps display names out of templates and controllers so the site can be
  renamed in one place. Values are read at runtime, so a deploy can override
  them without recompiling.
  """

  @defaults [
    name: "Inner Square Chess",
    wordmark: "INNERSQUARE",
    tagline: "Endgame Trainer",
    support_email: "support@innersquare.app",
    mail_from: "no-reply@innersquare.app"
  ]

  @doc "The display name, e.g. `\"Lucid Chess\"`."
  def name, do: get(:name)

  @doc "The short wordmark used in the navbar and footer."
  def wordmark, do: get(:wordmark)

  @doc "The tagline appended to the home title, e.g. `\"Endgame Trainer\"`."
  def tagline, do: get(:tagline)

  @doc "The support address shown in legal pages and used as the mailer reply-to."
  def support_email, do: get(:support_email)

  @doc "The From address used for outgoing mail."
  def mail_from, do: get(:mail_from)

  @doc "The home-page title, e.g. `\"Lucid Chess — Endgame Trainer\"`."
  def home_title, do: "#{name()} — #{tagline()}"

  @doc "Builds a page title, e.g. `title(\"Privacy Policy\")`."
  def title(page), do: "#{page} — #{name()}"

  defp get(key) do
    config = Application.get_env(:chesstrainer, :branding) || []
    Keyword.get(config, key, Keyword.fetch!(@defaults, key))
  end
end
