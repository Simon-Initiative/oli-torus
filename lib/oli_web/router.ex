defmodule OliWeb.Router do
  use OliWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Plug.Telemetry, event_prefix: [:oli, :plug]
    # disable protect_from_forgery in development environment
    if Mix.env != :dev, do: plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Oli.Plugs.SetCurrentUser
  end

  pipeline :admin do
    plug Oli.Plugs.EnsureAdmin
  end

  pipeline :protected do
    plug Oli.Plugs.Protect
  end

  pipeline :authoring do
    plug Oli.Plugs.NoCache
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
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Plug.Telemetry, event_prefix: [:oli, :plug]
    # disable protect_from_forgery in development environment
    if Mix.env != :dev, do: plug :protect_from_forgery

    # do not change the order of the next two, our Removal
    # plug removes a header that put_secure_browser_headers
    # adds which prevents an LMS from displaying our site
    # within an iframe
    plug :put_secure_browser_headers
    plug Oli.Plugs.RemoveXFrameOptions

    plug Oli.Plugs.SetCurrentUser
    plug Oli.Plugs.VerifyUser
    plug :put_layout, {OliWeb.LayoutView, :delivery}
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

    get "/", StaticPageController, :index
  end

  # authorization protected routes
  scope "/", OliWeb do
    pipe_through [:browser, :protected, :workspace_layout, :authoring]

    get "/projects", WorkspaceController, :projects
    get "/account", WorkspaceController, :account
    resources "/institutions", InstitutionController
  end

  scope "/project", OliWeb do
    pipe_through [:browser, :protected, :workspace_layout, :authoring]

    # Project display pages
    get "/:project_id", ProjectController, :overview
    get "/:project_id/objectives", ProjectController, :objectives
    get "/:project_id/objectives/:objective_slug/:action", ProjectController, :edit_objective
    get "/:project_id/publish", ProjectController, :publish
    post "/:project_id/publish", ProjectController, :publish_active
    get "/:project_id/insights", ProjectController, :insights

    # Project
    post "/", ProjectController, :create
    put "/:project_id", ProjectController, :update
    delete "/:project_id", ProjectController, :delete

    # Objectives
    post "/:project_id/objectives", ObjectiveController, :create
    put "/:project_id/objectives/:objective_slug", ObjectiveController, :update
    delete "/:project_id/objectives/:objective_slug", ObjectiveController, :delete

    # Curriculum
    resources "/:project_id/curriculum", CurriculumController, only: [:index, :create, :delete]
    put "/:project_id/curriculum", CurriculumController, :update

    # Editors
    get "/:project_id/resource/:revision_slug", ResourceController, :edit
    delete "/:project_id/resource/:revision_slug", ResourceController, :delete
    get "/:project_id/resource/:revision_slug/activity/:activity_slug", ActivityController, :edit

    # Collaborators
    post "/:project_id/collaborators", CollaboratorController, :create
    put "/:project_id/collaborators/:author_email", CollaboratorController, :update
    delete "/:project_id/collaborators/:author_email", CollaboratorController, :delete
  end

  scope "/api/v1/project", OliWeb do
    pipe_through [:api, :protected]

    put "/:project/resource/:resource", ResourceController, :update

    post "/:project/activity/:activity_type", ActivityController, :create
    put "/:project/resource/:resource/activity/:activity", ActivityController, :update
    delete "/:project/resource/:resource/activity", ActivityController, :delete

    post "/:project/lock/:resource", LockController, :acquire
    delete "/:project/lock/:resource", LockController, :release

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
    get "/create_and_link_account", DeliveryController, :create_and_link_account
    post "/section", DeliveryController, :create_section
    get "/signout", DeliveryController, :signout
    get "/open_and_free", DeliveryController, :list_open_and_free

  end

  # A student's view of a delivered course section goes thru
  # the "/delivery/course" prefix, while an instructor's view
  # goes thru the "/delivery/section" prefix.
  scope "/delivery", OliWeb do

    scope "/course" do
      pipe_through [:delivery]

      get "/:context_id/page/:revision_slug", StudentDeliveryController, :page
      get "/:context_id", StudentDeliveryController, :index

    end

    scope "/section" do
      pipe_through [:delivery]

      get "/:context_id", InstructorDeliveryController, :index
      get "/:context_id/page/:revision_slug", InstructorDeliveryController, :page

    end

  end

  scope "/admin", OliWeb do
    pipe_through [:browser, :protected, :admin]
    live_dashboard "/dashboard", metrics: OliWeb.Telemetry
  end

  # routes only accessible to developers
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

end
