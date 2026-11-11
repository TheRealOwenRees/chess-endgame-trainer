defmodule Mix.Tasks.Accounts.Promote do
  use Mix.Task

  @shortdoc "Sets a user's authority role"

  @moduledoc """
  Sets a user's authority role.

      mix accounts.promote <email-or-username> <role>

  Roles, from least to most authority: `member`, `moderator`, `admin`,
  `super_admin`.

  This task remains the CLI fallback for bootstrapping a role. Once an admin
  exists, roles and plans can also be managed at `/admin/users`.
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [login, role] ->
        set_role(login, parse_role(role))

      _ ->
        Mix.raise("Usage: mix accounts.promote <email-or-username> <role>")
    end
  end

  defp set_role(login, role) do
    case Chesstrainer.Accounts.get_user_by_login(login) do
      nil ->
        Mix.raise("No user found with email or username #{inspect(login)}")

      user ->
        case Chesstrainer.Accounts.update_user_role(user, role) do
          {:ok, updated} ->
            Mix.shell().info("Set #{updated.username} (#{updated.email}) role to #{updated.role}")

          {:error, changeset} ->
            Mix.raise("Could not update role: #{inspect(changeset.errors)}")
        end
    end
  end

  defp parse_role(role) do
    case Enum.find(Chesstrainer.Accounts.Role.values(), &(Atom.to_string(&1) == role)) do
      nil ->
        valid = Chesstrainer.Accounts.Role.values() |> Enum.map_join(", ", &Atom.to_string/1)
        Mix.raise("Unknown role #{inspect(role)}. Use one of: #{valid}")

      role ->
        role
    end
  end
end
