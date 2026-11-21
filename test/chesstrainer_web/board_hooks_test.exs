defmodule ChesstrainerWeb.BoardHooksTest do
  use ExUnit.Case, async: true

  @hooks Path.expand("../../assets/js/hooks", __DIR__)

  test "board hooks stay silent and never inject markup" do
    hooks = Path.wildcard(Path.join(@hooks, "*.js"))
    assert hooks != []

    for path <- hooks do
      source = File.read!(path)

      refute source =~ "alert(", "#{path} must not call alert()"
      refute source =~ "innerHTML", "#{path} must not assign innerHTML"
      refute source =~ "console.", "#{path} must not log to the console"
    end
  end
end
