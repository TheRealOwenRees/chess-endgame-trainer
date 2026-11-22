defmodule ChesstrainerWeb.Captcha do
  @moduledoc """
  Verifies the ALTCHA proof-of-work payload submitted with a form.

  The client widget adds an `altcha` field to the form; treat any missing or
  malformed payload as a failed verification.
  """

  @doc """
  Returns true when the event payload carries a valid, unexpired ALTCHA solution.
  """
  @spec verified?(map()) :: boolean()
  def verified?(%{"altcha" => token}) do
    secret = Application.get_env(:altcha, Altcha.Plug.Challenge, [])[:hmac_signature_secret]

    case Altcha.V2.decode_payload(token) do
      %Altcha.V2.Payload{} = payload ->
        Altcha.V2.verify_solution(%Altcha.V2.VerifySolutionOptions{
          challenge: payload.challenge,
          solution: payload.solution,
          hmac_signature_secret: secret
        }).verified

      nil ->
        false
    end
  end

  def verified?(_params), do: false
end
