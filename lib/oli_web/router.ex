defmodule OliWeb.Router do
  use OliWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword, PowEmailConfirmation]

  import Phoenix.LiveDashboard.Router
  import PhoenixStorybook.Router

  @user_persistent_session_cookie_key "oli_user_persistent_session_v2"
  @author_persistent_session_cookie_key "oli_author_persistent_session_v2"

  ### BASE PIPELINES ###
  # We have five "base" pipelines: :browser, :api, :lti, :skip_csrf_protection, and :sso
  # All of the other pipelines are to be used as additions onto one of these four base pipelines

  # pipeline for all browser based routes
  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {OliWeb.LayoutView, :default})
    plug(:put_layout, html: {OliWeb.LayoutView, :app})
    plug(:put_secure_browser_headers)
    plug(Oli.Plugs.LoadTestingCSRFBypass)
    plug(:protect_from_forgery)
    plug(OliWeb.SetLiveCSRF)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
    plug(OliWeb.Plugs.SessionContext)
  end

  # pipline for REST api endpoint routes
  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_secure_browser_headers)
    plug(OpenApiSpex.Plug.PutApiSpec, module: OliWeb.ApiSpec)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
    plug(OliWeb.Plugs.SessionContext)
  end

  # pipeline for LTI launch endpoints
  pipeline :lti do
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {OliWeb.LayoutView, :lti})
    plug(OliWeb.Plugs.SessionContext)
  end

  # pipeline for skipping CSRF protection
  pipeline :skip_csrf_protection do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_secure_browser_headers)
    plug(OliWeb.Plugs.SessionContext)
  end

  # pipeline for SSO endpoints
  pipeline :sso do
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(Oli.Plugs.ValidateIdToken)
    plug(OliWeb.Plugs.SessionContext)
  end

  ### PIPELINE EXTENSIONS ###
  # Extend the base pipelines specific routes

  pipeline :authoring do
    plug(Oli.Plugs.SetDefaultPow, :author)

    plug(PowPersistentSession.Plug.Cookie,
      persistent_session_cookie_key: @author_persistent_session_cookie_key
    )

    plug(Oli.Plugs.SetCurrentUser)

    # Disable caching of resources in authoring
    plug(Oli.Plugs.NoCache)
  end

  pipeline :delivery do
    plug(Oli.Plugs.SetDefaultPow, :user)

    plug(PowPersistentSession.Plug.Cookie,
      persistent_session_cookie_key: @user_persistent_session_cookie_key
    )

    plug(Oli.Plugs.SetCurrentUser)
  end

  # set the layout to be workspace
  pipeline :workspace do
    plug(:put_root_layout, {OliWeb.LayoutView, :workspace})
  end

  pipeline :delivery_layout do
    plug(:put_root_layout, {OliWeb.LayoutView, :delivery})
  end

  pipeline :maybe_gated_resource do
    plug(Oli.Plugs.MaybeGatedResource)
  end

  pipeline :require_lti_params do
    plug(Oli.Plugs.RequireLtiParams)
  end

  pipeline :require_section do
    plug(Oli.Plugs.RequireSection)
  end

  pipeline :require_exploration_pages do
    plug(Oli.Plugs.RequireExplorationPages)
  end

  pipeline :force_required_survey do
    plug(Oli.Plugs.ForceRequiredSurvey)
  end

  pipeline :enforce_enroll_and_paywall do
    plug(Oli.Plugs.EnforceEnrollAndPaywall)
  end

  pipeline :authorize_section_preview do
    plug(Oli.Plugs.AuthorizeSectionPreview)
  end

  # Ensure that we have a logged in user
  pipeline :delivery_protected do
    plug(:delivery)

    plug(PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
    )

    plug(Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )

    plug(OliWeb.EnsureUserNotLockedPlug)

    plug(Oli.Plugs.RemoveXFrameOptions)

    plug(:delivery_layout)
  end

  pipeline :delivery_and_admin do
    plug(:delivery)
    plug(:authoring)
    plug(Oli.Plugs.GiveAdminPriority)

    plug(PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
    )

    plug(Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )

    plug(OliWeb.EnsureUserNotLockedPlug)

    plug(Oli.Plugs.RemoveXFrameOptions)

    plug(Oli.Plugs.LayoutBasedOnUser)
  end

  pipeline :authoring_protected do
    plug(:authoring)

    plug(PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
    )

    plug(Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )

    plug(OliWeb.EnsureUserNotLockedPlug)
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

  # For independent section creation/management functionality
  pipeline :require_independent_instructor do
    plug(Oli.Plugs.RequireIndependentInstructor)
  end

  pipeline :community_admin do
    plug(Oli.Plugs.CommunityAdmin)
  end

  pipeline :authorize_community do
    plug(Oli.Plugs.AuthorizeCommunity)
  end

  pipeline :ensure_user_section_visit do
    plug(Oli.Plugs.EnsureUserSectionVisit)
  end

  ### HELPERS ###

  defp put_pow_mailer_layout(conn, layout), do: put_private(conn, :pow_mailer_layouts, layout)

  ### ROUTES ###

  scope "/" do
    storybook_assets()
  end

  scope "/" do
    pipe_through([:browser, :delivery, :registration_captcha, :pow_email_layout])

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()
  end

  scope "/" do
    pipe_through([:skip_csrf_protection, :delivery])
    post("/jcourse/superactivity/server", OliWeb.LegacySuperactivityController, :process)

    get(
      "/jcourse/superactivity/context/:attempt_guid",
      OliWeb.LegacySuperactivityController,
      :context
    )

    post("/jcourse/dashboard/log/server", OliWeb.LegacyLogsController, :process)
    pow_assent_authorization_post_callback_routes()
  end

  scope "/", OliWeb do
    pipe_through([:browser, :delivery_protected])

    # keep a session active by periodically calling this endpoint
    get("/keep-alive", StaticPageController, :keep_alive)
  end

  scope "/authoring", as: :authoring do
    pipe_through([:browser, :authoring, :registration_captcha, :pow_email_layout])

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()

    # handle linking accounts when using a social account provider to login
    get("/auth/:provider/link", OliWeb.DeliveryController, :process_link_account_provider)
    get("/auth/:provider/link/callback", OliWeb.DeliveryController, :link_account_callback)

    delete("/signout", OliWeb.SessionController, :signout)
  end

  scope "/authoring" do
    pipe_through([:skip_csrf_protection, :authoring])

    pow_assent_authorization_post_callback_routes()
  end

  scope "/authoring", PowInvitation.Phoenix, as: :pow_invitation do
    pipe_through([:browser, :authoring, :registration_captcha])

    resources("/invitations", InvitationController, only: [:edit, :update])
  end

  scope "/delivery", PowInvitation.Phoenix, as: :delivery_pow_invitation do
    pipe_through([:browser, :delivery, :registration_captcha])

    resources("/invitations", InvitationController, only: [:edit, :update])
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through([:browser, :delivery, :authoring])

    get("/", StaticPageController, :index)
    get("/unauthorized", StaticPageController, :unauthorized)
    get("/not_found", StaticPageController, :not_found)

    # update session timezone information
    post("/update_timezone", StaticPageController, :update_timezone)
  end

  scope "/", OliWeb do
    pipe_through([:api])

    get("/api/v1/legacy_support", LegacySupportController, :index)
    post("/access_tokens", LtiController, :access_tokens)

    post("/help/create", HelpController, :create)
    post("/consent/cookie", CookieConsentController, :persist_cookies)
    get("/consent/cookie", CookieConsentController, :retrieve)

    get("/site.webmanifest", StaticPageController, :site_webmanifest)

    # update session timezone information
    post("/timezone", StaticPageController, :timezone)

    # update limited session information
    post("/set_session", StaticPageController, :set_session)

    # general health check for application & db
    get("/healthz", HealthController, :index)
  end

  scope "/.well-known", OliWeb do
    pipe_through([:api])

    get("/jwks.json", LtiController, :jwks)
  end

  # authorization protected routes
  scope "/authoring", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace])

    # keep a session active by periodically calling this endpoint
    get("/keep-alive", StaticPageController, :keep_alive, as: :author_keep_alive)

    live("/projects", Projects.ProjectsLive)
    live("/products/:product_id", Products.DetailsView)
    live("/products/:product_id/payments", Products.PaymentsView)
    live("/products/:section_slug/source_materials", Delivery.ManageSourceMaterials)

    live("/products/:section_slug/remix", Delivery.RemixSection, :product_remix,
      as: :product_remix
    )

    get(
      "/products/:product_id/payments/donwload_codes",
      PaymentController,
      :download_payment_codes
    )

    get("/products/:product_id/payments/:count", PaymentController, :download_codes)

    live("/account", Workspace.AccountDetailsLive)

    put("/account", WorkspaceController, :update_author)

    scope "/communities" do
      pipe_through([:community_admin])

      live("/", CommunityLive.IndexView)

      scope "/:community_id" do
        pipe_through([:authorize_community])

        live("/", CommunityLive.ShowView)
        live("/members", CommunityLive.MembersIndexView)

        scope "/associated" do
          live("/", CommunityLive.Associated.IndexView)
          live("/new", CommunityLive.Associated.NewView)
        end
      end
    end
  end

  scope "/authoring/project", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace])
    post("/", ProjectController, :create)
  end

  scope "/authoring/project", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace, :authorize_project])

    live_session :load_projects,
      on_mount: [Oli.LiveSessionPlugs.SetCurrentAuthor, Oli.LiveSessionPlugs.SetProject] do
      live("/:project_id/overview", Projects.OverviewLive)
      live("/:project_id", Projects.OverviewLive)
    end
  end

  scope "/authoring/project", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace, :authorize_project])

    # Project display pages
    live("/:project_id/publish", Projects.PublishView)
    post("/:project_id/datashop", ProjectController, :download_datashop)
    post("/:project_id/export", ProjectController, :download_export)
    post("/:project_id/insights", ProjectController, :download_analytics)
    post("/:project_id/duplicate", ProjectController, :clone_project)

    # Alternatives Groups
    live("/:project_id/alternatives", Resources.AlternativesEditor)

    # Activity Bank
    get("/:project_id/bank", ActivityBankController, :index)

    # Bibliography
    get("/:project_id/bibliography", BibliographyController, :index)

    # Objectives
    live("/:project_id/objectives", ObjectivesLive.Objectives)

    # Experiment management
    live("/:project_id/experiments", Experiments.ExperimentsView)
    get("/:project_id/experiments/segment.json", ExperimentController, :segment_download)
    get("/:project_id/experiments/experiment.json", ExperimentController, :experiment_download)

    # Curriculum
    live(
      "/:project_id/curriculum/:container_slug/edit/:revision_slug",
      Curriculum.ContainerLive,
      :edit
    )

    live("/:project_id/curriculum/:container_slug", Curriculum.ContainerLive, :index)

    live("/:project_id/curriculum/", Curriculum.ContainerLive, :index)

    live("/:project_id/pages/", Resources.PagesView)
    live("/:project_id/activities/", Resources.ActivitiesView)

    # Review/QA
    live("/:project_id/review", Qa.QaLive)

    # Author facing product view
    live("/:project_id/products", Products.ProductsView)

    # Preview
    get("/:project_id/preview", ResourceController, :preview)
    get("/:project_id/preview/:revision_slug", ResourceController, :preview)
    get("/:project_id/preview_fullscreen/:revision_slug", ResourceController, :preview_fullscreen)
    get("/:project_id/preview/:revision_slug/page/:page", ResourceController, :preview)

    # Editors
    get("/:project_id/resource/:revision_slug", ResourceController, :edit)

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
    # live "/:project_id/insights", Insights
  end

  if Application.compile_env!(:oli, :env) == :dev or Application.compile_env!(:oli, :env) == :test do
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

    get("/:project/alternatives", Api.ResourceController, :alternatives)
  end

  # Storage Service
  scope "/api/v1/storage/project/:project/resource", OliWeb do
    pipe_through([:api, :authoring_protected])

    get("/:resource", Api.ActivityController, :retrieve)
    post("/", Api.ActivityController, :bulk_retrieve)
    put("/", Api.ActivityController, :bulk_update)
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

  # Activity Bank Service
  scope "/api/v1/bank/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.ActivityBankController, :retrieve)
  end

  # Blueprint Service
  scope "/api/v1/blueprint", OliWeb do
    pipe_through([:api, :authoring_protected])

    get("/", Api.BlueprintController, :index)
  end

  # Objectives Service
  scope "/api/v1/objectives/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.ObjectivesController, :create)
    get("/", Api.ObjectivesController, :index)
    put("/objective/:objective", Api.ObjectivesController, :update)
  end

  # Tags Service
  scope "/api/v1/tags/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.TagController, :new)
    get("/", Api.TagController, :index)
  end

  # Bibliography Service
  scope "/api/v1/bibs/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/retrieve", Api.BibEntryController, :retrieve)
    post("/", Api.BibEntryController, :new)
    get("/", Api.BibEntryController, :index)
    delete("/entry/:entry", Api.BibEntryController, :delete)
    put("/entry/:entry", Api.BibEntryController, :update)
  end

  # Dynamic question variable evaluation service
  scope "/api/v1/variables", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.VariableEvaluationController, :evaluate)
  end

  scope "/api/v1/products", OliWeb do
    pipe_through([:api])

    get("/", Api.ProductController, :index)
  end

  scope "/api/v1/publishers", OliWeb do
    pipe_through([:api])

    get("/", Api.PublisherController, :index)
    get("/:publisher_id", Api.PublisherController, :show)
  end

  scope "/api/v1/payments", OliWeb do
    pipe_through([:api])
    # This endpoint is secured via an API token
    post("/", Api.PaymentController, :new)
  end

  scope "/api/v1", OliWeb do
    pipe_through([:api])
    # These endpoints are secured via an API token
    resources("/registration/", Api.ActivityRegistrationController, only: [:create])

    post("/automation_setup", Api.AutomationSetupController, :setup)
    post("/automation_teardown", Api.AutomationSetupController, :teardown)
  end

  scope "/api/v1/page_lifecycle", OliWeb do
    pipe_through([:api, :delivery_protected])
    post("/", Api.PageLifecycleController, :transition)
  end

  scope "/api/v1/payments", OliWeb do
    pipe_through([:api, :delivery_protected])

    # String payment intent creation
    post("/s/create-payment-intent", PaymentProviders.StripeController, :init_intent)
    post("/s/success", PaymentProviders.StripeController, :success)
    post("/s/failure", PaymentProviders.StripeController, :failure)

    post("/c/create-payment-form", PaymentProviders.CashnetController, :init_form)
  end

  scope "/api/v1/payments", OliWeb do
    pipe_through([:skip_csrf_protection, :delivery])

    post("/c/success", PaymentProviders.CashnetController, :success)
    post("/c/failure", PaymentProviders.CashnetController, :failure)
    get("/c/signoff", PaymentProviders.CashnetController, :signoff)
  end

  # Endpoints for client-side scheduling UI
  scope "/api/v1/scheduling/:section_slug", OliWeb.Api do
    pipe_through([:api, :delivery_and_admin, :require_section])

    put("/", SchedulingController, :update)
    get("/", SchedulingController, :index)
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

    post(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid/upload",
      Api.AttemptController,
      :file_upload
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

  # routes for content element api endpoints
  scope "/api/v1/content_types", OliWeb do
    pipe_through([:api])

    post("/ecl", Api.ECLController, :eval)
  end

  scope "/api/v1/lti", OliWeb, as: :api do
    pipe_through([:api, :authoring_protected])

    resources("/platforms", Api.PlatformInstanceController)
  end

  # LTI routes
  scope "/lti", OliWeb do
    pipe_through([:lti, :www_url_form, :delivery])

    post("/login", LtiController, :login)
    get("/login", LtiController, :login)
    post("/launch", LtiController, :launch)
    post("/test", LtiController, :test)

    get("/developer_key.json", LtiController, :developer_key_json)

    post("/register", LtiController, :request_registration)

    get("/authorize_redirect", LtiController, :authorize_redirect)
  end

  ###
  # Section Routes
  ###

  ### Sections - View Public Open and Free Courses
  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :delivery_protected,
      :pow_email_layout
    ])

    live("/", Delivery.OpenAndFreeIndex)

    live("/join/invalid", Sections.InvalidSectionInviteView)
  end

  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_protected,
      :pow_email_layout
    ])

    get("/join/:section_invite_slug", DeliveryController, :enroll_independent)
  end

  # Sections - Independent Learner Section Creation
  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :delivery_protected,
      :require_independent_instructor
    ])

    live("/independent/create", Delivery.NewCourse, :independent_learner, as: :select_source)
    resources("/independent/", OpenAndFreeController, as: :independent_sections, except: [:index])
  end

  ### Sections - Payments
  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_protected,
      :pow_email_layout
    ])

    get("/:section_slug/payment", PaymentController, :guard)
    get("/:section_slug/payment/new", PaymentController, :make_payment)
    get("/:section_slug/payment/code", PaymentController, :use_code)
    post("/:section_slug/payment/code", PaymentController, :apply_code)
  end

  ### Sections - Student Dashboard

  scope "/sections/:section_slug/student_dashboard/:student_id", OliWeb do
    pipe_through([
      :browser,
      :delivery_and_admin,
      :pow_email_layout
    ])

    live_session :student_dashboard,
      on_mount: [
        OliWeb.LiveSessionPlugs.SetRouteName,
        OliWeb.Delivery.StudentDashboard.InitialAssigns
      ],
      root_layout: {OliWeb.LayoutView, :delivery_student_dashboard} do
      live("/:active_tab", Delivery.StudentDashboard.StudentDashboardLive,
        metadata: %{route_name: :student_dashboard}
      )
    end

    live_session :student_dashboard_preview,
      on_mount: [
        OliWeb.LiveSessionPlugs.SetRouteName,
        OliWeb.Delivery.StudentDashboard.InitialAssigns
      ],
      root_layout: {OliWeb.LayoutView, :delivery_student_dashboard} do
      live(
        "/preview/:active_tab",
        Delivery.StudentDashboard.StudentDashboardLive,
        :preview,
        metadata: %{route_name: :student_dashboard_preview}
      )
    end
  end

  ### Sections - Instructor Dashboard
  #### preview routes must come before the non-preview routes to properly match
  scope "/sections/:section_slug/instructor_dashboard/preview", OliWeb do
    pipe_through([
      :browser,
      :delivery_and_admin,
      :pow_email_layout
    ])

    live_session :instructor_dashboard_preview,
      on_mount: OliWeb.Delivery.InstructorDashboard.InitialAssigns,
      root_layout: {OliWeb.LayoutView, :delivery_dashboard} do
      live("/", Delivery.InstructorDashboard.InstructorDashboardLive, :preview)
      live("/:view", Delivery.InstructorDashboard.InstructorDashboardLive, :preview)
      live("/:view/:active_tab", Delivery.InstructorDashboard.InstructorDashboardLive, :preview)
    end
  end

  scope "/sections/:section_slug/instructor_dashboard", OliWeb do
    pipe_through([
      :browser,
      :delivery_and_admin,
      :pow_email_layout
    ])

    get(
      "/downloads/progress/:container_id",
      MetricsController,
      :download_container_progress
    )

    get(
      "/downloads/course_content",
      DeliveryController,
      :download_course_content_info
    )

    get(
      "/downloads/students_progress",
      DeliveryController,
      :download_students_progress
    )

    get(
      "/downloads/learning_objectives",
      DeliveryController,
      :download_learning_objectives
    )

    get(
      "/downloads/quiz_scores",
      DeliveryController,
      :download_quiz_scores
    )

    get(
      "/",
      DeliveryController,
      :instructor_dashboard
    )

    live_session :instructor_dashboard,
      on_mount: OliWeb.Delivery.InstructorDashboard.InitialAssigns,
      root_layout: {OliWeb.LayoutView, :delivery_dashboard} do
      live("/:view", Delivery.InstructorDashboard.InstructorDashboardLive)
      live("/:view/:active_tab", Delivery.InstructorDashboard.InstructorDashboardLive)

      live(
        "/:view/:active_tab/:assessment_id",
        Delivery.InstructorDashboard.InstructorDashboardLive
      )
    end
  end

  ### Sections - Student Course Delivery
  scope "/sections/:section_slug", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery,
      :require_exploration_pages,
      :delivery_protected,
      :maybe_gated_resource,
      :enforce_enroll_and_paywall,
      :ensure_user_section_visit,
      :force_required_survey,
      :pow_email_layout
    ])

    get("/overview", PageDeliveryController, :index)

    get("/exploration", PageDeliveryController, :exploration)
    get("/discussion", PageDeliveryController, :discussion)
    get("/my_assignments", PageDeliveryController, :assignments)
    get("/container/:revision_slug", PageDeliveryController, :container)
    get("/page/:revision_slug", PageDeliveryController, :page)
    get("/page_fullscreen/:revision_slug", PageDeliveryController, :page_fullscreen)
    get("/page/:revision_slug/page/:page", PageDeliveryController, :page)
    get("/page/:revision_slug/attempt", PageDeliveryController, :start_attempt)

    post(
      "/page/:revision_slug/attempt_protected",
      PageDeliveryController,
      :start_attempt_protected
    )

    post(
      "/page",
      PageDeliveryController,
      :navigate_by_index
    )

    get(
      "/page/:revision_slug/attempt/:attempt_guid/review",
      PageDeliveryController,
      :review_attempt
    )
  end

  ### Sections - Preview
  scope "/sections/:section_slug/preview", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :require_exploration_pages,
      :authorize_section_preview,
      :delivery_and_admin,
      :delivery_layout,
      :pow_email_layout
    ])

    # Redirect deprecated routes
    get("/overview", PageDeliveryController, :index_preview)
    get("/exploration", PageDeliveryController, :exploration_preview)
    get("/discussion", PageDeliveryController, :discussion_preview)
    get("/my_assignments", PageDeliveryController, :assignments_preview)
    get("/container/:revision_slug", PageDeliveryController, :container_preview)
    get("/page/:revision_slug", PageDeliveryController, :page_preview)
    get("/page/:revision_slug/page/:page", PageDeliveryController, :page_preview)
    get("/page/:revision_slug/selection/:selection_id", ActivityBankController, :preview)
  end

  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :delivery_protected
    ])

    live_session :load_section,
      on_mount: [
        Oli.LiveSessionPlugs.SetSection,
        Oli.LiveSessionPlugs.SetCurrentUser,
        Oli.LiveSessionPlugs.RequireEnrollment
      ] do
      live(
        "/:section_slug/welcome",
        Delivery.StudentOnboarding.Wizard
      )
    end
  end

  ### Sections - Management
  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_and_admin,
      :pow_email_layout
    ])

    live("/:section_slug", Sections.OverviewView)

    live("/:section_slug/grades/lms", Grades.GradesLive)
    live("/:section_slug/grades/lms_grade_updates", Grades.BrowseUpdatesView)
    live("/:section_slug/grades/failed", Grades.FailedGradeSyncLive)
    live("/:section_slug/grades/observe", Grades.ObserveGradeUpdatesView)
    live("/:section_slug/grades/gradebook", Grades.GradebookView)
    live("/:section_slug/scoring", ManualGrading.ManualGradingView)
    live("/:section_slug/snapshots", Snapshots.SnapshotsView)
    live("/:section_slug/progress/:user_id/:resource_id", Progress.StudentResourceView)
    live("/:section_slug/progress/:user_id", Progress.StudentView)
    get("/:section_slug/grades/export", PageDeliveryController, :export_gradebook)
    live("/:section_slug/source_materials", Delivery.ManageSourceMaterials, as: :source_materials)
    live("/:section_slug/remix", Delivery.RemixSection)
    live("/:section_slug/remix/:section_resource_slug", Delivery.RemixSection)
    live("/:section_slug/enrollments", Sections.EnrollmentsViewLive)
    post("/:section_slug/enrollments", InviteController, :create_bulk)

    live_session :enrolled_students,
      on_mount: [
        OliWeb.LiveSessionPlugs.SetRouteName,
        OliWeb.Delivery.StudentDashboard.InitialAssigns
      ],
      root_layout: {OliWeb.LayoutView, :delivery_student_dashboard} do
      live(
        "/:section_slug/enrollments/students/:student_id/:active_tab",
        Delivery.StudentDashboard.StudentDashboardLive,
        as: :enrollment_student_info,
        metadata: %{route_name: :enrollments_student_info}
      )
    end

    post("/:section_slug/enrollments/export", PageDeliveryController, :export_enrollments)
    live("/:section_slug/invitations", Sections.InviteView)
    live("/:section_slug/schedule", Sections.ScheduleView)
    live("/:section_slug/edit", Sections.EditView)
    live("/:section_slug/gating_and_scheduling", Sections.GatingAndScheduling)
    live("/:section_slug/gating_and_scheduling/new", Sections.GatingAndScheduling.New)

    live("/:section_slug/debugger/:attempt_guid", Attempt.AttemptLive)

    live(
      "/:section_slug/gating_and_scheduling/new/:parent_gate_id",
      Sections.GatingAndScheduling.New
    )

    live("/:section_slug/gating_and_scheduling/edit/:id", Sections.GatingAndScheduling.Edit)

    live(
      "/:section_slug/gating_and_scheduling/exceptions/:parent_gate_id",
      Sections.GatingAndScheduling
    )

    get(
      "/:section_slug/review/:attempt_guid",
      PageDeliveryController,
      :review_attempt,
      as: :instructor_review
    )

    live("/:section_slug/collaborative_spaces", CollaborationLive.IndexView, :instructor,
      as: :collab_spaces_index
    )

    live(
      "/:section_slug/assessment_settings/:active_tab/:assessment_id",
      Sections.AssessmentSettings.SettingsLive
    )
  end

  scope "/api/v1/state/course/:section_slug/activity_attempt", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_and_admin,
      :pow_email_layout
    ])

    get("/:activity_attempt_guid", Api.AttemptController, :get_activity_attempt)
  end

  ### Sections - Enrollment
  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery,
      :delivery_layout,
      :pow_email_layout
    ])

    get("/:section_slug/enroll", DeliveryController, :show_enroll)
    post("/:section_slug/enroll", DeliveryController, :process_enroll)
  end

  # Delivery Auth (Signin)
  scope "/course", OliWeb do
    pipe_through([:browser, :delivery, :delivery_layout, :pow_email_layout])

    get("/signin", DeliveryController, :signin)
    get("/create_account", DeliveryController, :create_account)
  end

  # Delivery Auth (Signout)
  scope "/course", OliWeb do
    pipe_through([:browser, :delivery_protected, :pow_email_layout])

    delete("/signout", SessionController, :signout)
    get("/signout", SessionController, :signout)
  end

  scope "/course", OliWeb do
    pipe_through([:browser, :delivery_protected, :pow_email_layout])

    get("/link_account", DeliveryController, :link_account)
    post("/link_account", DeliveryController, :process_link_account_user)
    get("/create_and_link_account", DeliveryController, :create_and_link_account)
    post("/create_and_link_account", DeliveryController, :process_create_and_link_account_user)
  end

  scope "/course", OliWeb do
    pipe_through([:browser, :delivery_protected, :require_lti_params, :pow_email_layout])

    get("/", DeliveryController, :index)
    live("/select_project", Delivery.NewCourse, :lms_instructor, as: :select_source)

    post("/research_consent", DeliveryController, :research_consent)
  end

  ### Admin Dashboard / Telemetry
  scope "/admin", OliWeb do
    pipe_through([:browser, :authoring_protected, :admin])

    live_dashboard("/dashboard",
      metrics: {OliWeb.Telemetry, :non_distributed_metrics},
      ecto_repos: [Oli.Repo],
      session: {__MODULE__, :with_session, []}
    )

    resources("/platform_instances", PlatformInstanceController)
  end

  ### Admin Portal / Management
  scope "/admin", OliWeb do
    pipe_through([
      :browser,
      :authoring_protected,
      :workspace,
      :admin,
      :pow_email_layout
    ])

    get("/activity_review", ActivityReviewController, :index)

    # General
    live("/", Admin.AdminView)
    live("/features", Features.FeaturesLive)
    live("/api_keys", ApiKeys.ApiKeysLive)
    live("/products", Products.ProductsView)
    live("/products/:product_id/discounts", Products.Payments.Discounts.ProductsIndexView)
    live("/collaborative_spaces", CollaborationLive.IndexView, :admin, as: :collab_spaces_index)

    live(
      "/products/:product_id/discounts/new",
      Products.Payments.Discounts.ShowView,
      :product_new,
      as: :discount
    )

    live(
      "/products/:product_id/discounts/:discount_id",
      Products.Payments.Discounts.ShowView,
      :product,
      as: :discount
    )

    # Section Management (+ Open and Free)
    live("/sections", Sections.SectionsView)
    live("/open_and_free/create", Delivery.NewCourse, :admin, as: :select_source)
    resources("/open_and_free", OpenAndFreeController, as: :admin_open_and_free)
    live("/open_and_free/:section_slug/remix", Delivery.RemixSection, as: :open_and_free_remix)

    # Institutions, LTI Registrations and Deployments
    resources("/institutions", InstitutionController)

    live(
      "/institutions/:institution_id/discount",
      Products.Payments.Discounts.ShowView,
      :institution,
      as: :discount
    )

    live("/institutions/:institution_id/research_consent", Admin.Institutions.ResearchConsentView,
      as: :institution
    )

    live(
      "/institutions/:institution_id/sections_and_students/:selected_tab",
      Admin.Institutions.SectionsAndStudentsView
    )

    live("/registrations", Admin.RegistrationsView)

    resources("/registrations", RegistrationController, except: [:index]) do
      resources("/deployments", DeploymentController, except: [:index, :show])
    end

    put("/approve_registration", InstitutionController, :approve_registration)
    delete("/pending_registration/:id", InstitutionController, :remove_registration)

    # Communities
    live("/communities/new", CommunityLive.NewView)

    # System Message Banner
    live("/system_messages", SystemMessageLive.IndexView)

    # Publishers
    live("/publishers", PublisherLive.IndexView)
    live("/publishers/new", PublisherLive.NewView)
    live("/publishers/:publisher_id", PublisherLive.ShowView)

    # Course Ingestion
    get("/ingest/upload", IngestController, :index)
    post("/ingest/ingest", IngestController, :upload)
    live("/ingest", Admin.Ingest)
    live("/ingest/process", Admin.IngestV2)

    # Authoring Activity Management
    get("/manage_activities", ActivityManageController, :index)
    put("/manage_activities/make_global/:activity_slug", ActivityManageController, :make_global)
    put("/manage_activities/make_private/:activity_slug", ActivityManageController, :make_private)

    put(
      "/manage_activities/make_globally_visible/:activity_slug",
      ActivityManageController,
      :make_globally_visible
    )

    put(
      "/manage_activities/make_admin_visible/:activity_slug",
      ActivityManageController,
      :make_admin_visible
    )

    # Branding
    resources("/brands", BrandController)

    # Admin Author/User Account Management
    live("/authors", Users.AuthorsView)
    live("/authors/:user_id", Users.AuthorsDetailView)
    live("/users", Users.UsersView)
    live("/users/:user_id", Users.UsersDetailView)
    get("/invite", InviteController, :index)
    post("/invite", InviteController, :create)
    post("/accounts/resend_user_confirmation_link", PowController, :resend_user_confirmation_link)

    post(
      "/accounts/resend_author_confirmation_link",
      PowController,
      :resend_author_confirmation_link
    )

    post("/accounts/send_user_password_reset_link", PowController, :send_user_password_reset_link)

    post(
      "/accounts/send_author_password_reset_link",
      PowController,
      :send_author_password_reset_link
    )
  end

  scope "/project", OliWeb do
    pipe_through([
      :browser,
      :authoring_protected,
      :workspace,
      :authorize_project,
      :admin
    ])

    live("/:project_id/history/slug/:slug", RevisionHistory)

    live("/:project_id/history/resource_id/:resource_id", RevisionHistory,
      as: :history_by_resource_id
    )
  end

  # Support for cognito JWT auth currently used by Infiniscope
  scope "/cognito", OliWeb do
    pipe_through([:sso, :delivery])

    get("/launch", CognitoController, :index)
    get("/launch/products/:product_slug", CognitoController, :launch)
    get("/launch/projects/:project_slug", CognitoController, :launch)
  end

  scope "/cognito", OliWeb do
    pipe_through([:sso, :authoring])

    get("/launch_clone/products/:product_slug", CognitoController, :launch_clone,
      as: :product_clone
    )

    get("/launch_clone/projects/:project_slug", CognitoController, :launch_clone,
      as: :project_clone
    )
  end

  scope "/cognito", OliWeb do
    pipe_through([
      :browser,
      :authoring_protected,
      :workspace
    ])

    get("/prompt_clone/projects/:project_slug", CognitoController, :prompt_clone,
      as: :prompt_project_clone
    )

    get("/clone/:project_slug", CognitoController, :clone)
  end

  scope "/cognito", OliWeb do
    pipe_through([
      :browser,
      :delivery_protected,
      :require_independent_instructor
    ])

    get("/prompt_create/projects/:project_slug", CognitoController, :prompt_create,
      as: :prompt_project_create
    )

    get("/prompt_create/products/:product_slug", CognitoController, :prompt_create,
      as: :prompt_product_create
    )
  end

  # routes only accessible when load testing mode is enabled. These routes exist solely
  # to allow the load testing framework to do things like query for the available open and free
  # sections, to query for all of the pages in an individual section, etc.

  scope "/api/v1/testing", OliWeb do
    pipe_through([:api])

    get("/openfree", Api.OpenAndFreeController, :index)
  end

  # routes only accessible to developers
  if Application.compile_env!(:oli, :env) == :dev or Application.compile_env!(:oli, :env) == :test do
    # web interface for viewing sent emails during development
    forward("/dev/sent_emails", Bamboo.SentEmailViewerPlug)

    scope "/api/v1/testing", OliWeb do
      pipe_through([:api])

      post("/rules", Api.RulesEngineController, :execute)
    end

    scope "/dev", OliWeb do
      pipe_through([:browser])

      get("/flame_graphs", DevController, :flame_graphs)

      live_storybook("/storybook", backend_module: OliWeb.Storybook)
    end
  end
end
