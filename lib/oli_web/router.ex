defmodule OliWeb.Router do
  use OliWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OliWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/auth", OliWeb do
    pipe_through :browser

    get "/:provider", SessionController, :request
  end

  scope "/dev", OliWeb do
    pipe_through :browser

    get "/uipalette", UIPaletteController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", OliWeb do
  #   pipe_through :api
  # end
end
