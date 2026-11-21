defmodule ChesstrainerWeb.TypographyTest do
  use ExUnit.Case, async: true

  @css Path.expand("../../assets/css", __DIR__)

  test "stylesheet font sizes are relative" do
    stylesheets = Path.wildcard(Path.join(@css, "**/*.css"))
    assert stylesheets != []

    for path <- stylesheets do
      source = File.read!(path)

      refute source =~ ~r/font-size:\s*[^;]*\b\d+(?:\.\d+)?px\b/,
             "#{path} must not declare a pixel font-size"
    end
  end
end
