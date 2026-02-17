defmodule MoulaxWeb.Router do
  use MoulaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", MoulaxWeb do
    pipe_through :api

    resources "/accounts", AccountController, except: [:new, :edit]
    resources "/categorization-rules", CategorizationRuleController, except: [:new, :edit]
  end
end
