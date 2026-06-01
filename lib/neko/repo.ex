defmodule Neko.Repo do
  use Ecto.Repo,
    otp_app: :neko,
    adapter: Ecto.Adapters.Postgres
end
