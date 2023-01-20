defmodule OliWeb.Projects.PublishView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  import Oli.Utils, only: [trap_nil: 1, log_error: 2]

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.Publications.{Publication, PublicationDiff}
  alias OliWeb.Common.{Breadcrumb, Listing, SessionContext}

  alias OliWeb.Projects.{
    LtiConnectInstructions,
    PublicationDetails,
    TableModelActiveSections,
    VersioningDetails
  }

  alias OliWeb.Router.Helpers, as: Routes

  data is_force_push, :boolean, default: false
  data limit, :integer, default: 10
  data offset, :integer, default: 0
  data page_change, :string, default: "page_change"
  data query, :string, default: ""
  data show_bottom_paging, :boolean, default: false
  data sort, :string, default: "sort"

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, _, _), do: socket.assigns.active_sections

  def live_path(socket, params),
    do: Routes.live_path(socket, __MODULE__, socket.assigns.project.slug, params)

  def mount(
        %{"project_id" => project_slug} = _params,
        session,
        socket
      ) do
    context = SessionContext.init(session)
    project = Course.get_project_by_slug(project_slug)
    {:ok, now_time} = DateTime.now("Etc/UTC")
    active_sections = Sections.get_active_sections_by_project(project, now_time)

    %{product_count: product_count, section_count: section_count} =
      Sections.get_push_force_affected_sections(project)

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project_slug) || %Publication{}

    active_publication = Publishing.project_working_publication(project_slug)

    {version_change, active_publication_changes, parent_pages} =
      case latest_published_publication do
        nil ->
          {true, nil, %{}}

        _ ->
          %PublicationDiff{
            classification: classification,
            edition: edition,
            major: major,
            minor: minor,
            changes: changes
          } = Publishing.diff_publications(latest_published_publication, active_publication)

          parent_pages =
            case classification do
              {:no_changes, _} ->
                %{}

              _ ->
                Map.values(changes)
                |> Enum.map(fn {_, %{revision: revision}} -> revision end)
                |> Enum.filter(fn r ->
                  r.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("activity")
                end)
                |> Enum.map(fn r -> r.resource_id end)
                |> Oli.Publishing.determine_parent_pages(
                  Oli.Publishing.project_working_publication(project_slug).id
                )
            end

          {{classification, {edition, major, minor}}, changes, parent_pages}
      end

    base_url = Oli.Utils.get_base_url()
    canvas_developer_key_url = "#{base_url}/lti/developer_key.json"

    blackboard_application_client_id =
      Application.get_env(:oli, :blackboard_application_client_id)

    tool_url = "#{base_url}/lti/launch"
    initiate_login_url = "#{base_url}/lti/login"
    public_keyset_url = "#{base_url}/.well-known/jwks.json"
    redirect_uris = "#{base_url}/lti/launch"

    has_changes =
      case version_change do
        {:no_changes, _} -> false
        _ -> true
      end

    {:ok, table_model} = TableModelActiveSections.new(context, active_sections, project)

    {:ok,
     assign(socket,
       active_publication: active_publication,
       active_publication_changes: active_publication_changes,
       active_sections: active_sections,
       base_url: base_url,
       blackboard_application_client_id: blackboard_application_client_id,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Publish"})],
       canvas_developer_key_url: canvas_developer_key_url,
       changeset: Publishing.change_publication(active_publication),
       context: context,
       has_changes: has_changes,
       initiate_login_url: initiate_login_url,
       latest_published_publication: latest_published_publication,
       now_time: now_time,
       parent_pages: parent_pages,
       product_count: product_count,
       project: project,
       public_keyset_url: public_keyset_url,
       section_count: section_count,
       redirect_uris: redirect_uris,
       table_model: table_model,
       tool_url: tool_url,
       version_change: version_change
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="publish container">
        <div class="row">
          <div class="col-12">
            <PublicationDetails
              active_publication_changes={@active_publication_changes}
              context={@context}
              has_changes={@has_changes}
              latest_published_publication={@latest_published_publication}
              parent_pages={@parent_pages}
              project={@project}
            />

            {#if @has_changes}
              <VersioningDetails
                active_publication={@active_publication}
                active_publication_changes={@active_publication_changes}
                changeset={@changeset}
                force_push="force_push"
                has_changes={@has_changes}
                is_force_push={@is_force_push}
                latest_published_publication={@latest_published_publication}
                product_count={@product_count}
                project={@project}
                publish_active="publish_active"
                section_count={@section_count}
                version_change={@version_change}
              />
            {/if}

            <hr class="mt-3 mb-5">
            {#if length(@active_sections) > 0}
              <h5>This project has {length(@active_sections)} active course sections</h5>
              <div id="active-course-sections-table">
                <Listing
                  filter={@query}
                  limit={@limit}
                  offset={@offset}
                  page_change={@page_change}
                  show_bottom_paging={@show_bottom_paging}
                  sort={@sort}
                  table_model={@table_model}
                  total_count={length(@active_sections)}
                />
              </div>
            {#else}
              <h5>This project has no active course sections</h5>
            {/if}

            <hr class="mb-5 mt-3">
            <LtiConnectInstructions
              blackboard_application_client_id={@blackboard_application_client_id}
              canvas_developer_key_url={@canvas_developer_key_url}
              initiate_login_url={@initiate_login_url}
              public_keyset_url={@public_keyset_url}
              redirect_uris={@redirect_uris}
              tool_url={@tool_url}
            />
          </div>
        </div>
      </div>
    """
  end

  def handle_event("publish_active", %{"publication" => publication} = _params, socket) do
    project = socket.assigns.project

    with {:ok, description} <- Map.get(publication, "description") |> trap_nil(),
         {active_publication_id, ""} <-
           Map.get(publication, "active_publication_id") |> Integer.parse(),
         {:ok} <- check_active_publication_id(project.slug, active_publication_id),
         previous_publication <-
           Publishing.get_latest_published_publication_by_slug(project.slug),
         {:ok, new_publication} <- Publishing.publish_project(project, description) do
      if Map.get(publication, "auto_push_update") == "true" do
        Publishing.push_publication_update_to_sections(
          project,
          previous_publication,
          new_publication
        )
      end

      {:noreply,
       socket
       |> put_flash(:info, "Publish Successful!")
       |> push_redirect(
         to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.PublishView, project.slug)
       )}
    else
      e ->
        {_id, msg} = log_error("Publish failed", e)

        {:noreply,
         socket
         |> put_flash(:error, msg)
         |> push_redirect(
           to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.PublishView, project.slug)
         )}
    end
  end

  def handle_event("force_push", _, socket) do
    {:noreply, assign(socket, is_force_push: !socket.assigns.is_force_push)}
  end

  defp check_active_publication_id(project_slug, active_publication_id) do
    active_publication = Publishing.project_working_publication(project_slug)

    if active_publication.id == active_publication_id do
      {:ok}
    else
      {:error, "publication id does not match the active publication"}
    end
  end
end
