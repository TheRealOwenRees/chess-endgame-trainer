defmodule Chesstrainer.Ratelimiters do
  @moduledoc """
  Generic rate limiter for external APIs (e.g., Lichess).

  This module exposes convenience functions for each external API
  that delegate to their specific rate limiter implementation.

  ## Examples

      iex> ChessTrainer.Ratelimiters.lichess_reset_cooldown()
      true

      iex> ChessTrainer.Ratelimiters.lichess_check_cooldown()
      {:ok, 0}

      iex> ChessTrainer.Ratelimiters.lichess_add_cooldown()
      true
  """

  alias Chesstrainer.Ratelimiters.Lichess

  @doc """
  Adds a cooldown entry for the Lichess API.

  This sets the cooldown period (e.g. 60 seconds) starting from now.
  Useful when a `429 Too Many Requests` response is received.
  """
  @spec lichess_add_cooldown() :: boolean()
  def lichess_add_cooldown, do: Lichess.add_cooldown()

  @doc """
  Resets the cooldown for the Lichess API.

  This clears any existing cooldown, allowing requests immediately.
  """
  @spec lichess_reset_cooldown() :: boolean()
  def lichess_reset_cooldown, do: Lichess.reset_cooldown()

  @doc """
  Checks whether the Lichess API is currently under cooldown.

  Returns:
    * `{:ok, 0}` if no cooldown is active
    * `{:cooldown, remaining_ms}` if still cooling down, with the remaining time in milliseconds
  """
  @spec lichess_check_cooldown() :: {:ok, non_neg_integer} | {:cooldown, non_neg_integer}
  def lichess_check_cooldown, do: Lichess.check_cooldown()
end
