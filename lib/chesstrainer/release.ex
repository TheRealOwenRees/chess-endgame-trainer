defmodule Chesstrainer.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :chesstrainer

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Derives material family themes for the whole library.

  Runs in the release without starting the web application: `with_repo/2`
  starts just the repository, which is all the derivation needs.
  """
  def derive_material, do: with_repo(&Chesstrainer.Endgames.MaterialThemes.derive/0)

  @doc """
  Derives motif themes from the local tablebase for the whole library.
  """
  def derive_motifs, do: with_repo(&Chesstrainer.Endgames.MotifThemes.derive/0)

  defp with_repo(fun) do
    load_app()

    for repo <- repos() do
      {:ok, result, _} = Ecto.Migrator.with_repo(repo, fn _repo -> fun.() end)
      result
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
