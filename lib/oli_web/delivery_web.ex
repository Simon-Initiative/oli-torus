defmodule OliWeb.DeliveryWeb do
  use OliWeb, :verified_routes

  import Phoenix.Controller

  alias Lti_1p3.Roles.{PlatformRoles, ContextRoles}
  alias Oli.Accounts.User
  alias Oli.Lti.LtiParams
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType

  require Logger

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  @roles_claims "https://purl.imsglobal.org/spec/lti/claim/roles"

  def redirect_user(conn, opts \\ []) do
    allow_new_section_creation = Keyword.get(opts, :allow_new_section_creation, false)
    revision_slug = Keyword.get(opts, :revision_slug)

    with %User{id: user_id, independent_learner: false} <- conn.assigns.current_user,
         %LtiParams{params: lti_params} <- LtiParams.get_latest_user_lti_params(user_id) do
      section = Sections.get_section_from_lti_params(lti_params)

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
          can_configure_section =
            MapSet.intersection(roles, allow_configure_section_roles) |> MapSet.size() > 0

          can_create_section = allow_new_section_creation and can_configure_section

          case section do
            # Section has not been configured yet, redirect to LTI new course creation wizard
            nil when can_create_section ->
              conn
              |> redirect(to: ~p"/sections/new/#{context_id}")

            # Section has not been configured, but student is not allowed to configure
            nil ->
              conn
              |> put_view(OliWeb.DeliveryView)
              |> render("course_not_configured.html")

            # Section has already been configured
            section ->
              # If a revision_slug is provided, attempt to redirect to that specific page
              if revision_slug do
                case get_and_validate_revision(section.slug, revision_slug) do
                  {:ok, revision} ->
                    # Redirect directly to the specific page
                    conn
                    |> redirect(to: ~p"/sections/#{section.slug}/page/#{revision.slug}")

                  {:error, _reason} ->
                    # Fallback to normal redirect logic if page not found or not valid
                    redirect_to_default(conn, section, can_configure_section)
                end
              else
                # No revision_slug provided, use normal redirect logic
                redirect_to_default(conn, section, can_configure_section)
              end
          end

        _ ->
          error_msg = "Context claim or context \"id\" field is missing from LTI params"

          Logger.error(error_msg)

          render(conn, "lti_error.html", reason: error_msg)
      end
    else
      _ ->
        redirect(conn, to: ~p"/workspaces/student")
    end
  end

  defp redirect_to_default(conn, section, can_configure_section) do
    if can_configure_section do
      conn
      |> redirect(to: ~p"/sections/#{section.slug}/manage")
    else
      conn
      |> redirect(to: ~p"/sections/#{section.slug}")
    end
  end

  defp get_and_validate_revision(section_slug, revision_slug) do
    case DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
      nil ->
        {:error, :not_found}

      revision ->
        # Verify it's a page and not deleted
        page_type_id = ResourceType.get_id_by_type("page")

        if revision.resource_type_id == page_type_id and not revision.deleted do
          {:ok, revision}
        else
          {:error, :not_found}
        end
    end
  end
end
