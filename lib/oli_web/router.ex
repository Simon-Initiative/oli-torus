defmodule OliWeb.Router do
  use OliWeb, :router

  import Phoenix.LiveDashboard.Router
  import OliWeb.UserAuth
  import OliWeb.AuthorAuth

  ### BASE PIPELINES ###
  # We have five "base" pipelines: :browser, :api, :lti, :skip_csrf_protection, and :sso
  # All of the other pipelines are to be used as additions onto one of these four base pipelines

  # pipeline for all browser based routes
  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_current_author)
    plug(:fetch_current_user)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {OliWeb.LayoutView, :default})
    plug(:put_layout, html: {OliWeb.LayoutView, :app})
    plug(:put_secure_browser_headers)
    plug(Oli.Plugs.LoadTestingCSRFBypass)
    plug(:protect_from_forgery)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
    plug(OliWeb.Plugs.SessionContext)
    plug(OliWeb.Plugs.HeaderSizeLogger)
  end

  # pipline for REST api endpoint routes
  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_current_author)
    plug(:fetch_current_user)
    plug(:fetch_live_flash)
    plug(:put_secure_browser_headers)
    plug(OpenApiSpex.Plug.PutApiSpec, module: OliWeb.ApiSpec)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
    plug(OliWeb.Plugs.SessionContext)
  end

  pipeline :text_api do
    plug(:accepts, ["text/plain"])
    plug(:fetch_session)
    plug(:fetch_current_user)
    plug(:put_secure_browser_headers)
    plug(Plug.Telemetry, event_prefix: [:oli, :plug])
    plug(OliWeb.Plugs.SessionContext)
  end

  # pipeline for LTI launch endpoints
  pipeline :lti do
    plug(:fetch_session)
    plug(:fetch_current_author)
    plug(:fetch_current_user)
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

  # pipeline for MCP (Model Context Protocol) endpoints
  pipeline :mcp_api do
    # The Anubis MCP server handles its own content negotiation,
    # so we don't use Phoenix's accepts plug here
    # Authentication is now handled in Oli.MCP.Server.init/2
  end

  ### PIPELINE EXTENSIONS ###
  # Extend the base pipelines specific routes

  pipeline :authoring do
    # Disable caching of resources in authoring
    plug(Oli.Plugs.NoCache)
  end

  pipeline :delivery do
    plug(Oli.Plugs.SetVrAgentValue)
    plug(OliWeb.Plugs.AllowIframe)
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

  pipeline :require_section do
    plug(Oli.Plugs.RequireSection)
  end

  pipeline :force_required_survey do
    plug(Oli.Plugs.ForceRequiredSurvey)
  end

  pipeline :enforce_paywall do
    plug(Oli.Plugs.EnforcePaywall)
  end

  pipeline :require_enrollment do
    plug(OliWeb.Plugs.RequireEnrollment)
  end

  pipeline :ensure_datashop_id do
    plug(OliWeb.Plugs.EnsureDatashopId)
  end

  pipeline :ensure_research_consent do
    plug(Oli.Plugs.EnsureResearchConsent)
  end

  pipeline :authorize_section_preview do
    plug(Oli.Plugs.AuthorizeSectionPreview)
  end

  # Ensure that we have a logged in user
  pipeline :delivery_protected do
    plug(:delivery)

    plug(OliWeb.Plugs.MaybeSkipEmailVerification)

    plug(:auto_enroll_admin)
    plug(:require_authenticated_user)

    plug(Oli.Plugs.RemoveXFrameOptions)
    plug(OliWeb.Plugs.SetToken)
    plug(:ensure_datashop_id)

    plug(:delivery_layout)
  end

  pipeline :authoring_protected do
    plug(:authoring)

    plug(:require_authenticated_author)
  end

  pipeline :require_authenticated_admin do
    plug(:require_authenticated_author)

    plug(:require_admin)
  end

  pipeline :require_authenticated_account_admin do
    plug(:require_authenticated_author)

    plug(:require_account_admin)
  end

  pipeline :require_authenticated_content_admin do
    plug(:require_authenticated_author)

    plug(:require_content_admin)
  end

  pipeline :require_authenticated_system_admin do
    plug(:require_authenticated_author)

    plug(:require_system_admin)
  end

  # parse url encoded forms
  pipeline :www_url_form do
    plug(Plug.Parsers, parsers: [:urlencoded])
  end

  pipeline :authorize_project do
    plug(Oli.Plugs.AuthorizeProject)
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
    plug(OliWeb.Plugs.EnsureUserSectionVisit)
  end

  pipeline :delivery_preview do
    plug(Oli.Plugs.DeliveryPreview)
  end

  pipeline :put_license, do: plug(:set_license)
  def set_license(conn, _), do: Plug.Conn.assign(conn, :has_license, true)

  pipeline :redirect_by_attempt_state do
    plug(OliWeb.Plugs.RedirectByAttemptState)
  end

  pipeline :student, do: plug(Oli.Plugs.SetUserType, :student)

  pipeline :restrict_admin_access do
    plug(Oli.Plugs.RestrictAdminAccess)
  end

  ### ROUTES ###

  ## MCP (Model Context Protocol) routes
  scope "/mcp" do
    pipe_through [:mcp_api]

    forward "/", Anubis.Server.Transport.StreamableHTTP.Plug, server: Oli.MCP.Server
  end

  ## Authentication routes

  # allow access to non-authenticated users or guest users for sign in and account creation
  scope "/", OliWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated_and_not_guest]

    live_session :redirect_if_user_is_authenticated_and_not_guest,
      on_mount: [{OliWeb.UserAuth, :redirect_if_user_is_authenticated_and_not_guest}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", OliWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{OliWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/instructors/log_in", UserLoginLive, :instructor_new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end
  end

  scope "/", OliWeb do
    pipe_through [:browser, :require_authenticated_user, :require_independent_user]

    live_session :require_authenticated_user,
      root_layout: {OliWeb.LayoutView, :delivery},
      layout: {OliWeb.Layouts, :workspace},
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetSidebar,
        OliWeb.LiveSessionPlugs.SetPreviewMode
      ] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", OliWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{OliWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end

    # OAuth OIDC SSO provider routes for social login
    resources "/users/auth/:provider", UserAuthorizationController,
      singleton: true,
      only: [:new, :delete]

    get "/users/auth/:provider/callback", UserAuthorizationController, :callback

    get "/certificates/", CertificateController, :index
    post "/certificates/verify", CertificateController, :verify
  end

  scope "/", OliWeb do
    pipe_through [
      :browser,
      :delivery,
      :require_authenticated_user,
      :fetch_current_author
    ]

    live "/users/link_account", LinkAccountLive, :link_account
  end

  scope "/", OliWeb do
    pipe_through [:browser, :redirect_if_author_is_authenticated]

    live_session :redirect_if_author_is_authenticated,
      on_mount: [{OliWeb.AuthorAuth, :redirect_if_author_is_authenticated}] do
      live "/authors/register", AuthorRegistrationLive, :new
      live "/authors/log_in", AuthorLoginLive, :new
      live "/authors/reset_password", AuthorForgotPasswordLive, :new
      live "/authors/reset_password/:token", AuthorResetPasswordLive, :edit
    end

    post "/authors/log_in", AuthorSessionController, :create
  end

  scope "/", OliWeb do
    pipe_through [:browser, :require_authenticated_author]

    live_session :require_authenticated_author,
      root_layout: {OliWeb.LayoutView, :delivery},
      layout: {OliWeb.Layouts, :workspace},
      on_mount: [
        {OliWeb.AuthorAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetSidebar,
        OliWeb.LiveSessionPlugs.SetPreviewMode
      ] do
      live "/authors/settings", AuthorSettingsLive, :edit
      live "/authors/settings/confirm_email/:token", AuthorSettingsLive, :confirm_email
    end
  end

  scope "/", OliWeb do
    pipe_through [:browser]

    delete "/authors/log_out", AuthorSessionController, :delete

    live_session :current_author,
      on_mount: [{OliWeb.AuthorAuth, :mount_current_author}] do
      live "/authors/confirm/:token", AuthorConfirmationLive, :edit
      live "/authors/confirm", AuthorConfirmationInstructionsLive, :new
    end

    # OAuth OIDC SSO provider routes for social login
    resources "/authors/auth/:provider", AuthorAuthorizationController,
      singleton: true,
      only: [:new, :delete]

    get "/authors/auth/:provider/callback", AuthorAuthorizationController, :callback
  end

  scope "/" do
    pipe_through([:api])
    post("/jcourse/superactivity/server", OliWeb.LegacySuperactivityController, :process)

    get(
      "/jcourse/superactivity/context/:attempt_guid",
      OliWeb.LegacySuperactivityController,
      :context
    )

    post("/jcourse/dashboard/log/server", OliWeb.LegacyLogsController, :process)
  end

  scope "/", OliWeb do
    pipe_through([:browser, :delivery_protected])

    get("/research_consent", DeliveryController, :show_research_consent)
    post("/research_consent", DeliveryController, :research_consent)
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through([:browser, :delivery, :authoring])

    get("/", StaticPageController, :index)
    get("/unauthorized", StaticPageController, :unauthorized)
    get("/not_found", StaticPageController, :not_found)

    # update session timezone information
    get("/timezones", StaticPageController, :list_timezones)
    post("/update_timezone", StaticPageController, :update_timezone)
  end

  scope "/", OliWeb do
    pipe_through([:api])

    get("/api/v1/legacy_support", LegacySupportController, :index)

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

    get("/jwks.json", Api.LtiController, :jwks)
  end

  # authorization protected routes
  scope "/authoring", OliWeb do
    pipe_through([:browser, :authoring_protected, :workspace])

    live("/projects", Projects.ProjectsLive)
    live("/products/:product_id", Products.DetailsView)
    live("/products/:product_id/payments", Products.PaymentsView)
    live("/products/:section_slug/source_materials", Delivery.ManageSourceMaterials)

    live("/products/:product_id/certificate_settings", Certificates.CertificatesSettingsLive,
      metadata: %{route_name: :authoring}
    )

    live("/products/:section_slug/remix", Delivery.RemixSection, :product_remix,
      as: :product_remix
    )

    get(
      "/products/:product_id/downloads/granted_certificates",
      GrantedCertificatesController,
      :download_granted_certificates
    )

    get(
      "/products/:product_id/payments/download_codes",
      PaymentController,
      :download_payment_codes
    )

    get("/products/:product_id/payments/:count", PaymentController, :download_codes)

    scope "/communities" do
      pipe_through([:community_admin, :require_authenticated_account_admin])

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

    # Project display pages
    live("/:project_id/publish", Projects.PublishView)
    post("/:project_id/duplicate", ProjectController, :clone_project)
    post("/:project_id/triggers", ProjectController, :enable_triggers)

    live("/:project_id/embeddings", Search.EmbeddingsLive)

    # Alternatives Groups
    live("/:project_id/alternatives", Resources.AlternativesEditor)

    # Activity Bank
    get("/:project_id/bank", ActivityBankController, :index)

    # Bibliography
    get("/:project_id/bibliography", BibliographyController, :index)

    # Objectives
    live("/:project_id/objectives", ObjectivesLive.Objectives)

    # Experiment management

    get("/:project_id/experiments/segment.json", ExperimentController, :segment_download)
    get("/:project_id/experiments/experiment.json", ExperimentController, :experiment_download)
    live("/:project_id/experiments", Experiments.ExperimentsView)

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

    # Insights
    live "/:project_id/insights", Insights
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

    post("/:project/create/activity/bulk", Api.ActivityController, :create_bulk)
    post("/:project/delete/activity/bulk", Api.ActivityController, :delete_bulk)

    put("/test/evaluate", Api.ActivityController, :evaluate)
    put("/test/transform", Api.ActivityController, :transform)

    post("/:project/lock/:resource", Api.LockController, :acquire)
    delete("/:project/lock/:resource", Api.LockController, :release)

    get("/:project/alternatives", Api.ResourceController, :alternatives)

    get("/:project/activities/with_report", Api.ResourceController, :activities_with_report)
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
    pipe_through([:api, :require_section, :delivery_protected])

    get("/:resource", Api.ActivityController, :retrieve_delivery)
    post("/", Api.ActivityController, :bulk_retrieve_delivery)
  end

  # Media Service
  scope "/api/v1/media/project/:project", OliWeb do
    pipe_through([:api, :authoring_protected])

    post("/", Api.MediaController, :create)
    post("/delete", Api.MediaController, :delete)
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
    post("/c/signoff", PaymentProviders.CashnetController, :signoff)
  end

  # Endpoints for client-side scheduling UI
  scope "/api/v1/scheduling/:section_slug", OliWeb.Api do
    pipe_through([:api, :require_section, :delivery_protected])

    put("/", SchedulingController, :update)
    put("/agenda", SchedulingController, :update_agenda)
    get("/", SchedulingController, :index)
    delete("/", SchedulingController, :clear)
  end

  # AI activation point endpoints
  scope "/api/v1/triggers/:section_slug", OliWeb.Api do
    pipe_through([:api, :require_section, :delivery_protected])

    post("/", TriggerPointController, :invoke)
  end

  # User State Service, instrinsic state
  scope "/api/v1/state/course/:section_slug/activity_attempt", OliWeb do
    pipe_through([:api, :require_section, :delivery_protected])

    post("/", Api.AttemptController, :bulk_retrieve)

    post("/:activity_attempt_guid", Api.AttemptController, :new_activity)
    put("/:activity_attempt_guid", Api.AttemptController, :submit_activity)
    patch("/:activity_attempt_guid", Api.AttemptController, :save_activity)

    patch("/:activity_attempt_guid/active", Api.AttemptController, :save_active_activity)

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

    patch(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid/active",
      Api.AttemptController,
      :save_active_part
    )

    get(
      "/:activity_attempt_guid/part_attempt/:part_attempt_guid/hint",
      Api.AttemptController,
      :get_hint
    )
  end

  scope "/api/v1/discussion/:section_slug/:resource_id", OliWeb do
    pipe_through([:api, :require_section, :delivery_protected])

    get("/", Api.DirectedDiscussionController, :get_discussion)
    post("/", Api.DirectedDiscussionController, :create_post)
    delete("/:post_id", Api.DirectedDiscussionController, :delete_post)
  end

  # Delivery facing XAPI endpoints
  scope "/api/v1/xapi/delivery", OliWeb do
    pipe_through([:api, :delivery_protected])

    post("/", Api.XAPIController, :emit)
  end

  # Delivery facing Activity report endpoints
  scope "/api/v1/activity/report/:section_id/:resource_id", OliWeb do
    pipe_through([:api, :delivery_protected])

    get("/", Api.ActivityReportDataController, :fetch)
  end

  # User State Service, extrinsic state
  scope "/api/v1/state", OliWeb do
    pipe_through([:api, :delivery_protected])

    get("/", Api.GlobalStateController, :read)
    put("/", Api.GlobalStateController, :upsert)
    delete("/", Api.GlobalStateController, :delete)
  end

  # Raw text blob service
  scope "/api/v1/blob", OliWeb do
    pipe_through([:text_api, :delivery_protected])

    get("/user/:key", Api.BlobStorageController, :read_user_key)
    put("/user/:key", Api.BlobStorageController, :write_user_key)
    get("/:key", Api.BlobStorageController, :read_key)
    put("/:key", Api.BlobStorageController, :write_key)
  end

  scope "/api/v1/state/course/:section_slug", OliWeb do
    pipe_through([:api, :require_section, :delivery_protected])

    get("/", Api.SectionStateController, :read)
    put("/", Api.SectionStateController, :upsert)
    delete("/", Api.SectionStateController, :delete)

    get(
      "/resource_attempt/:resource_attempt_guid",
      Api.ResourceAttemptStateController,
      :read
    )

    put(
      "/resource_attempt/:resource_attempt_guid",
      Api.ResourceAttemptStateController,
      :upsert
    )

    delete(
      "/resource_attempt/:resource_attempt_guid",
      Api.ResourceAttemptStateController,
      :delete
    )
  end

  # routes for content element api endpoints
  scope "/api/v1/content_types", OliWeb do
    pipe_through([:api])

    post("/ecl", Api.ECLController, :eval)
  end

  # LTI routes
  scope "/lti", OliWeb do
    pipe_through([:api])

    # LTI platform services access tokens
    post("/auth/token", Api.LtiController, :auth_token)

    post("/deep_link/:section_slug/:resource_id", LtiController, :deep_link)
  end

  scope "/lti", OliWeb do
    pipe_through([:lti, :www_url_form, :delivery])

    post("/login", LtiController, :login)
    get("/login", LtiController, :login)

    post("/launch", LtiController, :launch)
    post("/test", LtiController, :test)

    get("/developer_key.json", Api.LtiController, :developer_key_json)

    post("/register", LtiController, :request_registration)

    get("/authorize_redirect", LtiController, :authorize_redirect)
  end

  # LTI 1.3 AGS endpoints
  scope "/lti/lineitems/:page_attempt_guid/:activity_resource_id", OliWeb.Api do
    pipe_through([:api])
    get "/results", LtiAgsController, :get_result
    post "/scores", LtiAgsController, :post_score
  end

  ### Workspaces
  scope "/workspaces", OliWeb.Workspaces do
    pipe_through([:browser, :authoring_protected])

    live_session :authoring_workspaces,
      root_layout: {OliWeb.LayoutView, :delivery},
      layout: {OliWeb.Layouts, :workspace},
      on_mount: [
        {OliWeb.AuthorAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.AssignActiveMenu,
        OliWeb.LiveSessionPlugs.SetSidebar,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.LiveSessionPlugs.SetProjectOrSection,
        OliWeb.LiveSessionPlugs.AuthorizeProject
      ] do
      scope "/course_author", CourseAuthor do
        live("/", IndexLive)
      end
    end

    live_session :protected_authoring_workspaces,
      root_layout: {OliWeb.LayoutView, :delivery},
      layout: {OliWeb.Layouts, :workspace},
      on_mount: [
        {OliWeb.AuthorAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.AssignActiveMenu,
        OliWeb.LiveSessionPlugs.SetSidebar,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.LiveSessionPlugs.SetProjectOrSection,
        OliWeb.LiveSessionPlugs.AuthorizeProject
      ] do
      scope "/course_author", CourseAuthor do
        live("/:project_id/overview", OverviewLive)
        live("/:project_id/alternatives", AlternativesLive)
        live("/:project_id/index_csv", IndexCsvLive)
        live("/:project_id/activity_bank", ActivityBankLive)
        live("/:project_id/objectives", ObjectivesLive)
        live("/:project_id/experiments", ExperimentsLive)
        live("/:project_id/bibliography", BibliographyLive)
        live("/:project_id/curriculum", CurriculumLive)
        live("/:project_id/curriculum/:container_slug", CurriculumLive)
        live("/:project_id/curriculum/:revision_slug/edit", Curriculum.EditorLive)
        live("/:project_id/curriculum/:revision_slug/history", HistoryLive)
        live("/:project_id/curriculum/:container_slug/:revision_slug", Curriculum.EditorLive)
        live("/:project_id/pages", PagesLive)
        live("/:project_id/activities", ActivitiesLive)
        live("/:project_id/activities/activity_review", Activities.ActivityReviewLive)
        live("/:project_id/review", ReviewLive)
        live("/:project_id/publish", PublishLive)
        live("/:project_id/insights", InsightsLive)

        live("/:project_id/datasets", DatasetsLive)
        live("/:project_id/datasets/create", CreateJobLive)
        live("/:project_id/datasets/details/:job_id", DatasetDetailsLive)

        scope "/:project_id/products" do
          live("/", ProductsLive)
          live("/:product_id", Products.DetailsLive)

          scope "/", alias: false do
            live(
              "/:product_id/certificate_settings",
              OliWeb.Certificates.CertificatesSettingsLive,
              metadata: %{route_name: :workspaces}
            )
          end
        end
      end
    end
  end

  scope "/workspaces", OliWeb.Workspaces do
    pipe_through([:browser, :delivery_protected])

    live_session :delivery_workspaces,
      root_layout: {OliWeb.LayoutView, :delivery},
      layout: {OliWeb.Layouts, :workspace},
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.AssignActiveMenu,
        OliWeb.LiveSessionPlugs.SetSidebar,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.LiveSessionPlugs.SetProjectOrSection,
        OliWeb.LiveSessionPlugs.AuthorizeProject
      ] do
      scope "/instructor", Instructor do
        live("/", IndexLive)
        live("/:section_slug/:view", DashboardLive)
        live("/:section_slug/:view/:active_tab", DashboardLive)
      end
    end
  end

  scope "/workspaces", OliWeb.Workspaces do
    pipe_through([
      :browser,
      :delivery_protected
    ])

    live_session :student_delivery_workspace,
      root_layout: {OliWeb.LayoutView, :delivery},
      layout: {OliWeb.Layouts, :workspace},
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.AssignActiveMenu,
        OliWeb.LiveSessionPlugs.SetSidebar,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.LiveSessionPlugs.SetProjectOrSection
      ] do
      scope "/student" do
        live("/", Student)
      end
    end
  end

  ###
  # Section Routes
  ###

  scope "/sections", OliWeb do
    pipe_through([:browser, :delivery, :delivery_layout])

    # Resolve root /sections route using the DeliveryController index action
    get("/", DeliveryController, :index)

    live("/join/invalid", Sections.InvalidSectionInviteView)
  end

  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery,
      :delivery_layout
    ])

    get("/join/:section_invite_slug", DeliveryController, :enroll_independent)
  end

  # Sections - Independent Learner Section Creation
  scope "/sections", OliWeb do
    pipe_through([:browser, :delivery_protected, :require_independent_instructor])

    live("/independent/create", Delivery.NewCourse, :independent_learner, as: :select_source)
    resources("/independent/", OpenAndFreeController, as: :independent_sections, except: [:index])
  end

  ### Sections - Payments
  scope "/sections/:section_slug", OliWeb do
    pipe_through([:browser, :require_section, :delivery_protected])

    get("/payment", PaymentController, :guard)
    get("/payment/new", PaymentController, :make_payment)
    get("/payment/code", PaymentController, :use_code)
    post("/payment/code", PaymentController, :apply_code)
  end

  ### Sections - Student Dashboard

  scope "/sections/:section_slug/student_dashboard/:student_id", OliWeb do
    pipe_through([:browser, :delivery_protected])

    live_session :student_dashboard,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
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
    pipe_through([:browser, :delivery, :delivery_protected])

    live_session :instructor_dashboard_preview,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.Delivery.InstructorDashboard.InitialAssigns
      ],
      layout: {OliWeb.Layouts, :instructor_dashboard} do
      live("/", Delivery.InstructorDashboard.InstructorDashboardLive, :preview)
      live("/:view", Delivery.InstructorDashboard.InstructorDashboardLive, :preview)
      live("/:view/:active_tab", Delivery.InstructorDashboard.InstructorDashboardLive, :preview)
    end
  end

  scope "/sections/:section_slug/instructor_dashboard", OliWeb do
    pipe_through([:browser, :delivery_protected])

    get(
      "/downloads/progress/:container_id/:title",
      DeliveryController,
      :download_container_progress
    )

    get("/downloads/course_content", DeliveryController, :download_course_content_info)
    get("/downloads/students_progress", DeliveryController, :download_students_progress)
    get("/downloads/learning_objectives", DeliveryController, :download_learning_objectives)
    get("/downloads/quiz_scores", DeliveryController, :download_quiz_scores)
    get("/", DeliveryController, :instructor_dashboard)
    post("/enrollments", InviteController, :create_bulk)

    live_session :instructor_dashboard,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetSection,
        OliWeb.LiveSessionPlugs.SetBrand,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.Delivery.InstructorDashboard.InitialAssigns
      ],
      layout: {OliWeb.Layouts, :instructor_dashboard} do
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
      :ensure_datashop_id,
      :require_authenticated_user_or_guest,
      :student,
      :enforce_paywall,
      :require_enrollment,
      :ensure_research_consent,
      :ensure_user_section_visit,
      :force_required_survey
    ])

    ### Student Course Delivery
    scope "/" do
      live_session :delivery,
        root_layout: {OliWeb.LayoutView, :delivery},
        layout: {OliWeb.Layouts, :student_delivery},
        on_mount: [
          {OliWeb.UserAuth, :ensure_authenticated},
          OliWeb.LiveSessionPlugs.SetCtx,
          OliWeb.LiveSessionPlugs.SetSection,
          OliWeb.LiveSessionPlugs.SetScheduledResourcesFlag,
          OliWeb.LiveSessionPlugs.SetRequireCertificationCheck,
          OliWeb.LiveSessionPlugs.SetBrand,
          OliWeb.LiveSessionPlugs.SetPreviewMode,
          OliWeb.LiveSessionPlugs.SetSidebar,
          OliWeb.LiveSessionPlugs.SetAnnotations,
          OliWeb.LiveSessionPlugs.RequireEnrollment,
          OliWeb.LiveSessionPlugs.SetNotificationBadges,
          OliWeb.LiveSessionPlugs.SetPaywallSummary
        ] do
        live("/", Delivery.Student.IndexLive)
        live("/learn", Delivery.Student.LearnLive)
        live("/discussions", Delivery.Student.DiscussionsLive)
        live("/assignments", Delivery.Student.AssignmentsLive)
        live("/student_schedule", Delivery.Student.ScheduleLive)
        live("/explorations", Delivery.Student.ExplorationsLive)
        live("/practice", Delivery.Student.PracticeLive)
        live("/certificate/:certificate_guid", Delivery.Student.CertificateLive)
      end
    end

    # TODO: Ensure that all these liveviews actually respect preview mode flag
    ### Instructor Preview Modes
    scope "/preview" do
      live_session :delivery_preview,
        root_layout: {OliWeb.LayoutView, :delivery},
        layout: {OliWeb.Layouts, :student_delivery},
        on_mount: [
          {OliWeb.UserAuth, :ensure_authenticated},
          OliWeb.LiveSessionPlugs.SetCtx,
          OliWeb.LiveSessionPlugs.SetSection,
          OliWeb.LiveSessionPlugs.SetScheduledResourcesFlag,
          OliWeb.LiveSessionPlugs.SetBrand,
          OliWeb.LiveSessionPlugs.SetPreviewMode,
          OliWeb.LiveSessionPlugs.SetSidebar,
          OliWeb.LiveSessionPlugs.SetAnnotations,
          OliWeb.LiveSessionPlugs.RequireEnrollment
        ] do
        live("/", Delivery.Student.IndexLive, :preview)
        live("/learn", Delivery.Student.LearnLive, :preview)
        live("/discussions", Delivery.Student.DiscussionsLive, :preview)
        live("/assignments", Delivery.Student.AssignmentsLive, :preview)
        live("/student_schedule", Delivery.Student.ScheduleLive, :preview)
        live("/explorations", Delivery.Student.ExplorationsLive, :preview)
        live("/practice", Delivery.Student.PracticeLive, :preview)
      end
    end

    get("/container/:revision_slug", PageDeliveryController, :container)

    scope "/" do
      pipe_through([:put_license])
      get("/page/:revision_slug", PageDeliveryController, :page)
      get("/page_fullscreen/:revision_slug", PageDeliveryController, :page_fullscreen)
      get("/page/:revision_slug/page/:page", PageDeliveryController, :page)
      get("/page/:revision_slug/attempt", PageDeliveryController, :start_attempt)

      get(
        "/page/:revision_slug/attempt/:attempt_guid/review",
        PageDeliveryController,
        :review_attempt
      )
    end

    post(
      "/page/:revision_slug/attempt_protected",
      PageDeliveryController,
      :start_attempt_protected
    )

    post("/page", PageDeliveryController, :navigate_by_index)
  end

  # page paths (prologue - lesson - adaptive_lesson)
  scope "/sections/:section_slug", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery,
      :redirect_by_attempt_state,
      :delivery_protected,
      :enforce_paywall,
      :require_enrollment,
      :ensure_user_section_visit,
      :force_required_survey
    ])

    scope "/prologue/:revision_slug" do
      live_session :delivery_prologue,
        root_layout: {OliWeb.LayoutView, :delivery},
        layout: {OliWeb.Layouts, :student_delivery_lesson},
        on_mount: [
          {OliWeb.UserAuth, :ensure_authenticated},
          OliWeb.LiveSessionPlugs.SetCtx,
          OliWeb.LiveSessionPlugs.SetSection,
          OliWeb.LiveSessionPlugs.SetScheduledResourcesFlag,
          {OliWeb.LiveSessionPlugs.InitPage, :set_prologue_context},
          OliWeb.LiveSessionPlugs.SetBrand,
          OliWeb.LiveSessionPlugs.SetPreviewMode,
          OliWeb.LiveSessionPlugs.RequireEnrollment,
          OliWeb.LiveSessionPlugs.SetRequestPath,
          OliWeb.LiveSessionPlugs.SetPaywallSummary
        ] do
        live("/", Delivery.Student.PrologueLive)
      end
    end

    scope "/lesson/:revision_slug" do
      live_session :delivery_lesson,
        root_layout: {OliWeb.LayoutView, :delivery},
        layout: {OliWeb.Layouts, :student_delivery_lesson},
        on_mount: [
          {OliWeb.UserAuth, :ensure_authenticated},
          OliWeb.LiveSessionPlugs.SetCtx,
          OliWeb.LiveSessionPlugs.SetSection,
          OliWeb.LiveSessionPlugs.SetRequireCertificationCheck,
          {OliWeb.LiveSessionPlugs.InitPage, :set_page_context},
          OliWeb.LiveSessionPlugs.SetBrand,
          OliWeb.LiveSessionPlugs.SetPreviewMode,
          OliWeb.LiveSessionPlugs.RequireEnrollment,
          OliWeb.LiveSessionPlugs.SetRequestPath,
          OliWeb.LiveSessionPlugs.SetPaywallSummary
        ] do
        live("/", Delivery.Student.LessonLive)
      end
    end

    scope "/lesson/:revision_slug/attempt/:attempt_guid/review" do
      live_session :delivery_lesson_review,
        root_layout: {OliWeb.LayoutView, :delivery},
        layout: {OliWeb.Layouts, :student_delivery_lesson},
        on_mount: [
          {OliWeb.UserAuth, :ensure_authenticated},
          OliWeb.LiveSessionPlugs.SetCtx,
          OliWeb.LiveSessionPlugs.SetSection,
          OliWeb.LiveSessionPlugs.SetScheduledResourcesFlag,
          OliWeb.LiveSessionPlugs.SetBrand,
          OliWeb.LiveSessionPlugs.SetPreviewMode,
          OliWeb.LiveSessionPlugs.RequireEnrollment,
          OliWeb.LiveSessionPlugs.SetPaywallSummary
        ] do
        live("/", Delivery.Student.ReviewLive)
      end
    end

    scope "/adaptive_lesson/:revision_slug" do
      pipe_through([:maybe_gated_resource])

      get("/", PageDeliveryController, :page_fullscreen)

      get(
        "/attempt/:attempt_guid/review",
        PageDeliveryController,
        :review_attempt
      )
    end
  end

  ### Sections - Preview
  scope "/sections/:section_slug/preview", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :authorize_section_preview,
      :delivery_protected,
      :delivery_layout
    ])

    get("/container/:revision_slug", PageDeliveryController, :container_preview)

    scope "/" do
      pipe_through([:put_license])
      get("/page/:revision_slug", PageDeliveryController, :page_preview)
      get("/page/:revision_slug/page/:page", PageDeliveryController, :page_preview)
      get("/page/:revision_slug/selection/:selection_id", ActivityBankController, :preview)
    end
  end

  scope "/sections/:section_slug", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_protected
    ])

    live_session :load_section,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetSection,
        OliWeb.LiveSessionPlugs.SetBrand,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.LiveSessionPlugs.RequireEnrollment
      ] do
      live(
        "/welcome",
        Delivery.StudentOnboarding.Wizard
      )
    end
  end

  ### Sections - Management
  scope "/sections/:section_slug", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_protected
    ])

    get("/grades/export", PageDeliveryController, :export_gradebook)
    post("/enrollments", InviteController, :create_bulk)
    post("/enrollments/export", PageDeliveryController, :export_enrollments)

    get(
      "/review/:attempt_guid",
      PageDeliveryController,
      :review_attempt,
      as: :instructor_review
    )

    live_session :schedule_gating,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetSection,
        OliWeb.LiveSessionPlugs.SetBrand,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.LiveSessionPlugs.SetUri,
        OliWeb.Delivery.InstructorDashboard.InitialAssigns
      ],
      layout: {OliWeb.Layouts, :instructor_dashboard_schedule} do
      live("/schedule", Sections.ScheduleView)
      live("/gating_and_scheduling", Sections.GatingAndScheduling)
      live("/gating_and_scheduling/new", Sections.GatingAndScheduling.New)
      live("/gating_and_scheduling/edit/:id", Sections.GatingAndScheduling.Edit)

      live(
        "/gating_and_scheduling/exceptions/:parent_gate_id",
        Sections.GatingAndScheduling
      )

      live(
        "/gating_and_scheduling/new/:parent_gate_id",
        Sections.GatingAndScheduling.New
      )

      live(
        "/assessment_settings/student_exceptions/:assessment_id",
        Sections.AssessmentSettings.StudentExceptionsLive
      )

      live(
        "/assessment_settings/settings/:assessment_id",
        Sections.AssessmentSettings.SettingsLive
      )
    end

    live_session :manage_section,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetSection,
        OliWeb.LiveSessionPlugs.SetBrand,
        OliWeb.LiveSessionPlugs.SetPreviewMode,
        OliWeb.Delivery.InstructorDashboard.InitialAssigns
      ],
      layout: {OliWeb.Layouts, :instructor_dashboard} do
      live("/certificate_settings", Certificates.CertificatesSettingsLive,
        metadata: %{route_name: :delivery, access: :read_only}
      )

      live("/manage", Sections.OverviewView)
      live("/grades/lms", Grades.GradesLive)
      live("/grades/lms_grade_updates", Grades.BrowseUpdatesView)
      live("/grades/failed", Grades.FailedGradeSyncLive)
      live("/grades/observe", Grades.ObserveGradeUpdatesView)
      live("/grades/gradebook", Grades.GradebookView)
      live("/scoring", ManualGrading.ManualGradingView)
      live("/progress/:user_id/:resource_id", Progress.StudentResourceView)
      live("/progress/:user_id", Progress.StudentView)
      live("/source_materials", Delivery.ManageSourceMaterials, as: :source_materials)
      live("/remix", Delivery.RemixSection)
      live("/remix/:section_resource_slug", Delivery.RemixSection)
      live("/invitations", Sections.InviteView)
      live("/lti_external_tools", Sections.LtiExternalToolsView)

      live("/edit", Sections.EditView)

      live("/debugger/:attempt_guid", Attempt.AttemptLive)

      live("/collaborative_spaces", CollaborationLive.IndexView, as: :collab_spaces_index)

      live(
        "/assistant/conversations",
        Sections.Assistant.StudentConversationsLive
      )
    end

    live_session :enrolled_students,
      on_mount: [
        {OliWeb.UserAuth, :ensure_authenticated},
        OliWeb.LiveSessionPlugs.SetCtx,
        OliWeb.LiveSessionPlugs.SetRouteName,
        OliWeb.Delivery.StudentDashboard.InitialAssigns
      ],
      root_layout: {OliWeb.LayoutView, :delivery_student_dashboard} do
      live(
        "/enrollments/students/:student_id/:active_tab",
        Delivery.StudentDashboard.StudentDashboardLive,
        as: :enrollment_student_info,
        metadata: %{route_name: :enrollments_student_info}
      )
    end
  end

  scope "/api/v1/state/course/:section_slug/activity_attempt", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery_protected
    ])

    get("/:activity_attempt_guid", Api.AttemptController, :get_activity_attempt)
  end

  scope "/api/v1/lti/projects/:project_slug", OliWeb, as: :api do
    pipe_through([:api, :authoring_protected])

    get(
      "/launch_details/:activity_id",
      Api.LtiController,
      :launch_details
    )
  end

  scope "/api/v1/lti/sections/:section_slug", OliWeb, as: :api do
    pipe_through([:api, :require_section, :delivery_protected])

    get(
      "/launch_details/:activity_id",
      Api.LtiController,
      :launch_details
    )

    get(
      "/deep_linking_launch_details/:activity_id",
      Api.LtiController,
      :deep_linking_launch_details
    )
  end

  ### Invitations (to sections or projects)

  scope "/", OliWeb do
    pipe_through([:browser])

    live "/users/invite/:token", Users.Invitations.UsersInviteView, as: :users_invite

    live "/collaborators/invite/:token", Collaborators.Invitations.InviteView,
      as: :collaborators_invite

    live "/authors/invite/:token", Authors.Invitations.InviteView, as: :authors_invite

    post "/users/accept_invitation", InviteController, :accept_user_invitation
    post "/collaborators/accept_invitation", InviteController, :accept_collaborator_invitation
    post "/authors/accept_invitation", InviteController, :accept_author_invitation
  end

  ### Sections - Enrollment
  scope "/sections", OliWeb do
    pipe_through([
      :browser,
      :require_section,
      :delivery,
      :delivery_layout
    ])

    get("/:section_slug/enroll", DeliveryController, :show_enroll)
    post("/:section_slug/enroll", DeliveryController, :process_enroll)
    get("/:section_slug/join", LaunchController, :join)
    post("/:section_slug/auto_enroll", LaunchController, :auto_enroll_as_guest)
  end

  scope "/course", OliWeb do
    pipe_through([:browser, :delivery_protected])

    live("/select_project", Delivery.NewCourse, :lms_instructor, as: :select_source)
  end

  ### Admin Dashboard / Telemetry

  scope "/admin", OliWeb do
    pipe_through([:browser, :authoring_protected, :require_authenticated_system_admin])

    live_dashboard("/dashboard",
      metrics: {OliWeb.Telemetry, :non_distributed_metrics},
      ecto_repos: [Oli.Repo],
      session: {__MODULE__, :with_session, []},
      additional_pages: [
        broadway: {BroadwayDashboard, pipelines: [Oli.Analytics.XAPI.UploadPipeline]}
      ]
    )
  end

  ### Admin Portal / Management
  scope "/admin", OliWeb do
    pipe_through([
      :browser,
      :require_authenticated_admin,
      :workspace
    ])

    # General
    live("/", Admin.AdminView)
    live("/vr_user_agents", Admin.VrUserAgentsView)
    live("/products", Products.ProductsView)
    live("/datasets", Workspaces.CourseAuthor.DatasetsLive)
    live("/agent_monitor", Admin.AgentMonitorView)

    live("/products/:product_id/discounts", Products.Payments.Discounts.ProductsIndexView)

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
    live("/sections/create", Delivery.NewCourse, :admin, as: :select_source)

    live("/open_and_free/:section_slug/remix", Delivery.RemixSection, as: :open_and_free_remix)

    # Publishers
    live("/publishers", PublisherLive.IndexView)
    live("/publishers/new", PublisherLive.NewView)
    live("/publishers/:publisher_id", PublisherLive.ShowView)

    # Course Ingestion
    get("/ingest/upload", IngestController, :index)
    post("/ingest/ingest", IngestController, :upload)

    get("/:project_slug/import/index", IngestController, :index_csv)
    post("/:project_slug/import/upload_csv", IngestController, :upload_csv)
    get("/:project_slug/import/download", IngestController, :download_current)
    live("/:project_slug/import/csv", Import.CSVImportView)

    live("/ingest/process", Admin.IngestV2)

    # Branding
    resources("/brands", BrandController)

    # Account admin
    scope "/" do
      pipe_through([:require_authenticated_account_admin])
      # Admin Author/User Account Management
      live("/users", Users.UsersView)
      live("/users/:user_id", Users.UsersDetailView)

      live("/authors", Users.AuthorsView)
      live("/authors/:author_id", Users.AuthorsDetailView)

      # Institutions, LTI Registrations and Deployments
      resources("/institutions", InstitutionController, except: [:index])
      put("/approve_registration", InstitutionController, :approve_registration)
      live("/institutions/", Admin.Institutions.IndexLive)

      live(
        "/institutions/:institution_id/discount",
        Products.Payments.Discounts.ShowView,
        :institution,
        as: :discount
      )

      live(
        "/institutions/:institution_id/research_consent",
        Admin.Institutions.ResearchConsentView,
        as: :institution
      )

      live(
        "/institutions/:institution_id/sections_and_students/:selected_tab",
        Admin.Institutions.SectionsAndStudentsView
      )

      get("/invite", InviteController, :index)
      post("/invite", InviteController, :create)

      # Communities
      live("/communities/new", CommunityLive.NewView)

      live("/registrations", Admin.RegistrationsView)

      resources("/registrations", RegistrationController, except: [:index]) do
        resources("/deployments", DeploymentController, except: [:index, :show])
      end

      # External tools
      live("/external_tools", Admin.ExternalTools.ExternalToolsView)
      live("/external_tools/new", Admin.ExternalTools.NewExternalToolView)
      live("/external_tools/:platform_instance_id/details", Admin.ExternalTools.DetailsView)
      live("/external_tools/:platform_instance_id/usage", Admin.ExternalTools.UsageView)
    end

    # System admin
    scope "/" do
      pipe_through([:require_authenticated_system_admin])
      get("/activity_review", ActivityReviewController, :index)
      live("/part_attempts", Admin.PartAttemptsView)

      live("/restore_progress", Admin.RestoreUserProgress)

      live("/xapi", Admin.UploadPipelineView)
      get("/spot_check/:activity_attempt_id", SpotCheckController, :index)

      # Authoring Activity Management
      get("/manage_activities", ActivityManageController, :index)
      put("/manage_activities/make_global/:activity_slug", ActivityManageController, :make_global)

      put(
        "/manage_activities/make_private/:activity_slug",
        ActivityManageController,
        :make_private
      )

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

      # System Message Banner
      live("/system_messages", SystemMessageLive.IndexView)

      live("/features", Features.FeaturesLive)
      live("/api_keys", ApiKeys.ApiKeysLive)
    end
  end

  scope "/project", OliWeb do
    pipe_through([
      :browser,
      :require_authenticated_content_admin,
      :workspace,
      :authorize_project
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
    forward "/dev/mailbox", Plug.Swoosh.MailboxPreview

    scope "/api/v1/testing", OliWeb do
      pipe_through([:api])

      post("/rules", Api.RulesEngineController, :execute)
    end

    scope "/dev", OliWeb do
      pipe_through([:browser])

      get("/flame_graphs", DevController, :flame_graphs)
      live("/icons", Dev.IconsLive)
      live("/tokens", Dev.TokensLive)
    end
  end
end
