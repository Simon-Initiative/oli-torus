defmodule OliWeb.LtiRedirect do
  use OliWeb, :verified_routes

  import Phoenix.Controller

  alias Lti_1p3.Roles.{ContextRoles, PlatformRoles}
  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Lti.LtiParams

  require Logger
  @telemetry_prefix [:oli, :lti]

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]
  @allow_configure_section_roles_set MapSet.new(@allow_configure_section_roles)

  def redirect_authenticated_user(conn, opts \\ []) do
    allow_new_section_creation = Keyword.get(opts, :allow_new_section_creation, false)

    with %Accounts.User{id: user_id, independent_learner: false} <- conn.assigns.current_user,
         %LtiParams{params: lti_params} <- LtiParams.get_latest_user_lti_params(user_id) do
      redirect_from_lti_params(conn, lti_params,
        allow_new_section_creation: allow_new_section_creation,
        source: :latest_user_lti_params
      )
    else
      _ ->
        redirect(conn, to: ~p"/workspaces/student")
    end
  end

  def redirect_from_lti_params(conn, lti_params, opts \\ []) do
    with %Accounts.User{independent_learner: false} <- conn.assigns.current_user,
         destination <- launch_destination(lti_params, opts) do
      apply_destination(conn, destination, opts)
    else
      _ ->
        redirect(conn, to: ~p"/workspaces/student")
    end
  end

  def launch_destination(lti_params, opts \\ []) do
    allow_new_section_creation = Keyword.get(opts, :allow_new_section_creation, false)
    source = Keyword.get(opts, :source, :current_launch)
    transport_method = Keyword.get(opts, :transport_method)

    case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
      %{"id" => context_id} ->
        roles = launch_roles(lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"])
        can_configure_section = can_configure_section?(roles)
        can_create_section = allow_new_section_creation and can_configure_section

        section = Sections.get_section_from_lti_params(lti_params)

        case section do
          nil when can_create_section ->
            metadata = %{
              context_id: context_id,
              outcome: :section_new,
              source: source,
              transport_method: transport_method
            }

            observe_redirect_resolution(metadata)
            {:redirect, ~p"/sections/new/#{context_id}"}

          nil ->
            metadata = %{
              context_id: context_id,
              outcome: :course_not_configured,
              source: source,
              transport_method: transport_method
            }

            observe_redirect_resolution(metadata)
            :course_not_configured

          section when can_configure_section ->
            metadata = %{
              context_id: context_id,
              outcome: :section_manage,
              section_id: section.id,
              source: source,
              transport_method: transport_method
            }

            observe_redirect_resolution(metadata)
            {:redirect, ~p"/sections/#{section.slug}/manage"}

          section ->
            metadata = %{
              context_id: context_id,
              outcome: :section_home,
              section_id: section.id,
              source: source,
              transport_method: transport_method
            }

            observe_redirect_resolution(metadata)
            {:redirect, ~p"/sections/#{section.slug}"}
        end

      _ ->
        error_msg = "Context claim or context \"id\" field is missing from current LTI launch"

        observe_redirect_resolution(%{
          outcome: :launch_error,
          reason: :missing_context_id,
          source: source,
          transport_method: transport_method
        })

        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  defp launch_roles(roles) when is_list(roles) do
    context_roles = ContextRoles.get_roles_by_uris(roles)
    platform_roles = PlatformRoles.get_roles_by_uris(roles)
    MapSet.new(context_roles ++ platform_roles)
  end

  defp launch_roles(_roles), do: MapSet.new()

  defp can_configure_section?(roles) do
    MapSet.intersection(roles, @allow_configure_section_roles_set) |> MapSet.size() > 0
  end

  defp apply_destination(conn, {:redirect, path}, _opts), do: redirect(conn, to: path)

  defp apply_destination(conn, :course_not_configured, _opts) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> render("course_not_configured.html")
  end

  defp apply_destination(conn, {:error, error_msg}, opts) do
    conn
    |> Plug.Conn.put_status(Keyword.get(opts, :error_status, :bad_request))
    |> render("lti_error.html", reason: error_msg)
  end

  defp observe_redirect_resolution(metadata) do
    Logger.info("LTI redirect resolution #{format_metadata(metadata)}")
    :telemetry.execute(@telemetry_prefix ++ [:redirect_resolution], %{count: 1}, metadata)
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map_join(" ", fn {key, value} -> "#{key}=#{inspect(value)}" end)
  end
end
