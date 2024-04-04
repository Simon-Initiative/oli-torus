defmodule OliWeb.AnalyticsRouter do
  use OliWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword, PowEmailConfirmation]

  import Phoenix.LiveDashboard.Router
  import PhoenixStorybook.Router

  import Oli.Plugs.EnsureAdmin

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

  pipeline :storybook_layout do
    plug(:put_root_layout, {OliWeb.LayoutView, :storybook})
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

    plug(OliWeb.Plugs.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )

    plug(OliWeb.EnsureUserNotLockedPlug)

    plug(Oli.Plugs.RemoveXFrameOptions)

    plug(:delivery_layout)
  end

  pipeline :authoring_protected do
    plug(:authoring)

    plug(PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
    )

    plug(OliWeb.Plugs.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )

    plug(OliWeb.EnsureUserNotLockedPlug)
  end

  # Ensure that the user logged in is an admin user
  pipeline :admin do
    plug(Oli.Plugs.RequireAdmin)
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
    pipe_through([:browser, :delivery, :registration_captcha, :pow_email_layout])

    pow_routes()
    pow_assent_routes()
    pow_extension_routes()
  end

  scope "/", OliWeb do
    pipe_through([:browser, :delivery_protected])

    # keep a session active by periodically calling this endpoint
    get("/keep-alive", StaticPageController, :keep_alive)
  end

  scope "/" do
    pipe_through([:skip_csrf_protection, :delivery])

    pow_assent_authorization_post_callback_routes()
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

end
