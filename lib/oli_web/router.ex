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
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {OliWeb.LayoutView, "default.html"})
    plug(:put_layout, {OliWeb.LayoutView, "app.html"})
    plug(:put_secure_browser_headers)
    plug(Oli.Plugs.LoadTestingCSRFBypass)
    plug(:protect_from_forgery)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
  end

  # pipline for REST api endpoint routes
  pipeline :api do
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_secure_browser_headers)
    plug(OpenApiSpex.Plug.PutApiSpec, module: OliWeb.ApiSpec)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
    plug(:accepts, ["json"])
    plug(Oli.Plugs.SetDefaultPow, :author)
  end

  # pipeline for LTI launch endpoints
  pipeline :lti do
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(Oli.Plugs.SetCurrentUser)
    plug(:put_root_layout, {OliWeb.LayoutView, "lti.html"})
  end

  pipeline :skip_csrf_protection do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_secure_browser_headers)
  end

  ### PIPELINE EXTENSIONS ###
  # Extend the base pipelines specific routes

  pipeline :authoring do
    plug(Oli.Plugs.SetDefaultPow, :author)
    # Disable caching of resources in authoring
    plug(Oli.Plugs.NoCache)
  end

  pipeline :delivery do
    plug(Oli.Plugs.SetDefaultPow, :user)
  end

  # set the layout to be workspace
  pipeline :workspace do
    plug(:put_root_layout, {OliWeb.LayoutView, "workspace.html"})
  end

  pipeline :delivery_layout do
    plug(:put_root_layout, {OliWeb.LayoutView, "delivery.html"})
  end

  pipeline :maybe_enroll_open_and_free do
    plug(Oli.Plugs.MaybeEnrollOpenAndFreeUser)
  end

  pipeline :require_lti_params do
    plug(Oli.Plugs.RequireLtiParams)
  end

  pipeline :require_section do
    plug(Oli.Plugs.RequireSection)
  end

  # Ensure that we have a logged in user
  pipeline :delivery_protected do
    plug(Oli.Plugs.SetDefaultPow, :user)
    plug(Oli.Plugs.SetCurrentUser)

    plug(Pow.Plug.RequireAuthenticated,
      error_handler: OliWeb.Pow.UserAuthErrorHandler
    )

    plug(Oli.Plugs.RemoveXFrameOptions)
    plug(:put_root_layout, {OliWeb.LayoutView, "delivery.html"})
  end

  pipeline :authoring_protected do
    plug(Oli.Plugs.SetDefaultPow, :author)
    plug(Oli.Plugs.SetCurrentUser)

    plug(Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )
  end

  # Ensure that the user logged in is an admin user
  pipeline :admin do
    plug(Oli.Plugs.EnsureAdmin)
  end

  # parse url encoded forms
  pipeline :www_url_form do
    plug(Plug.Parsers, parsers: [:urlencoded])
  end

  pipeline :authorize_project do
    plug(Oli.Plugs.AuthorizeProject)
  end

  pipeline :registration_captcha do
    plug(Oli.Plugs.RegistrationCaptcha)
  end

  pipeline :pow_email_layout do
    plug(:put_pow_mailer_layout, {OliWeb.LayoutView, :email})
  end

  ### HELPERS ###

  # with_session/1 used by authoring liveviews to load the current author id
  def with_session(conn) do
    %{"current_author_id" => conn.assigns.current_author.id}
  end

  def with_section_user(conn) do
    %{"section" => conn.assigns.section, "current_user" => conn.assigns.current_user}
  end

  defp put_pow_mailer_layout(conn, layout), do: put_private(conn, :pow_mailer_layout, layout)

  ### ROUTES ###

  scope "/" do
    pipe_through([:browser, :delivery, :registration_captcha, :pow_email_layout])

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()
  end

  scope "/" do
    pipe_through([:delivery, :skip_csrf_protection])

    pow_assent_authorization_post_callback_routes()
  end

  scope "/authoring", as: :authoring do
    pipe_through([:browser, :authoring, :registration_captcha, :pow_email_layout])

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()

    # handle linking accounts when using a social account provider to login
    get("/auth/:provider/link", OliWeb.DeliveryController, :process_link_account_provider)
    get("/auth/:provider/link/callback", OliWeb.DeliveryController, :link_account_callback)
  end

  scope "/authoring" do
    pipe_through([:authoring, :skip_csrf_protection])

    pow_assent_authorization_post_callback_routes()
  end

  scope "/authoring", PowInvitation.Phoenix, as: "pow_invitation" do
    pipe_through([:browser, :delivery, :registration_captcha])

    resources("/invitations", InvitationController, only: [:edit, :update])
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through([:browser])

    get("/", StaticPageController, :index)
    get("/unauthorized", StaticPageController, :unauthorized)
  end

  scope "/", OliWeb do
    pipe_through([:api])
    get("/api/v1/legacy_support", LegacySupportController, :index)
    post("/access_tokens", LtiController, :access_tokens)

    post("/help/create", HelpController, :create)
    post("/consent/cookie", CookieConsentController, :persist_cookies)
    get("/consent/cookie/", CookieConsentController, :retrieve)

    get("/site.webmanifest", StaticPageController, :site_webmanifest)
  end

  scope "/.well-known", OliWeb do
    pipe_through([:api])

    get("/jwks.json", LtiController, :jwks)
  end

  # authorization protected routes
  scope "/authoring", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace, :authoring])

    live("/projects", Projects.ProjectsLive, session: {__MODULE__, :with_session, []})
    get("/account", WorkspaceController, :account)
    put("/account", WorkspaceController, :update_author)
    post("/account/theme", WorkspaceController, :update_theme)
    post("/account/live_preview_display", WorkspaceController, :update_live_preview_display)

    # keep a session active by periodically calling this endpoint
    get("/keep-alive", StaticPageController, :keep_alive)
  end

  scope "/authoring/project", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace, :authoring])
    post("/", ProjectController, :create)
  end

  scope "/authoring/project", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace, :authoring, :authorize_project])

    # Project display pages
    get("/:project_id", ProjectController, :overview)
    get("/:project_id/publish", ProjectController, :publish)
    post("/:project_id/publish", ProjectController, :publish_active)
    post("/:project_id/datashop", ProjectController, :download_datashop)
    post("/:project_id/duplicate", ProjectController, :clone_project)

    # Project
    put("/:project_id", ProjectController, :update)
    delete("/:project_id", ProjectController, :delete)

    # Objectives
    live("/:project_id/objectives", Objectives.Objectives,
      session: {__MODULE__, :with_session, []}
    )

    # Curriculum
    live(
      "/:project_id/curriculum/:container_slug/edit/:revision_slug",
      Curriculum.ContainerLive,
      :edit,
      session: {__MODULE__, :with_session, []}
    )

    live("/:project_id/curriculum/:container_slug", Curriculum.ContainerLive, :index,
      session: {__MODULE__, :with_session, []}
    )

    live("/:project_id/curriculum/", Curriculum.ContainerLive, :index,
      session: {__MODULE__, :with_session, []}
    )

    # Review/QA
    live("/:project_id/review", Qa.QaLive, session: {__MODULE__, :with_session, []})

    # Preview
    get("/:project_id/preview", ResourceController, :preview)
    get("/:project_id/preview/:revision_slug", ResourceController, :preview)

    # Editors
    get("/:project_id/resource/:revision_slug", ResourceController, :edit)
    get("/:project_id/resource/:revision_slug/activity/:activity_slug", ActivityController, :edit)

    # Collaborators
    post("/:project_id/collaborators", CollaboratorController, :create)
    put("/:project_id/collaborators/:author_email", CollaboratorController, :update)
    delete("/:project_id/collaborators/:author_email", CollaboratorController, :delete)

    # Activities
    put(
      "/:project_id/activities/enable/:activity_slug",
      ProjectActivityController,
      :enable_activity
    )

    put(
      "/:project_id/activities/disable/:activity_slug",
      ProjectActivityController,
      :disable_activity
    )

    # Insights
    get("/:project_id/insights", ProjectController, :insights)
    # Ideally, analytics should be live-routed to preserve forward/back button when toggling
    # between analytics groupings and sorting. I could not get it to run through the project authorization
    # plugs when live-routing, however.
    # live "/:project_id/insights", Insights, session: {__MODULE__, :with_session, []}
  end

  if Application.fetch_env!(:oli, :env) == :dev or Application.fetch_env!(:oli, :env) == :test do
    scope "/api/v1/docs" do
      pipe_through([:browser])

      get("/", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi")
    end
  end

  scope "/api/v1" do
    pipe_through([:api])

    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
  end

  scope "/api/v1/account", OliWeb do
    pipe_through([:api, :authoring_protected])

    get("/preferences", WorkspaceController, :fetch_preferences)
    post("/preferences", WorkspaceController, :update_preferences)
  end

  scope "/api/v1/project", OliWeb do
    pipe_through([:api, :authoring_protected])

    put("/:project/resource/:resource", Api.ResourceController, :update)
    get("/:project/link", Api.ResourceController, :index)

    post("/:project/activity/:activity_type", Api.ActivityController, :create)

    put("/test/evaluate", Api.ActivityController, :evaluate)
    put("/test/transform", Api.ActivityController, :transform)

    post("/:project/lock/:resource", Api.LockController, :acquire)
    delete("/:project/lock/:resource", Api.LockController, :release)
  end

  # Storage Service
  scope "/api/v1/storage/project/:project/resource", OliWeb do
    pipe_through([:api, :authoring_protected])

    get("/:resource", Api.ActivityController, :retrieve)
    post("/", Api.ActivityController, :bulk_retrieve)
    delete("/:resource", Api.ActivityController, :delete)
    put("/:resource", Api.ActivityController, :update)
    post("/:resource", Api.ActivityController, :create_secondary)
  end

  scope "/api/v1/storage/course/:section_slug/resource", OliWeb do
    pipe_through([:api, :delivery_protected])

    get("/:resource", Api.ActivityController, :retrieve_delivery)
    post("/", Api.ActivityController, :bulk_retrieve_delivery)
  end

  # Media Service
  scope "/api/v1/media/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.MediaController, :create)
    get("/", Api.MediaController, :index)
  end

  # Objectives Service
  scope "/api/v1/objectives/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.ObjectivesController, :create)
    get("/", Api.ObjectivesController, :index)
    put("/objective/:objective", Api.ObjectivesController, :update)
  end

  # User State Service, instrinsic state
  scope "/api/v1/state/course/:section_slug/activity_attempt", OliWeb do
    pipe_through([:api, :delivery_protected])

    post("/", Api.AttemptController, :bulk_retrieve)

    post("/:activity_attempt_guid", Api.AttemptController, :new_activity)
    put("/:activity_attempt_guid", Api.AttemptController, :submit_activity)
    patch("/:activity_attempt_guid", Api.AttemptController, :save_activity)
    put("/:activity_attempt_guid/evaluations", Api.AttemptController, :submit_evaluations)

    post(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid",
      Api.AttemptController,
      :new_part
    )

    put(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid",
      Api.AttemptController,
      :submit_part
    )

    patch(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid",
      Api.AttemptController,
      :save_part
    )

    get(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid/hint",
      Api.AttemptController,
      :get_hint
    )
  end

  # User State Service, extrinsic state
  scope "/api/v1/state", OliWeb do
    pipe_through([:api, :delivery_protected])

    get("/", Api.GlobalStateController, :read)
    put("/", Api.GlobalStateController, :upsert)
    delete("/", Api.GlobalStateController, :delete)

    get("/course/:section_slug", Api.SectionStateController, :read)
    put("/course/:section_slug", Api.SectionStateController, :upsert)
    delete("/course/:section_slug", Api.SectionStateController, :delete)

    get(
      "/course/:section_slug/resource_attempt/:resource_attempt_guid",
      Api.ResourceAttemptStateController,
      :read
    )

    put(
      "/course/:section_slug/resource_attempt/:resource_attempt_guid",
      Api.ResourceAttemptStateController,
      :upsert
    )

    delete(
      "/course/:section_slug/resource_attempt/:resource_attempt_guid",
      Api.ResourceAttemptStateController,
      :delete
    )
  end

  scope "/api/v1/lti", OliWeb, as: :api do
    pipe_through([:api, :authoring_protected])

    resources("/platforms", Api.PlatformInstanceController)
  end

  # LTI routes
  scope "/lti", OliWeb do
    pipe_through([:lti, :www_url_form])

    post("/login", LtiController, :login)
    get("/login", LtiController, :login)
    post("/launch", LtiController, :launch)
    post("/test", LtiController, :test)

    get("/developer_key.json", LtiController, :developer_key_json)

    post("/register", LtiController, :request_registration)

    get("/authorize_redirect", LtiController, :authorize_redirect)
  end

  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :delivery,
      :maybe_enroll_open_and_free,
      :delivery_protected,
      :pow_email_layout
    ])

    get("/", DeliveryController, :open_and_free_index)
  end

  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :delivery,
      :require_section,
      :maybe_enroll_open_and_free,
      :delivery_protected,
      :pow_email_layout
    ])

    get("/:section_slug", PageDeliveryController, :index)
    get("/:section_slug/page/:revision_slug", PageDeliveryController, :page)
    get("/:section_slug/page/:revision_slug/attempt", PageDeliveryController, :start_attempt)

    get(
      "/:section_slug/page/:revision_slug/attempt/:attempt_guid",
      PageDeliveryController,
      :finalize_attempt
    )

    get(
      "/:section_slug/page/:revision_slug/attempt/:attempt_guid/review",
      PageDeliveryController,
      :review_attempt
    )

    live("/:section_slug/grades", Grades.GradesLive, session: {__MODULE__, :with_section_user, []})

    live("/:section_slug/manage", Delivery.ManageSection,
      session: {__MODULE__, :with_section_user, []}
    )

    get("/:section_slug/grades/export", PageDeliveryController, :export_gradebook)
  end

  scope "/sections", OliWeb do
    pipe_through([:browser, :require_section, :delivery_layout, :pow_email_layout])

    get("/:section_slug/enroll", DeliveryController, :enroll)
    post("/:section_slug/create_user", DeliveryController, :create_user)
  end

  scope "/course", OliWeb do
    pipe_through([:browser, :delivery_protected, :pow_email_layout])

    get("/signout", DeliveryController, :signout)
  end

  scope "/course", OliWeb do
    pipe_through([:browser, :delivery_protected, :require_lti_params, :pow_email_layout])

    get("/", DeliveryController, :index)

    get("/link_account", DeliveryController, :link_account)
    post("/link_account", DeliveryController, :process_link_account_user)
    get("/create_and_link_account", DeliveryController, :create_and_link_account)
    post("/create_and_link_account", DeliveryController, :process_create_and_link_account_user)
    post("/research_consent", DeliveryController, :research_consent)

    post("/", DeliveryController, :create_section)
  end

  scope "/admin", OliWeb do
    pipe_through([:browser, :authoring_protected, :admin])

    live_dashboard("/dashboard",
      metrics: OliWeb.Telemetry,
      ecto_repos: [Oli.Repo],
      session: {__MODULE__, :with_session, []}
    )

    resources("/platform_instances", PlatformInstanceController)
  end

  scope "/admin", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace, :authoring, :admin])
    live("/accounts", Accounts.AccountsLive, session: {__MODULE__, :with_session, []})
    live("/features", Features.FeaturesLive)

    resources "/institutions", InstitutionController do
      resources "/registrations", RegistrationController, except: [:index, :show] do
        resources("/deployments", DeploymentController, except: [:index, :show])
      end
    end

    get("/ingest", IngestController, :index)
    post("/ingest", IngestController, :upload)

    get("/invite", InviteController, :index)
    post("/invite", InviteController, :create)

    get("/manage_activities", ActivityManageController, :index)
    put("/manage_activities/make_global/:activity_slug", ActivityManageController, :make_global)
    put("/manage_activities/make_private/:activity_slug", ActivityManageController, :make_private)

    put("/approve_registration", InstitutionController, :approve_registration)
    delete("/pending_registration/:id", InstitutionController, :remove_registration)

    # Open and free sections
    resources("/open_and_free", OpenAndFreeController)

    # Branding
    resources("/brands", BrandController)
  end

  scope "/project", OliWeb do
    pipe_through([
      :browser,
      :authoring_protected,
      :workspace,
      :authoring,
      :authorize_project,
      :admin
    ])

    live("/:project_id/history/:slug", RevisionHistory, session: {__MODULE__, :with_session, []})
  end

  # routes only accessible when load testing mode is enabled. These routes exist solely
  # to allow the load testing framework to do things like query for the available open and free
  # sections, to query for all of the pages in an individual section, etc.
  if Oli.Utils.LoadTesting.enabled?() do
    scope "/api/v1/testing", OliWeb do
      pipe_through([:api])

      get("/openfree", OpenAndFreeController, :index_api)
    end
  end

  # routes only accessible to developers
  if Application.fetch_env!(:oli, :env) == :dev or Application.fetch_env!(:oli, :env) == :test do
    # web interface for viewing sent emails during development
    forward("/dev/sent_emails", Bamboo.SentEmailViewerPlug)

    scope "/api/v1/testing", OliWeb do
      pipe_through([:api])

      post("/rules", Api.RulesEngineController, :execute)
    end

    scope "/dev", OliWeb do
      pipe_through([
        :browser,
        :admin
      ])

      get("/flame_graphs", DevController, :flame_graphs)
    end
  end
end
