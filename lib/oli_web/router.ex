defmodule OliWeb.Router do
  use OliWeb, :router

  import Phoenix.LiveDashboard.Router

  # We have only three "base" pipelines:   :browser, :api, and :lti
  # All of the other pipelines are to be used as additions onto
  # one of these three base pipelines

  # pipeline for all browser based routes
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {OliWeb.LayoutView, :root}
    plug :put_secure_browser_headers
    plug Plug.Telemetry, event_prefix: [:oli, :plug]
    plug Oli.Plugs.SetCurrentUser
  end

  # pipline for REST api endpoint routes
  pipeline :api do
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
    plug Plug.Telemetry, event_prefix: [:oli, :plug]
    plug :accepts, ["json"]
  end

  # pipeline for LTI launch endpoints
  pipeline :lti do
    plug :fetch_session
    plug :fetch_flash
    plug Oli.Plugs.SetCurrentUser
  end

  # Pipeline extensions:

  # Extends the browser pipeline for delivery specific routes
  pipeline :delivery do
    plug Oli.Plugs.RemoveXFrameOptions
    plug Oli.Plugs.VerifyUser
    plug :put_layout, {OliWeb.LayoutView, :delivery}
  end

  # Ensure that we always do csrf
  pipeline :csrf_always do
    plug :protect_from_forgery
  end

  # Do not include csrf protection in development mode. Certain
  # LTI launch routes break in dev with csrf in place
  pipeline :csrf_in_prod do
    if Mix.env != :dev, do: plug :protect_from_forgery
  end

  # Ensure that the user logged in is an admin user
  pipeline :admin do
    plug Oli.Plugs.EnsureAdmin
  end

  # Ensure that we have a logged in user
  pipeline :protected do
    plug Oli.Plugs.Protect
  end

  # Disable caching of resources in authoring
  pipeline :authoring do
    plug Oli.Plugs.NoCache
  end

  # parse url encoded forms
  pipeline :www_url_form do
    plug Plug.Parsers, parsers: [:urlencoded]
  end

  # set the layout to be workspace
  pipeline :workspace_layout do
    plug :put_layout, {OliWeb.LayoutView, "workspace.html"}
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through [:browser, :csrf_always]

    get "/", StaticPageController, :index
  end

  # authorization protected routes
  scope "/", OliWeb do
    pipe_through [:browser, :csrf_always, :protected, :workspace_layout, :authoring]

    get "/projects", WorkspaceController, :projects
    get "/account", WorkspaceController, :account
    resources "/institutions", InstitutionController
  end

  scope "/project", OliWeb do
    pipe_through [:browser, :csrf_always, :protected, :workspace_layout, :authoring]

    # Project display pages
    get "/:project_id", ProjectController, :overview
    get "/:project_id/objectives", ProjectController, :objectives
    get "/:project_id/objectives/:objective_slug/:action", ProjectController, :edit_objective
    get "/:project_id/publish", ProjectController, :publish
    post "/:project_id/publish", ProjectController, :publish_active

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


    # Editors
    get "/:project_id/resource/:revision_slug", ResourceController, :edit
    get "/:project_id/resource/:revision_slug/preview", ResourceController, :preview
    delete "/:project_id/resource/:revision_slug", ResourceController, :delete
    get "/:project_id/resource/:revision_slug/activity/:activity_slug", ActivityController, :edit

    # Collaborators
    post "/:project_id/collaborators", CollaboratorController, :create
    put "/:project_id/collaborators/:author_email", CollaboratorController, :update
    delete "/:project_id/collaborators/:author_email", CollaboratorController, :delete

    # Insights
    get "/:project_id/insights", ProjectController, :insights
    # Ideally, analytics should be live-routed to preserve forward/back button when toggling
    # between analytics groupings and sorting. I could not get it to run through the project authorization
    # plugs when live-routing, however.
    # live "/:project_id/insights", Insights
  end

  scope "/api/v1/project", OliWeb do
    pipe_through [:api, :protected]
    put "/:project_id/curriculum", CurriculumController, :update
    put "/:project/resource/:resource", ResourceController, :update

    post "/:project/activity/:activity_type", ActivityController, :create
    put "/:project/resource/:resource/activity/:activity", ActivityController, :update
    put "/test/evaluate", ActivityController, :evaluate
    put "/test/transform", ActivityController, :transform

    delete "/:project/resource/:resource/activity", ActivityController, :delete

    post "/:project/lock/:resource", LockController, :acquire
    delete "/:project/lock/:resource", LockController, :release


  end

  scope "/api/v1/attempt", OliWeb do
    pipe_through [:api]

    # post to create a new attempt
    # put to submit a response
    # patch to save response state

    post "/activity/:activity_attempt_guid/part/:part_attempt_guid", AttemptController, :new_part
    put "/activity/:activity_attempt_guid/part/:part_attempt_guid", AttemptController, :submit_part
    patch "/activity/:activity_attempt_guid/part/:part_attempt_guid", AttemptController, :save_part
    get "/activity/:activity_attempt_guid/part/:part_attempt_guid/hint", AttemptController, :get_hint

    post "/activity/:activity_attempt_guid", AttemptController, :new_activity
    put "/activity/:activity_attempt_guid", AttemptController, :submit_activity
    patch "/activity/:activity_attempt_guid", AttemptController, :save_activity

  end

  # auth routes, only accessable to guest users who are not logged in
  scope "/auth", OliWeb do
    pipe_through [:browser, :csrf_always, OliWeb.Plugs.Guest]

    get "/signin", AuthController, :signin

    get "/register", AuthController, :register
    get "/register/email", AuthController, :register_email_form
    post "/register/email", AuthController, :register_email_submit
  end

  scope "/auth", OliWeb do
    pipe_through [:browser, :csrf_in_prod]

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
    pipe_through [:browser, :csrf_always, :delivery]

    get "/", DeliveryController, :index

    get "/link_account", DeliveryController, :link_account
    get "/create_and_link_account", DeliveryController, :create_and_link_account
    post "/section", DeliveryController, :create_section
    get "/signout", DeliveryController, :signout
    get "/open_and_free", DeliveryController, :list_open_and_free

    get "/:context_id/page/:revision_slug", PageDeliveryController, :page
    get "/:context_id/page", PageDeliveryController, :index
    get "/:context_id/page/:revision_slug/attempt", PageDeliveryController, :start_attempt
    get "/:context_id/page/:revision_slug/attempt/:attempt_guid", PageDeliveryController, :finalize_attempt

    get "/:context_id/grades/export", PageDeliveryController, :export_gradebook
  end

  scope "/admin", OliWeb do
    pipe_through [:browser, :csrf_always, :protected, :admin]
    live_dashboard "/dashboard", metrics: OliWeb.Telemetry
    live "/history/:slug", RevisionHistory
  end

  # routes only accessible to developers
  if Application.fetch_env!(:oli, :env) == :dev or Application.fetch_env!(:oli, :env) == :test do
    scope "/dev", OliWeb do
      pipe_through [:browser, :csrf_always]

      get "/uipalette", UIPaletteController, :index
    end

    scope "/test", OliWeb do
      pipe_through [:browser, :csrf_always]

      get "/editor", EditorTestController, :index

    end

  end

end
