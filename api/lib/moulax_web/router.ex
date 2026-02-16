defmodule MoulaxWeb.Router do
  use MoulaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", MoulaxWeb do
    pipe_through :api
  end
end
