defmodule Chesstrainer.Attempts do
  @moduledoc """
  The Attempts context: a per-user history of finished playthroughs.
  """

  alias Chesstrainer.Repo
  alias Chesstrainer.Accounts.{Scope, User}
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Attempts.Attempt

  @doc """
  Records a finished attempt for the signed-in user in `scope`.

  Anonymous scopes record nothing and return `:ignored`.
  """
  def record_attempt(nil, _endgame, _outcome), do: :ignored

  def record_attempt(%Scope{user: nil}, _endgame, _outcome), do: :ignored

  def record_attempt(%Scope{user: %User{} = user}, %Endgame{} = endgame, outcome)
      when outcome in [:solved, :failed] do
    %Attempt{user_id: user.id, endgame_id: endgame.id}
    |> Attempt.changeset(%{outcome: outcome})
    |> Repo.insert()
  end
end
