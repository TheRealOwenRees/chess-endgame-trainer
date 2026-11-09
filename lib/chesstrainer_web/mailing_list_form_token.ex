defmodule ChesstrainerWeb.MailingListFormToken do
  @moduledoc """
  Signed timestamp hidden in the mailing-list signup form.

  Used as a timing check: submissions that arrive faster than a human could
  plausibly fill the form are rejected. The timestamp is signed so a bot
  cannot simply make one up.
  """

  @salt "mailing_list_form"
  @max_age 2 * 60 * 60
  @min_seconds 2

  @type verify_result :: :ok | :too_fast | :expired | :invalid

  @doc "Signs the current time for the hidden form field."
  def sign, do: sign(System.system_time(:second))

  @doc false
  def sign(signed_at) when is_integer(signed_at) do
    Phoenix.Token.sign(ChesstrainerWeb.Endpoint, @salt, signed_at, signed_at: signed_at)
  end

  @doc "Checks a submitted form token."
  @spec verify(term()) :: verify_result()
  def verify(token) when is_binary(token) do
    now = System.system_time(:second)

    case Phoenix.Token.verify(ChesstrainerWeb.Endpoint, @salt, token, max_age: @max_age) do
      {:ok, signed_at} when is_integer(signed_at) and now - signed_at >= @min_seconds -> :ok
      {:ok, _signed_at} -> :too_fast
      {:error, :expired} -> :expired
      {:error, _reason} -> :invalid
    end
  end

  def verify(_token), do: :invalid
end
