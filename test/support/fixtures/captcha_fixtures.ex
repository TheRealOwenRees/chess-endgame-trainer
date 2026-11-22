defmodule ChesstrainerWeb.CaptchaFixtures do
  @moduledoc """
  Test helpers for producing ALTCHA proof-of-work payloads.
  """

  @algorithm "PBKDF2/SHA-256"
  # Keep the proof-of-work cheap so tests stay fast.
  @cost 50

  @doc """
  Returns a base64-encoded ALTCHA payload signed with the configured secret.

  Options:

    * `:secret` - sign with a different secret (to exercise rejection paths)
    * `:expires_at` - challenge expiry, defaults to one minute from now
  """
  def altcha_token(opts \\ []) do
    secret = Keyword.get_lazy(opts, :secret, &configured_secret/0)

    expires_at =
      Keyword.get_lazy(opts, :expires_at, fn -> DateTime.add(DateTime.utc_now(), 60) end)

    challenge =
      Altcha.V2.create_challenge(%Altcha.V2.CreateChallengeOptions{
        algorithm: @algorithm,
        cost: @cost,
        expires_at: expires_at,
        hmac_signature_secret: secret
      })

    solution = Altcha.V2.solve_challenge(%Altcha.V2.SolveChallengeOptions{challenge: challenge})
    payload = %Altcha.V2.Payload{challenge: challenge, solution: solution}

    payload
    |> Altcha.V2.Payload.to_map()
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp configured_secret do
    Application.fetch_env!(:altcha, Altcha.Plug.Challenge)[:hmac_signature_secret]
  end
end
