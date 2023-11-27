defmodule OliWeb.Projects.PublishView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal
  use OliWeb.Common.SortableTable.TableHandlers

  import Oli.Utils, only: [trap_nil: 1, log_error: 2]

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.Publications.PublicationDiff
  alias OliWeb.Common.{Breadcrumb, Listing, SessionContext}

  alias OliWeb.Projects.{
    ActiveSectionsTableModel,
    LtiConnectInstructions,
    VersioningDetails
  }

  alias OliWeb.Router.Helpers, as: Routes

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, _, _), do: socket.assigns.active_sections

  def live_path(socket, params),
    do: Routes.live_path(socket, __MODULE__, socket.assigns.project.slug, params)

  def mount(
        %{"project_id" => project_slug},
        session,
        socket
      ) do
    ctx = SessionContext.init(socket, session)
    project = Course.get_project_by_slug(project_slug)
    active_sections = Sections.get_active_sections_by_project(project.id)

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project_slug)

    push_affected =
      if is_nil(latest_published_publication),
        do: %{product_count: 0, section_count: 0},
        else:
          Sections.get_push_force_affected_sections(project.id, latest_published_publication.id)

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

    lti_connect_info = %{
      canvas_developer_key_url: "#{base_url}/lti/developer_key.json",
      blackboard_application_client_id:
        Application.get_env(:oli, :blackboard_application_client_id),
      tool_url: "#{base_url}/lti/launch",
      initiate_login_url: "#{base_url}/lti/login",
      public_keyset_url: "#{base_url}/.well-known/jwks.json",
      redirect_uris: "#{base_url}/lti/launch"
    }

    has_changes =
      case version_change do
        {:no_changes, _} -> false
        _ -> true
      end

    {:ok, table_model} = ActiveSectionsTableModel.new(ctx, active_sections, project)

    publication_changes =
      case active_publication_changes do
        nil ->
          []

        changes ->
          Enum.map(Map.values(changes), fn {type, data} ->
            Map.put(data.revision, :type, type)
            |> Map.put(:is_structural, Sections.is_structural?(data.revision))
          end)
      end

    {:ok,
     assign(socket,
       active_publication: active_publication,
       active_publication_changes: active_publication_changes,
       active_sections: active_sections,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Publish"})],
       changeset: Publishing.change_publication(active_publication),
       ctx: ctx,
       has_changes: has_changes,
       latest_published_publication: latest_published_publication,
       lti_connect_info: lti_connect_info,
       parent_pages: parent_pages,
       project: project,
       publication_changes: publication_changes,
       push_affected: push_affected,
       table_model: table_model,
       version_change: version_change,
       limit: 10
     )}
  end

  attr(:auto_update_sections, :boolean, default: false)
  attr(:limit, :integer, default: 10)
  attr(:modal, :any, default: nil)
  attr(:offset, :integer, default: 0)
  attr(:page_change, :string, default: "page_change")
  attr(:query, :string, default: "")
  attr(:show_bottom_paging, :boolean, default: false)
  attr(:sort, :string, default: "sort")

  def render(assigns) do
    ~H"""
    <%= render_modal(assigns) %>
    <div class="publish container">
      <div class="flex flex-row">
        <div class="flex-1">
          <.live_component
            id="publication_details"
            module={OliWeb.Projects.PublicationDetails}
            active_publication_changes={@active_publication_changes}
            ctx={@ctx}
            has_changes={@has_changes}
            latest_published_publication={@latest_published_publication}
            parent_pages={@parent_pages}
            project={@project}
            publication_changes={@publication_changes}
          />

          <%= if @has_changes do %>
            <VersioningDetails.render
              active_publication={@active_publication}
              active_publication_changes={@active_publication_changes}
              auto_update_sections={@auto_update_sections}
              form_changed="form_changed"
              changeset={@changeset |> to_form()}
              has_changes={@has_changes}
              latest_published_publication={@latest_published_publication}
              project={@project}
              publish_active="publish_active"
              push_affected={@push_affected}
              version_change={@version_change}
            />
          <% end %>

          <hr class="mt-3 mb-5" />
          <%= if length(@active_sections) > 0 do %>
            <h5>This project has <%= length(@active_sections) %> active course sections</h5>
            <div id="active-course-sections-table">
              <Listing.render
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
          <% else %>
            <h5>This project has no active course sections</h5>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event(
        "form_changed",
        %{
          "publication" => %{"auto_push_update" => auto_push_update}
        },
        socket
      ) do
    {:noreply,
     assign(socket,
       auto_update_sections: string_to_bool(auto_push_update)
     )}
  end

  def handle_event("publish_active", %{"publication" => publication}, socket) do
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

  def handle_event("display_lti_connect_modal", %{}, socket) do
    modal_assigns = %{
      id: "lti_connect_modal",
      lti_connect_info: socket.assigns.lti_connect_info
    }

    modal = fn assigns ->
      ~H"""
      <LtiConnectInstructions.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  defp check_active_publication_id(project_slug, active_publication_id) do
    active_publication = Publishing.project_working_publication(project_slug)

    if active_publication.id == active_publication_id do
      {:ok}
    else
      {:error, "publication id does not match the active publication"}
    end
  end

  defp string_to_bool("true"), do: true
  defp string_to_bool(_), do: false
end
