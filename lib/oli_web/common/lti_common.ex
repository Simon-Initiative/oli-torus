defmodule OliWeb.Common.LtiCommon do
  use OliWeb, :verified_routes

  import Phoenix.Controller

  alias Lti_1p3.Roles.{PlatformRoles, ContextRoles}

  require Logger

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  @roles_claims "https://purl.imsglobal.org/spec/lti/claim/roles"

  def redirect_lti_user(conn, section, lti_params) do
    # Context claim is considered optional according to IMS http://www.imsglobal.org/spec/lti/v1p3/#context-claim
    # so we must safeguard against the case that context is missing
    case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
      %{"id" => context_id} ->
        lti_roles = lti_params[@roles_claims]
        context_roles = ContextRoles.get_roles_by_uris(lti_roles)
        platform_roles = PlatformRoles.get_roles_by_uris(lti_roles)
        roles = MapSet.new(context_roles ++ platform_roles)
        allow_configure_section_roles = MapSet.new(@allow_configure_section_roles)

        # allow section configuration if user has any of the allowed roles
        allow_configure_section =
          MapSet.intersection(roles, allow_configure_section_roles) |> MapSet.size() > 0

        case section do
          # Section has not been configured, redirect to LTI new course creation wizard
          nil when allow_configure_section ->
            conn
            |> redirect(to: ~p"/sections/new/#{context_id}")

          # Section has not been configured, but student is not allowed to configure
          nil ->
            render(conn, "course_not_configured.html")

          # Section has already been configured, redirect to manage view
          section when allow_configure_section ->
            conn
            |> redirect(to: ~p"/sections/#{section.slug}/manage")

          # Section has been configured, redirect student to section home
          section ->
            conn
            |> redirect(to: ~p"/sections/#{section.slug}")
        end

      _ ->
        error_msg = "Context claim or context \"id\" field is missing from LTI params"

        Logger.error(error_msg)

        render(conn, "lti_error.html", reason: error_msg)
    end
  end
end
