defmodule OliWeb.Router do
  use OliWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Oli.Plugs.SetUser
  end

  pipeline :protected do
    plug Oli.Plugs.Protect
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :lti do
    plug :put_layout, {OliWeb.LayoutView, :lti}
  end

  pipeline :www_url_form do
    plug Plug.Parsers, parsers: [:urlencoded]
  end

  scope "/", OliWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/institutions", OliWeb do
    pipe_through [:browser, :protected]

    resources "/", InstitutionController
  end

  scope "/auth", OliWeb do
    pipe_through [:browser, OliWeb.Plugs.Guest]

    get "/signin", AuthController, :signin

    get "/register", AuthController, :register
    get "/register/email", AuthController, :register_email_form
    post "/register/email", AuthController, :register_email_submit
  end

  scope "/auth", OliWeb do
    pipe_through [:browser]

    get "/signin", AuthController, :signin
    get "/signout", AuthController, :signout

    get "/register", AuthController, :register
    get "/register/email", AuthController, :register_email_form
    post "/register/email", AuthController, :register_email_submit

    post "/identity/callback", AuthController, :identity_callback

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/test", OliWeb do
    pipe_through :browser

    get "/editor", EditorTestController, :index

  end

  scope "/lti", OliWeb do
    pipe_through [:lti, :www_url_form]

    post "/basic_launch", LtiController, :basic_launch
  end

  if "#{Mix.env}" === "dev" or "#{Mix.env}" === "test" do
    scope "/dev", OliWeb do
      pipe_through :browser

      get "/uipalette", UIPaletteController, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", OliWeb do
  #   pipe_through :api
  # end
end
