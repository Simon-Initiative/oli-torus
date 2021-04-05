defmodule OliWeb.Router do
  use OliWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword, PowEmailConfirmation]

  import Phoenix.LiveDashboard.Router

  ### BASE PIPELINES ###
  # We have four "base" pipelines:   :browser, :api, :lti, and :skip_csrf_protection
  # All of the other pipelines are to be used as additions onto one of these four base pipelines

  # pipeline for all browser based routes
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {OliWeb.LayoutView, "default.html"}
    plug :put_layout, {OliWeb.LayoutView, "app.html"}
    plug :put_secure_browser_headers
    plug :protect_from_forgery
    plug Plug.Telemetry, event_prefix: [:oli, :plug]
    plug Oli.Plugs.SetCurrentUser
    plug Oli.Plugs.SetDefaultPow, :author
  end

  # pipline for REST api endpoint routes
  pipeline :api do
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
    plug OpenApiSpex.Plug.PutApiSpec, module: OliWeb.ApiSpec
    plug Plug.Telemetry, event_prefix: [:oli, :plug]
    plug :accepts, ["json"]
    plug Oli.Plugs.SetDefaultPow, :author
  end

  # pipeline for LTI launch endpoints
  pipeline :lti do
    plug :fetch_session
    plug :fetch_flash
    plug :put_root_layout, {OliWeb.LayoutView, "lti.html"}
  end

  pipeline :skip_csrf_protection do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  ### PIPELINE EXTENSIONS ###
  # Extend the base pipelines specific routes

  pipeline :authoring do
    # Disable caching of resources in authoring
    plug Oli.Plugs.NoCache
  end

  # set the layout to be workspace
  pipeline :workspace do
    plug :put_root_layout, {OliWeb.LayoutView, "workspace.html"}
  end

  # Ensure that we have a logged in user
  pipeline :delivery_protected do
    plug Oli.Plugs.SetDefaultPow, :user

    plug Pow.Plug.RequireAuthenticated,
      error_handler: OliWeb.Pow.UserAuthErrorHandler

    plug Oli.Plugs.RemoveXFrameOptions
    plug Oli.Plugs.LoadLtiParams
    plug :put_root_layout, {OliWeb.LayoutView, "delivery.html"}
  end

  # Ensure that we have a logged in user
  pipeline :authoring_protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  # Ensure that the user logged in is an admin user
  pipeline :admin do
    plug Oli.Plugs.EnsureAdmin
  end

  # parse url encoded forms
  pipeline :www_url_form do
    plug Plug.Parsers, parsers: [:urlencoded]
  end

  pipeline :authorize_project do
    plug Oli.Plugs.AuthorizeProject
  end

  pipeline :registration_captcha do
    plug Oli.Plugs.RegistrationCaptcha
  end

  pipeline :pow_email_layout do
    plug :put_pow_mailer_layout, {OliWeb.LayoutView, :email}
  end

  ### HELPERS ###

  # with_session/1 used by authoring liveviews to load the current author id
  def with_session(conn) do
    %{"current_author_id" => conn.assigns.current_author.id}
  end

  def with_delivery(conn) do
    %{"lti_params" => conn.assigns.lti_params, "current_user" => conn.assigns.current_user}
  end

  defp put_pow_mailer_layout(conn, layout), do: put_private(conn, :pow_mailer_layout, layout)

  ### ROUTES ###

  scope "/" do
    pipe_through :skip_csrf_protection

    pow_assent_authorization_post_callback_routes()
  end

  scope "/", PowInvitation.Phoenix, as: "pow_invitation" do
    pipe_through [:browser, :registration_captcha]

    resources "/invitations", InvitationController, only: [:edit, :update]
  end

  scope "/" do
    pipe_through [:browser, :pow_email_layout, :registration_captcha]

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()

    # handle linking accounts when using a social account provider to login
    get "/auth/:provider/link", OliWeb.DeliveryController, :process_link_account_provider
    get "/auth/:provider/link/callback", OliWeb.DeliveryController, :link_account_callback
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through [:browser]

    get "/", StaticPageController, :index
  end

  scope "/", OliWeb do
    pipe_through [:browser, Oli.Plugs.RemoveXFrameOptions]

    resources "/help", HelpController, only: [:index, :create]
    get "/help/sent", HelpController, :sent
  end

  scope "/", OliWeb do
    pipe_through [:api]
    get "/api/v1/legacy_support", LegacySupportController, :index
    post "/access_tokens", LtiController, :access_tokens
  end

  scope "/.well-known", OliWeb do
    pipe_through [:api]

    get "/jwks.json", LtiController, :jwks
  end

  # authorization protected routes
  scope "/", OliWeb do
    pipe_through [:browser, :authoring_protected, :workspace, :authoring]

    live "/projects", Projects.ProjectsLive, session: {__MODULE__, :with_session, []}
    get "/account", WorkspaceController, :account
    put "/account", WorkspaceController, :update_author
    post "/account/theme", WorkspaceController, :update_theme
    post "/account/live_preview_display", WorkspaceController, :update_live_preview_display

    # keep a session active by periodically calling this endpoint
    get "/keep-alive", StaticPageController, :keep_alive
  end

  scope "/project", OliWeb do
    pipe_through [:browser, :authoring_protected, :workspace, :authoring]
    post "/", ProjectController, :create
  end

  scope "/project", OliWeb do
    pipe_through [:browser, :authoring_protected, :workspace, :authoring, :authorize_project]

    # Project display pages
    get "/:project_id", ProjectController, :overview
    get "/:project_id/publish", ProjectController, :publish
    post "/:project_id/publish", ProjectController, :publish_active
    post "/:project_id/datashop", ProjectController, :download_datashop
    post "/:project_id/duplicate", ProjectController, :clone_project

    # Project
    put "/:project_id", ProjectController, :update
    delete "/:project_id", ProjectController, :delete

    # Objectives
    live "/:project_id/objectives", Objectives.Objectives,
      session: {__MODULE__, :with_session, []}

    # Curriculum
    live "/:project_id/curriculum/:container_slug/edit/:revision_slug",
         Curriculum.ContainerLive,
         :edit,
         session: {__MODULE__, :with_session, []}

    live "/:project_id/curriculum/:container_slug", Curriculum.ContainerLive, :index,
      session: {__MODULE__, :with_session, []}

    live "/:project_id/curriculum/", Curriculum.ContainerLive, :index,
      session: {__MODULE__, :with_session, []}

    # Review/QA
    live "/:project_id/review", Qa.QaLive, session: {__MODULE__, :with_session, []}

    # Editors
    get "/:project_id/resource/:revision_slug", ResourceController, :edit
    get "/:project_id/resource/:revision_slug/preview", ResourceController, :preview
    delete "/:project_id/resource/:revision_slug", ResourceController, :delete
    get "/:project_id/resource/:revision_slug/activity/:activity_slug", ActivityController, :edit

    # Collaborators
    post "/:project_id/collaborators", CollaboratorController, :create
    put "/:project_id/collaborators/:author_email", CollaboratorController, :update
    delete "/:project_id/collaborators/:author_email", CollaboratorController, :delete

    # Activities
    put "/:project_id/activities/enable/:activity_slug",
        ProjectActivityController,
        :enable_activity

    put "/:project_id/activities/disable/:activity_slug",
        ProjectActivityController,
        :disable_activity

    # Insights
    get "/:project_id/insights", ProjectController, :insights
    # Ideally, analytics should be live-routed to preserve forward/back button when toggling
    # between analytics groupings and sorting. I could not get it to run through the project authorization
    # plugs when live-routing, however.
    # live "/:project_id/insights", Insights, session: {__MODULE__, :with_session, []}
  end

  scope "/api/v1" do
    pipe_through [:api]

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api/v1/account", OliWeb do
    pipe_through [:api, :authoring_protected]

    get "/preferences", WorkspaceController, :fetch_preferences
    post "/preferences", WorkspaceController, :update_preferences
  end

  scope "/api/v1/project", OliWeb do
    pipe_through [:api, :authoring_protected]

    put "/:project/resource/:resource", ResourceController, :update
    get "/:project/link", ResourceController, :index

    post "/:project/activity/:activity_type", ActivityController, :create

    put "/test/evaluate", ActivityController, :evaluate
    put "/test/transform", ActivityController, :transform

    post "/:project/lock/:resource", LockController, :acquire
    delete "/:project/lock/:resource", LockController, :release
  end

  # Storage Service
  scope "/api/v1/storage/project/:project/resource", OliWeb do
    pipe_through [:api, :authoring_protected]

    get "/:resource", ActivityController, :retrieve
    post "/", ActivityController, :bulk_retrieve
    delete "/:resource", ActivityController, :delete
    put "/:resource", ActivityController, :update
    post "/:resource", ActivityController, :create_secondary
  end

  scope "/api/v1/storage/course/:course/resource", OliWeb do
    pipe_through [:api, :delivery_protected]

    get "/:resource", ActivityController, :retrieve_delivery
    post "/", ActivityController, :bulk_retrieve_delivery
  end

  # Media Service
  scope "/api/v1/media/project/:project", OliWeb do
    pipe_through [:api, :authoring_protected]

    post "/", MediaController, :create
    get "/", MediaController, :index
  end

  # Objectives Service
  scope "/api/v1/objectives/project/:project", OliWeb do
    pipe_through [:api, :authoring_protected]

    post "/", ObjectivesController, :create
    get "/", ObjectivesController, :index
    put "/objective/:objective", ObjectivesController, :update
  end

  scope "/api/v1/attempt", OliWeb do
    pipe_through [:api, :delivery_protected]

    # post to create a new attempt
    # put to submit a response
    # patch to save response state

    post "/activity/:activity_attempt_guid/part/:part_attempt_guid", AttemptController, :new_part

    put "/activity/:activity_attempt_guid/part/:part_attempt_guid",
        AttemptController,
        :submit_part

    patch "/activity/:activity_attempt_guid/part/:part_attempt_guid",
          AttemptController,
          :save_part

    get "/activity/:activity_attempt_guid/part/:part_attempt_guid/hint",
        AttemptController,
        :get_hint

    post "/activity/:activity_attempt_guid", AttemptController, :new_activity
    put "/activity/:activity_attempt_guid", AttemptController, :submit_activity
    patch "/activity/:activity_attempt_guid", AttemptController, :save_activity

    put "/activity/:activity_attempt_guid/evaluations", AttemptController, :submit_evaluations
  end

  scope "/api/v1/lti", OliWeb, as: :api do
    pipe_through [:api, :authoring_protected]

    resources "/platforms", Api.PlatformInstanceController
  end

  # LTI routes
  scope "/lti", OliWeb do
    pipe_through [:lti, :www_url_form]

    post "/login", LtiController, :login
    get "/login", LtiController, :login
    post "/launch", LtiController, :launch
    post "/test", LtiController, :test

    get "/developer_key.json", LtiController, :developer_key_json

    post "/register", LtiController, :request_registration

    get "/authorize_redirect", LtiController, :authorize_redirect
  end

  scope "/course", OliWeb do
    pipe_through [:browser, :delivery_protected, :pow_email_layout]

    get "/", DeliveryController, :index

    get "/link_account", DeliveryController, :link_account
    post "/link_account", DeliveryController, :process_link_account_user
    get "/create_and_link_account", DeliveryController, :create_and_link_account
    post "/create_and_link_account", DeliveryController, :process_create_and_link_account_user

    post "/section", DeliveryController, :create_section
    get "/signout", DeliveryController, :signout

    get "/unauthorized", DeliveryController, :unauthorized

    # course link resolver
    get "/link/:revision_slug", PageDeliveryController, :link

    get "/:section_slug/page", PageDeliveryController, :index
    get "/:section_slug/page/:revision_slug", PageDeliveryController, :page
    get "/:section_slug/page/:revision_slug/attempt", PageDeliveryController, :start_attempt

    get "/:section_slug/page/:revision_slug/attempt/:attempt_guid",
        PageDeliveryController,
        :finalize_attempt

    get "/:section_slug/page/:revision_slug/attempt/:attempt_guid/review",
        PageDeliveryController,
        :review_attempt

    live "/:section_slug/grades", Grades.GradesLive, session: {__MODULE__, :with_delivery, []}
    get "/:section_slug/grades/export", PageDeliveryController, :export_gradebook

    resources "/help", HelpDeliveryController, only: [:index, :create]
    get "/help/sent", HelpDeliveryController, :sent
  end

  scope "/admin", OliWeb do
    pipe_through [:browser, :authoring_protected, :admin]

    live_dashboard "/dashboard",
      metrics: OliWeb.Telemetry,
      session: {__MODULE__, :with_session, []}

    resources "/platform_instances", PlatformInstanceController
  end

  scope "/admin", OliWeb do
    pipe_through [:browser, :authoring_protected, :workspace, :authoring, :admin]
    live "/accounts", Accounts.AccountsLive, session: {__MODULE__, :with_session, []}

    resources "/institutions", InstitutionController do
      resources "/registrations", RegistrationController, except: [:index, :show] do
        resources "/deployments", DeploymentController, except: [:index, :show]
      end
    end

    get "/ingest", IngestController, :index
    post "/ingest", IngestController, :upload

    get "/invite", InviteController, :index
    post "/invite", InviteController, :create

    get "/manage_activities", ActivityManageController, :index
    put "/manage_activities/make_global/:activity_slug", ActivityManageController, :make_global
    put "/manage_activities/make_private/:activity_slug", ActivityManageController, :make_private

    put "/approve_registration", InstitutionController, :approve_registration
    delete "/pending_registration/:id", InstitutionController, :remove_registration
  end

  scope "/project", OliWeb do
    pipe_through [
      :browser,
      :authoring_protected,
      :workspace,
      :authoring,
      :authorize_project,
      :admin
    ]

    live "/:project_id/history/:slug", RevisionHistory, session: {__MODULE__, :with_session, []}
  end

  # routes only accessible to developers
  if Application.fetch_env!(:oli, :env) == :dev or Application.fetch_env!(:oli, :env) == :test do
    # web interface for viewing sent emails during development
    forward "/dev/sent_emails", Bamboo.SentEmailViewerPlug

    scope "/dev", OliWeb do
      pipe_through [:browser]

      get "/uipalette", UIPaletteController, :index
    end

    scope "/dev" do
      pipe_through [:browser]

      get "/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
    end

    scope "/test", OliWeb do
      pipe_through [:browser]

      get "/editor", EditorTestController, :index
    end
  end
end
