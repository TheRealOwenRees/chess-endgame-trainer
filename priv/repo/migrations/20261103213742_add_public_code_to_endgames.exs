defmodule Chesstrainer.Repo.Migrations.AddPublicCodeToEndgames do
  use Ecto.Migration

  @alphabet ~c"0123456789abcdefghjkmnpqrstvwxyz"
  @length 10

  def up do
    alter table(:endgames) do
      add :public_code, :string
    end

    flush()

    repo().query!("SELECT id FROM endgames").rows
    |> Enum.reduce(MapSet.new(), fn [id], used ->
      code = Stream.repeatedly(&generate_code/0) |> Enum.find(&(not MapSet.member?(used, &1)))

      repo().query!("UPDATE endgames SET public_code = $1 WHERE id = $2", [code, id])

      MapSet.put(used, code)
    end)

    alter table(:endgames) do
      modify :public_code, :string, null: false
    end

    create unique_index(:endgames, [:public_code])
  end

  def down do
    drop unique_index(:endgames, [:public_code])

    alter table(:endgames) do
      remove :public_code
    end
  end

  # Inlined rather than calling the schema, so the migration stays frozen even
  # if the app's generator changes. `rem(byte, 32)` is unbiased: 256 = 8 * 32.
  defp generate_code do
    @length
    |> :crypto.strong_rand_bytes()
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> Enum.at(@alphabet, rem(byte, length(@alphabet))) end)
    |> List.to_string()
  end
end
