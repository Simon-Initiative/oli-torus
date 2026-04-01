defmodule OliWeb.DeliveryWeb do
  use OliWeb, :verified_routes

  import Phoenix.Controller

  alias Lti_1p3.Roles.{PlatformRoles, ContextRoles}
  alias Oli.Accounts.User
  alias Oli.Lti.LaunchContext
  alias Oli.Lti.LtiParams
  alias Oli.Delivery.Sections

  require Logger

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  def redirect_user_from_launch(conn, %LaunchContext{} = launch_context, opts \\ []) do
    section =
      Sections.get_section_from_lti_context(
        launch_context.issuer,
        launch_context.client_id,
        launch_context.context_id
      )

    redirect_lti_user(conn, launch_context.context_id, section, launch_context.roles, opts)
  end

  def redirect_user(conn, opts \\ []) do
    with %User{id: user_id, independent_learner: false} <- conn.assigns.current_user,
         %LtiParams{params: lti_params} <- LtiParams.get_latest_user_lti_params(user_id),
         {:ok, launch_context} <- LaunchContext.from_claims(lti_params) do
      redirect_user_from_launch(conn, launch_context, opts)
    else
      {:error, :missing_context} ->
        error_msg = "Context claim or context \"id\" field is missing from LTI params"
        Logger.error(error_msg)
        render(conn, "lti_error.html", reason: error_msg)

      _ ->
        redirect(conn, to: ~p"/workspaces/student")
    end
  end

  defp redirect_lti_user(conn, context_id, section, lti_roles, opts) do
    allow_new_section_creation = Keyword.get(opts, :allow_new_section_creation, false)
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    platform_roles = PlatformRoles.get_roles_by_uris(lti_roles)
    roles = MapSet.new(context_roles ++ platform_roles)
    allow_configure_section_roles = MapSet.new(@allow_configure_section_roles)

    can_configure_section =
      MapSet.intersection(roles, allow_configure_section_roles) |> MapSet.size() > 0

    can_create_section = allow_new_section_creation and can_configure_section

    case section do
      nil when can_create_section ->
        redirect(conn, to: ~p"/sections/new/#{context_id}")

      nil ->
        conn
        |> put_view(OliWeb.DeliveryView)
        |> render("course_not_configured.html")

      section when can_configure_section ->
        redirect(conn, to: ~p"/sections/#{section.slug}/manage")

      section ->
        redirect(conn, to: ~p"/sections/#{section.slug}")
    end
  end
end
