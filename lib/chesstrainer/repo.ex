defmodule Chesstrainer.Repo do
  use Ecto.Repo,
    otp_app: :chesstrainer,
    adapter: Ecto.Adapters.Postgres
end
