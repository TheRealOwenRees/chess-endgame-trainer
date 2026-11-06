alias Chesstrainer.Repo.Seeds.Endgames.{Win, Draw}

defmodule Chesstrainer.Repo.Seeds.Endgames do
  def all do
    Win.all() ++ Draw.all()
  end
end
