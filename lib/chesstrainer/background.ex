defmodule Chesstrainer.Background do
  @moduledoc """
  Runs background work and logs any failure.

  Background failures otherwise disappear: a task exits, the supervisor keeps
  the rest of the system running, and nobody sees why the work did not happen.
  This wrapper turns crashes, throws, exits and `{:error, reason}` returns into
  one structured error line with the reason and stacktrace.

  The label is a short description of the work; metadata is added to the log
  line unchanged (minus the formatter's own redaction).
  """

  require Logger

  @type result :: term()

  @doc """
  Runs `fun` and logs a failure. Returns the function's value, or `:error` when
  it crashed or returned an error tuple.
  """
  @spec run(String.t(), (-> result)) :: result() | :error
  def run(label, fun), do: run(label, [], fun)

  @doc """
  Like `run/2`, with extra metadata for the error line.
  """
  @spec run(String.t(), keyword(), (-> result)) :: result() | :error
  def run(label, metadata, fun)
      when is_binary(label) and is_list(metadata) and is_function(fun, 0) do
    case fun.() do
      {:error, reason} ->
        Logger.error(
          "#{label} failed: #{format_term(reason)}",
          Keyword.merge(metadata, reason: reason)
        )

        :error

      result ->
        result
    end
  rescue
    exception ->
      Logger.error(
        "#{label} crashed: #{Exception.message(exception)}",
        Keyword.merge(metadata, exception: exception, stacktrace: __STACKTRACE__)
      )

      :error
  catch
    kind, reason ->
      Logger.error(
        "#{label} crashed: #{format_term(reason)}",
        Keyword.merge(metadata, kind: kind, reason: reason, stacktrace: __STACKTRACE__)
      )

      :error
  end

  defp format_term(term) when is_binary(term), do: term
  defp format_term(term), do: inspect(term, limit: 10, printable_limit: 500)
end
