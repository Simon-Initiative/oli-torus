defmodule Oli.Repo do
  use Ecto.Repo,
    otp_app: :oli,
    adapter: Ecto.Adapters.Postgres
end
