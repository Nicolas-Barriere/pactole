defmodule MoulaxWeb.Router do
  use MoulaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", MoulaxWeb do
    pipe_through :api

    resources "/accounts", AccountController, except: [:new, :edit]
    resources "/categories", CategoryController, except: [:new, :edit]

    resources "/accounts", AccountController, except: [:new, :edit] do
      resources "/transactions", TransactionController, only: [:index, :create]
      resources "/imports", ImportController, only: [:index, :create]
    end

    get "/transactions", TransactionController, :index
    patch "/transactions/bulk-categorize", TransactionController, :bulk_categorize
    resources "/transactions", TransactionController, only: [:show, :update, :delete]

    resources "/imports", ImportController, only: [:show]

    resources "/categorization-rules", CategorizationRuleController, except: [:new, :edit]
  end
end
