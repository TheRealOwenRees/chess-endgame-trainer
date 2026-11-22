defmodule ChesstrainerWeb.HoneypotTest do
  use ExUnit.Case, async: true

  alias ChesstrainerWeb.Honeypot

  describe "filled?/1" do
    test "is false when the field is absent or blank" do
      refute Honeypot.filled?(%{})
      refute Honeypot.filled?(%{"company" => ""})
      refute Honeypot.filled?(%{"company" => nil})
    end

    test "is true when a bot fills the field" do
      assert Honeypot.filled?(%{"company" => "spam.example"})
    end

    test "is true for a repeated field" do
      assert Honeypot.filled?(%{"company" => ["spam.example"]})
    end

    test "is false for params that are not a map" do
      refute Honeypot.filled?("not a map")
    end
  end
end
