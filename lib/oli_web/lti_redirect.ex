defmodule OliWeb.LtiRedirect do
  use OliWeb, :verified_routes

  import Phoenix.Controller

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Lti.LtiParams

  require Logger
  @telemetry_prefix [:oli, :lti]

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

  @doc "Resolves the current LTI launch to a section destination or a page in that section."
  def launch_destination(lti_params, opts \\ []) do
    allow_new_section_creation = Keyword.get(opts, :allow_new_section_creation, false)
    source = Keyword.get(opts, :source, :current_launch)
    transport_method = Keyword.get(opts, :transport_method)

    case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
      %{"id" => context_id} ->
        roles =
          LtiParams.launch_roles(lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"])

        can_configure_section = LtiParams.can_configure_section?(roles)
        can_create_section = allow_new_section_creation and can_configure_section

        target =
          Keyword.get_lazy(opts, :target, fn ->
            resolve_target(lti_params, Sections.get_section_from_lti_params(lti_params))
          end)

        section = target.section

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

          section ->
            section_destination(
              section,
              can_configure_section,
              context_id,
              source,
              transport_method,
              target
            )
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

  defp section_destination(
         section,
         can_configure_section,
         context_id,
         source,
         transport_method,
         target
       ) do
    case direct_page_path(target) do
      {:ok, path} ->
        observe_redirect_resolution(%{
          context_id: context_id,
          outcome: :direct_page,
          section_id: section.id,
          source: source,
          transport_method: transport_method
        })

        {:redirect, path}

      :fallback when can_configure_section ->
        observe_redirect_resolution(%{
          context_id: context_id,
          outcome: :section_manage,
          section_id: section.id,
          source: source,
          transport_method: transport_method
        })

        {:redirect, ~p"/sections/#{section.slug}/manage"}

      :fallback ->
        observe_redirect_resolution(%{
          context_id: context_id,
          outcome: :section_home,
          section_id: section.id,
          source: source,
          transport_method: transport_method
        })

        {:redirect, ~p"/sections/#{section.slug}"}
    end
  end

  @doc "Resolves the current launch's direct page once, from authoritative section resources."
  @spec resolve_target(map(), %Sections.Section{} | nil) :: map()
  def resolve_target(claims, section) do
    resource = resolve_resource(claims, section)
    %{section: section, resource: resource}
  end

  defp resolve_resource(
         %{
           "https://purl.imsglobal.org/spec/lti/claim/custom" => %{
             "torus_resource_type" => "page",
             "torus_resource_id" => revision_slug
           }
         },
         %Sections.Section{} = section
       )
       when is_binary(revision_slug) and revision_slug != "" do
    case section.section_resource_migration_version == SectionResourceMigration.current_version() do
      true -> :ok
      false -> {:ok, _} = SectionResourceMigration.ensure_current(section.id)
    end

    SectionResourceDepot.get_page_by_revision_slug(section.id, revision_slug)
  end

  defp resolve_resource(_, _), do: nil

  defp direct_page_path(%{section: section, resource: %{revision_slug: slug}}),
    do: {:ok, ~p"/sections/#{section.slug}/page/#{slug}"}

  defp direct_page_path(_), do: :fallback

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
