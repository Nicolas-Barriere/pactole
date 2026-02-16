defmodule Moulax.Repo do
  use Ecto.Repo,
    otp_app: :moulax,
    adapter: Ecto.Adapters.Postgres
end
