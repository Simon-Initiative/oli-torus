defmodule OliWeb.Workspaces.CourseAuthor.PublishLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal
  use OliWeb.Common.SortableTable.TableHandlers

  import Oli.Utils, only: [trap_nil: 1, log_error: 2]

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.Publications.PublicationDiff
  alias Oli.Resources.ResourceType
  alias Oli.Search.Embeddings
  alias OliWeb.Common.{Confirm, Listing}

  alias OliWeb.Workspaces.CourseAuthor.Publish.{
    ActiveSectionsTableModel,
    LtiConnectInstructions,
    VersioningDetails
  }

  on_mount {OliWeb.LiveSessionPlugs.AuthorizeProject, :default}

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, _, _), do: socket.assigns.active_sections

  def live_path(socket, params),
    do: ~p"/workspaces/course_author/#{socket.assigns.project.slug}/publish?#{params}"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, ctx: ctx} = socket.assigns

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project.slug)

    push_affected = calculate_push_affected(latest_published_publication, project.id)
    active_publication = Publishing.project_working_publication(project.slug)

    {version_change, active_publication_changes, parent_pages} =
      calculate_publication_changes(
        latest_published_publication,
        active_publication,
        project.slug
      )

    lti_connect_info = generate_lti_connect_info()
    has_changes = has_version_changes?(version_change)
    active_sections = Sections.get_active_sections_by_project(project.id)
    publication_changes = prepare_publication_changes(active_publication_changes)

    {:ok, table_model} = ActiveSectionsTableModel.new(ctx, active_sections, project)

    {:ok,
     assign(socket,
       active_publication: active_publication,
       active_publication_changes: active_publication_changes,
       active_sections: active_sections,
       auto_update_sections: project.auto_update_sections,
       changeset: Publishing.change_publication(active_publication),
       ctx: ctx,
       has_changes: has_changes,
       latest_published_publication: latest_published_publication,
       limit: 10,
       lti_connect_info: lti_connect_info,
       parent_pages: parent_pages,
       project: project,
       publication_changes: publication_changes,
       push_affected: push_affected,
       resource_slug: project.slug,
       resource_title: project.title,
       table_model: table_model,
       version_change: version_change
     )}
  end

  attr(:limit, :integer, default: 10)
  attr(:modal, :any, default: nil)
  attr(:offset, :integer, default: 0)
  attr(:page_change, :string, default: "page_change")
  attr(:query, :string, default: "")
  attr(:show_bottom_paging, :boolean, default: false)
  attr(:sort, :string, default: "sort")
  attr(:description, :string, default: "")

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Publish</h2>
    <%= render_modal(assigns) %>
    <div class="publish">
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
              description={@description}
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
          "publication" => %{"auto_push_update" => auto_push_update, "description" => description}
        },
        socket
      ) do
    project = socket.assigns.project
    auto_update_sections = string_to_bool(auto_push_update)
    Course.update_project(project, %{auto_update_sections: auto_update_sections})

    {:noreply,
     assign(socket,
       auto_update_sections: auto_update_sections,
       description: description
     )}
  end

  def handle_event("update_sections", %{"publication" => publication}, socket) do
    %{project: project, current_author: author} = socket.assigns

    with {:ok, description} <- Map.get(publication, "description") |> trap_nil(),
         {active_publication_id, ""} <-
           Map.get(publication, "active_publication_id") |> Integer.parse(),
         {:ok} <- check_active_publication_id(project.slug, active_publication_id),
         previous_publication <-
           Publishing.get_latest_published_publication_by_slug(project.slug),
         {:ok, new_publication} <- Publishing.publish_project(project, description, author.id) do
      if Map.get(publication, "auto_push_update") == "true" do
        Publishing.push_publication_update_to_sections(
          project,
          previous_publication,
          new_publication
        )
      end

      if project.attributes && project.attributes.calculate_embeddings_on_publish,
        do: upsert_page_embeddings(socket.assigns.active_publication_changes, new_publication.id)

      {:noreply,
       socket
       |> put_flash(:info, "Publish Successful!")
       |> push_navigate(to: ~p"/workspaces/course_author/#{project.slug}/publish")}
    else
      e ->
        {_id, msg} = log_error("Publish failed", e)

        {:noreply,
         socket
         |> put_flash(:error, msg)
         |> push_navigate(to: ~p"/workspaces/course_author/#{project.slug}/publish")}
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

  def handle_event("publish_active", %{"publication" => publication}, socket) do
    modal_assigns = %{
      title: "Update Sections",
      id: "update_sections_modal",
      ok:
        JS.push("update_sections",
          value: %{"publication" => publication}
        ),
      cancel: JS.push("cancel_update_sections")
    }

    modal = fn assigns ->
      ~H"""
      <Confirm.render
        title={@modal_assigns.title}
        ok={@modal_assigns.ok}
        cancel={@modal_assigns.cancel}
        id={@modal_assigns.id}
      >
        Please confirm that you <b><%= if @auto_update_sections, do: "want", else: "don't want" %></b>
        to push this publication update to all sections
      </Confirm.render>
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("cancel_update_sections", _params, socket) do
    send(self(), {:hide_modal})

    {:noreply, socket}
  end

  defp check_active_publication_id(project_slug, active_publication_id) do
    active_publication = Publishing.project_working_publication(project_slug)

    if active_publication.id == active_publication_id,
      do: {:ok},
      else: {:error, "publication id does not match the active publication"}
  end

  defp string_to_bool("true"), do: true
  defp string_to_bool(_), do: false

  _docp = """
  Upsert page embeddings for the given changes and for the pages that not yet have embeddings calculated.
  """

  defp upsert_page_embeddings(changes, publication_id) do
    page_resource_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    changed_page_revision_ids =
      Enum.reduce(changes || [], [], fn {
                                          _resource_id,
                                          {_status,
                                           %{
                                             resource: _resource,
                                             revision: %{
                                               id: revision_id,
                                               resource_type_id: resource_type_id
                                             }
                                           }}
                                        },
                                        acc_revision_ids ->
        if resource_type_id == page_resource_type_id,
          do: [revision_id | acc_revision_ids],
          else: acc_revision_ids
      end)

    page_revision_ids_without_embeddings =
      Embeddings.revisions_to_embed(publication_id)

    (changed_page_revision_ids ++ page_revision_ids_without_embeddings)
    |> Enum.uniq()
    |> Embeddings.update_by_revision_ids(publication_id)
  end

  def calculate_publication_changes(
        latest_published_publication,
        active_publication,
        project_slug
      ) do
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
              changes
              |> Map.values()
              |> Enum.reduce([], fn {_, %{revision: revision}}, acc ->
                if revision.resource_type_id == ResourceType.id_for_activity(),
                  do: [revision.resource_id | acc],
                  else: acc
              end)
              |> Publishing.determine_parent_pages(
                Publishing.project_working_publication(project_slug).id
              )
          end

        {{classification, {edition, major, minor}}, changes, parent_pages}
    end
  end

  defp calculate_push_affected(latest_published_publication, project_id),
    do:
      if(is_nil(latest_published_publication),
        do: %{product_count: 0, section_count: 0},
        else:
          Sections.get_push_force_affected_sections(project_id, latest_published_publication.id)
      )

  defp generate_lti_connect_info do
    base_url = Oli.Utils.get_base_url()

    %{
      canvas_developer_key_url: "#{base_url}/lti/developer_key.json",
      blackboard_application_client_id:
        Application.get_env(:oli, :blackboard_application_client_id),
      tool_url: "#{base_url}/lti/launch",
      initiate_login_url: "#{base_url}/lti/login",
      public_keyset_url: "#{base_url}/.well-known/jwks.json",
      redirect_uris: "#{base_url}/lti/launch"
    }
  end

  defp has_version_changes?(version_change) do
    case version_change do
      {:no_changes, _} -> false
      _ -> true
    end
  end

  defp prepare_publication_changes(nil), do: []

  defp prepare_publication_changes(changes) do
    Enum.map(Map.values(changes), fn {type, data} ->
      Map.put(data.revision, :type, type)
      |> Map.put(:is_structural, Sections.is_structural?(data.revision))
    end)
  end
end
