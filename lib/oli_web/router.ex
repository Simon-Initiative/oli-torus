defmodule OliWeb.Router do
  use OliWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    # disable protect_from_forgery in development environment
    if Mix.env != :dev, do: plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Oli.Plugs.SetCurrentUser
  end

  pipeline :protected do
    plug Oli.Plugs.Protect
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :lti do
    plug :fetch_session
    plug :fetch_flash
    plug Oli.Plugs.SetCurrentUser
  end

  pipeline :delivery do
    plug :fetch_session
    plug :fetch_flash
    plug :put_layout, {OliWeb.LayoutView, :delivery}
    plug Oli.Plugs.SetCurrentUser
    plug Oli.Plugs.VerifyUser
  end

  pipeline :www_url_form do
    plug Plug.Parsers, parsers: [:urlencoded]
  end

  pipeline :workspace_layout do
    plug :put_layout, {OliWeb.LayoutView, "workspace.html"}
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # authorization protected routes
  scope "/", OliWeb do
    pipe_through [:browser, :protected, :workspace_layout]

    get "/projects", WorkspaceController, :projects
    get "/account", WorkspaceController, :account
    resources "/institutions", InstitutionController
  end

  scope "/project", OliWeb do
    pipe_through [:browser, :protected, :workspace_layout]

    get "/:project", ProjectController, :overview
    get "/:project/objectives", ProjectController, :objectives
    get "/:project/curriculum", ProjectController, :curriculum
    get "/:project/publish", ProjectController, :publish
    get "/:project/insights", ProjectController, :insights

    get "/:project/:page", ProjectController, :page
    get "/:project/:page/edit", ProjectController, :resource_editor
  end

  # auth routes, only accessable to guest users who are not logged in
  scope "/auth", OliWeb do
    pipe_through [:browser, OliWeb.Plugs.Guest]

    get "/signin", AuthController, :signin

    get "/register", AuthController, :register
    get "/register/email", AuthController, :register_email_form
    post "/register/email", AuthController, :register_email_submit
  end

  scope "/auth", OliWeb do
    pipe_through [:browser]

    get "/signout", AuthController, :signout

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/identity/callback", AuthController, :identity_callback
  end

  # LTI routes
  scope "/lti", OliWeb do
    pipe_through [:lti, :www_url_form]

    post "/basic_launch", LtiController, :basic_launch
  end

  scope "/course", OliWeb do
    pipe_through [:delivery]

    get "/", DeliveryController, :index
    get "/link_account", DeliveryController, :link_account
    get "/signout", DeliveryController, :signout

  end

  # routes only accessable to developers
  if Mix.env === :dev or Mix.env === :test do
    scope "/dev", OliWeb do
      pipe_through :browser

      get "/uipalette", UIPaletteController, :index
    end

    scope "/test", OliWeb do
      pipe_through :browser

      get "/editor", EditorTestController, :index

    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", OliWeb do
  #   pipe_through :api
  # end
end
