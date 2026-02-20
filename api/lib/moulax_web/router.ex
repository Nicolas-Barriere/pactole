defmodule MoulaxWeb.Router do
  use MoulaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", MoulaxWeb do
    pipe_through :api

    resources "/tags", TagController, except: [:new, :edit]

    resources "/accounts", AccountController, except: [:new, :edit] do
      resources "/transactions", TransactionController, only: [:index, :create]
      resources "/imports", ImportController, only: [:index, :create]
    end

    get "/transactions", TransactionController, :index
    patch "/transactions/bulk-tag", TransactionController, :bulk_tag
    resources "/transactions", TransactionController, only: [:show, :update, :delete]

    resources "/imports", ImportController, only: [:show]

    resources "/tagging-rules", TaggingRuleController, except: [:new, :edit]
    post "/tagging-rules/apply", TaggingRuleController, :apply_rules

    get "/dashboard/summary", DashboardController, :summary
    get "/dashboard/spending", DashboardController, :spending
    get "/dashboard/trends", DashboardController, :trends
    get "/dashboard/top-expenses", DashboardController, :top_expenses
  end
end
