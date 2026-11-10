defmodule Chesstrainer.JSONLogFormatterTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.JSONLogFormatter

  @time 1_760_000_000_123_456

  describe "format/2" do
    test "emits one JSON line with timestamp, level, message and request id" do
      event = %{
        level: :info,
        msg: {:string, "hello"},
        meta: %{time: @time, request_id: "request-1"}
      }

      decoded = format_and_decode(event)

      assert decoded["timestamp"] ==
               @time |> DateTime.from_unix!(:microsecond) |> DateTime.to_iso8601()

      assert decoded["level"] == "info"
      assert decoded["message"] == "hello"
      assert decoded["request_id"] == "request-1"
    end

    test "includes access-line fields" do
      event = %{
        level: :info,
        msg: {:string, "GET /health 200 in 1.2ms"},
        meta: %{
          time: @time,
          request_id: "request-1",
          method: "GET",
          path: "/health",
          status: 200,
          duration_ms: 1.2
        }
      }

      decoded = format_and_decode(event)

      assert decoded["method"] == "GET"
      assert decoded["path"] == "/health"
      assert decoded["status"] == 200
      assert decoded["duration_ms"] == 1.2
      assert decoded["request_id"] == "request-1"
    end

    test "renders an exception's reason and stacktrace" do
      event = %{
        level: :error,
        msg: {:string, "boom"},
        meta: %{
          time: @time,
          exception: %RuntimeError{message: "bad thing"},
          stacktrace: stacktrace()
        }
      }

      decoded = format_and_decode(event)

      assert decoded["error"] == %{
               "kind" => "RuntimeError",
               "reason" => "bad thing",
               "stacktrace" => ["lib/foo.ex:10: Foo.bar/1"]
             }
    end

    test "renders an OTP crash report's reason and stacktrace" do
      event = %{
        level: :error,
        msg: {:report, %{label: :gen_server_terminate}},
        meta: %{
          time: @time,
          crash_reason: {%RuntimeError{message: "call boom"}, stacktrace()}
        }
      }

      decoded = format_and_decode(event)

      assert decoded["error"]["kind"] == "RuntimeError"
      assert decoded["error"]["reason"] == "call boom"
      assert decoded["error"]["stacktrace"] == ["lib/foo.ex:10: Foo.bar/1"]
    end

    test "redacts email addresses and credentials in metadata, params and the message" do
      event = %{
        level: :info,
        msg: {:string, "contact user@example.com"},
        meta: %{
          time: @time,
          email: "user@example.com",
          token: "secret-token",
          params: %{
            "user" => %{
              "email" => "user@example.com",
              "name" => "Ada"
            },
            "user@example.com" => %{"name" => "Keyed by email"}
          }
        }
      }

      decoded = format_and_decode(event)

      assert decoded["email"] == "[REDACTED]"
      assert decoded["token"] == "[REDACTED]"
      assert decoded["params"]["user"]["email"] == "[REDACTED]"
      assert decoded["params"]["user"]["name"] == "Ada"
      assert decoded["params"]["[REDACTED]"]["name"] == "Keyed by email"
      assert decoded["message"] == "contact [REDACTED]"
    end

    test "redacts credential assignments in the message" do
      event = %{
        level: :info,
        msg: {:string, "GET /reset token=abc123&next=/home"},
        meta: %{time: @time}
      }

      decoded = format_and_decode(event)

      assert decoded["message"] == "GET /reset token=[REDACTED]&next=/home"
    end

    test "sanitises non-JSON metadata instead of crashing" do
      event = %{
        level: :info,
        msg: {:string, "weird"},
        meta: %{
          time: @time,
          pid: self(),
          reference: make_ref(),
          tuple: {:ok, 1},
          charlist: ~c"hello",
          domain: [:bandit],
          invalid: <<0, 255>>
        }
      }

      decoded = format_and_decode(event)

      assert decoded["pid"] =~ "#PID"
      assert is_binary(decoded["reference"])
      assert decoded["tuple"] == ["ok", 1]
      assert decoded["charlist"] == "hello"
      assert decoded["domain"] == ["bandit"]
      assert decoded["invalid"] == "<<0, 255>>"
    end

    test "falls back to a JSON line when the message cannot be formatted" do
      event = %{
        level: :error,
        msg: {:report, %{label: :broken}},
        meta: %{
          time: @time,
          report_cb: fn _report -> raise "report blew up" end
        }
      }

      decoded = format_and_decode(event)

      assert decoded["level"] == "error"
      assert is_binary(decoded["message"])
      assert decoded["message"] =~ "broken"
    end
  end

  describe "production configuration" do
    test "uses the JSON formatter only in production" do
      config = Config.Reader.read!("config/prod.exs", env: :prod)

      assert get_in(config, [:logger, :default_handler, :formatter]) ==
               {Chesstrainer.JSONLogFormatter, %{}}
    end
  end

  defp format_and_decode(event) do
    line = event |> JSONLogFormatter.format(%{}) |> IO.iodata_to_binary()

    assert String.ends_with?(line, "\n")
    assert length(String.split(line, "\n", trim: true)) == 1

    Jason.decode!(line)
  end

  defp stacktrace do
    [{Foo, :bar, 1, [file: ~c"lib/foo.ex", line: 10]}]
  end
end
