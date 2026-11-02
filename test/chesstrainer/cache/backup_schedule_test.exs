defmodule Chesstrainer.Cache.BackupScheduleTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Cache.BackupSchedule

  describe "parse_time/1" do
    test "accepts HH:MM strings and {hour, minute} tuples" do
      assert {:ok, {3, 0}} = BackupSchedule.parse_time("03:00")
      assert {:ok, {23, 59}} = BackupSchedule.parse_time("23:59")
      assert {:ok, {0, 5}} = BackupSchedule.parse_time("0:05")
      assert {:ok, {4, 30}} = BackupSchedule.parse_time({4, 30})
    end

    test "rejects values that are not a valid UTC time" do
      assert :error = BackupSchedule.parse_time("24:00")
      assert :error = BackupSchedule.parse_time("03:60")
      assert :error = BackupSchedule.parse_time("03:00:00")
      assert :error = BackupSchedule.parse_time("three")
      assert :error = BackupSchedule.parse_time({24, 0})
      assert :error = BackupSchedule.parse_time(nil)
    end
  end

  describe "time!/1" do
    test "defaults to 03:00 UTC" do
      assert {3, 0} = BackupSchedule.time!(nil)
      assert {3, 0} = BackupSchedule.time!("03:00")
    end
  end

  describe "next_delay/2" do
    test "returns the delay until today's run when it is still ahead" do
      now = ~U[2026-11-02 01:30:00Z]

      assert BackupSchedule.next_delay({3, 0}, now) == :timer.hours(1) + :timer.minutes(30)
    end

    test "rolls over to tomorrow once today's run has passed" do
      now = ~U[2026-11-02 04:00:00Z]

      assert BackupSchedule.next_delay({3, 0}, now) == :timer.hours(23)
    end

    test "waits a full day when called exactly at the scheduled time" do
      now = ~U[2026-11-02 03:00:00Z]

      assert BackupSchedule.next_delay({3, 0}, now) == :timer.hours(24)
    end

    test "computes the delay from the wall clock by default" do
      delay = BackupSchedule.next_delay({0, 0})

      assert delay > 0
      assert delay <= :timer.hours(24)
    end
  end
end
