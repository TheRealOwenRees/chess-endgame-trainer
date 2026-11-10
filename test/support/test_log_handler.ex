defmodule Chesstrainer.TestLogHandler do
  @moduledoc false

  @doc false
  def format(event, %{pid: pid}) do
    send(pid, {:log_event, event})
    ""
  end
end
