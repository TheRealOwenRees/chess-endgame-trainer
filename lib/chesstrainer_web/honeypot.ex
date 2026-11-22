defmodule ChesstrainerWeb.Honeypot do
  @moduledoc """
  Off-screen form field used to catch naive form-filling bots.

  Render the field with `<.honeypot />` and check the submitted nested params
  with `filled?/1`. The field is hidden with CSS (not `display: none`) and kept
  out of the tab order, so humans never notice it while bots that fill every
  input do.

  A filled field must take the same success path a real submission takes --
  never show an error, or the bot learns which field to skip.
  """

  @field "company"

  @doc """
  True when the honeypot field was submitted with any value.

  Pass the form's nested params (the value under `"user"`, `"subscriber"`, and
  so on), not the top-level params map.
  """
  @spec filled?(map()) :: boolean()
  def filled?(params) when is_map(params), do: Map.get(params, @field) not in [nil, ""]
  def filled?(_params), do: false
end
