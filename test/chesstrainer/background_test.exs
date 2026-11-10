defmodule Chesstrainer.BackgroundTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Chesstrainer.Background
  alias Chesstrainer.JSONLogFormatter

  setup do
    handler_id = :"background_test_capture_#{System.unique_integer([:positive])}"

    :ok =
      :logger.add_handler(handler_id, :logger_std_h, %{
        formatter: {Chesstrainer.TestLogHandler, %{pid: self()}},
        level: :all
      })

    on_exit(fn -> :logger.remove_handler(handler_id) end)

    :ok
  end

  describe "run/3" do
    test "returns the function's value on success" do
      assert :ok = Background.run("test task", fn -> :ok end)
      assert {:ok, 42} = Background.run("test task", fn -> {:ok, 42} end)
    end

    test "logs an error tuple with its reason" do
      capture_log(fn ->
        assert :error =
                 Background.run("test task", [table: :demo], fn -> {:error, :disk_full} end)
      end)

      assert_receive {:log_event, event}

      assert event.level == :error
      assert event.meta[:table] == :demo
      assert event.meta[:reason] == :disk_full
      assert message(event) == "test task failed: :disk_full"
    end

    test "logs a crash with the exception, reason and stacktrace" do
      capture_log(fn ->
        assert :error = Background.run("test task", fn -> raise "boom" end)
      end)

      assert_receive {:log_event, event}

      assert event.level == :error
      assert %RuntimeError{message: "boom"} = event.meta[:exception]
      assert is_list(event.meta[:stacktrace])
      assert event.meta[:stacktrace] != []
      assert message(event) =~ "test task crashed: boom"

      decoded = event |> JSONLogFormatter.format(%{}) |> IO.iodata_to_binary() |> Jason.decode!()

      assert decoded["error"]["kind"] == "RuntimeError"
      assert decoded["error"]["reason"] == "boom"
      assert decoded["error"]["stacktrace"] |> is_list()
      assert decoded["error"]["stacktrace"] != []
    end

    test "logs a throw with its reason and stacktrace" do
      capture_log(fn ->
        assert :error = Background.run("test task", fn -> throw(:nope) end)
      end)

      assert_receive {:log_event, event}

      assert event.level == :error
      assert event.meta[:kind] == :throw
      assert event.meta[:reason] == :nope
      assert message(event) == "test task crashed: :nope"
    end
  end

  describe "Chesstrainer.Cache scheduled backups" do
    test "log a failed backup" do
      table = :"test_failed_backup_log_#{System.unique_integer([:positive])}"
      parent = self()

      backup_fun = fn _table ->
        send(parent, {:backup_started, self()})
        {:error, :disk_full}
      end

      log =
        capture_log([level: :info], fn ->
          pid =
            start_supervised!(
              Supervisor.child_spec(
                {Chesstrainer.Cache, {table, [backup_fun: backup_fun]}},
                id: table
              )
            )

          send(pid, :backup)

          assert_receive {:backup_started, task_pid}, 1_000
          ref = Process.monitor(task_pid)
          assert_receive {:DOWN, ^ref, :process, ^task_pid, :normal}, 1_000
        end)

      assert log =~ "cache backup failed"
      assert log =~ ":disk_full"
    end
  end

  defp message(event) do
    event
    |> Logger.Formatter.format_event(8_096)
    |> IO.iodata_to_binary()
  end
end
