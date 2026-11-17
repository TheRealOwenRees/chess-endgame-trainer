defmodule Chesstrainer.BrandingTest do
  use ExUnit.Case, async: false

  alias Chesstrainer.Branding

  describe "discord_invite_url/0" do
    setup do
      previous = Application.get_env(:chesstrainer, :branding)
      on_exit(fn -> restore(:branding, previous) end)
      :ok
    end

    test "passes a full URL through" do
      put_branding(discord_invite: "https://discord.gg/abc123")

      assert Branding.discord_invite_url() == "https://discord.gg/abc123"
    end

    test "expands a bare invite code" do
      put_branding(discord_invite: " abc123 ")

      assert Branding.discord_invite_url() == "https://discord.gg/abc123"
    end

    test "returns nil when the invite is blank" do
      put_branding(discord_invite: "")

      assert Branding.discord_invite_url() == nil
    end
  end

  defp put_branding(overrides) do
    config = Application.get_env(:chesstrainer, :branding, [])
    Application.put_env(:chesstrainer, :branding, Keyword.merge(config, overrides))
  end

  defp restore(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore(key, value), do: Application.put_env(:chesstrainer, key, value)
end
