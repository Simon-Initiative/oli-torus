defmodule OliWeb.Workspaces.CourseAuthor.HistoryLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal
  use Phoenix.HTML

  import Ecto.Query, warn: false

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Utils.SchemaResolver
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.History.RestoreRevisionModal

  alias OliWeb.RevisionHistory.{
    Details,
    Graph,
    Pagination,
    Table
  }

  @page_size 15

  @impl Phoenix.LiveView
  def mount(%{"project_id" => project_slug, "revision_slug" => revision_slug}, _session, socket) do
    with {:is_admin?, true} <-
           {:is_admin?, Accounts.has_admin_role?(socket.assigns.current_author)},
         {:revision, revision} when not is_nil(revision) <-
           {:revision, AuthoringResolver.from_revision_slug(project_slug, revision_slug)} do
      do_mount(revision, socket.assigns.project, socket)
    else
      {:is_admin?, _} ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have access to that project history")
         |> push_navigate(to: ~p"/workspaces/course_author")}

      {:revision, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Revision not found")
         |> push_navigate(to: ~p"/workspaces/course_author")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show_restore_revision_modal", _, socket) do
    modal_assigns = %{
      id: "restore_revision"
    }

    modal = fn assigns ->
      ~H"""
      <RestoreRevisionModal.render id={@modal_assigns.id} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :json, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    %{resource_schema: resource_schema} = socket.assigns

    with uploaded_content <-
           consume_uploaded_entries(socket, :json, fn %{path: path}, _entry ->
             {:ok,
              File.read!(path)
              |> Jason.decode!()}
           end),
         :ok <- ExJsonSchema.Validator.validate(resource_schema, uploaded_content) do
      latest_revision = fetch_revision(hd(socket.assigns.revisions).id)

      {:noreply,
       socket
       |> mimic_edit(latest_revision, hd(uploaded_content))
       |> assign(upload_errors: [])}
    else
      {:error, errors} ->
        {:noreply, assign(socket, upload_errors: flatten_validation_errors(errors))}
    end
  end

  # creates a new revision by restoring the state of the selected revision
  @impl Phoenix.LiveView
  def handle_event("restore", _, socket) do
    %{selected: selected} = socket.assigns

    {:noreply,
     socket
     |> hide_modal(modal_assigns: nil)
     |> mimic_edit(selected, selected.content)}
  end

  @impl Phoenix.LiveView
  def handle_event("select", %{"rev" => str}, socket) do
    id = String.to_integer(str)
    selected = fetch_revision(id)

    content_json =
      selected.content
      |> Jason.encode!()
      |> Jason.Formatter.pretty_print()

    {:noreply,
     socket
     |> assign(:selected, selected)
     |> reset_editor(content_json)}
  end

  @impl Phoenix.LiveView
  def handle_event("table", _, socket) do
    {:noreply, assign(socket, :view, "table")}
  end

  @impl Phoenix.LiveView
  def handle_event("graph", _, socket) do
    {:noreply, assign(socket, view: "graph")}
  end

  @impl Phoenix.LiveView
  def handle_event("page", %{"ordinal" => ordinal}, socket) do
    page_offset = (String.to_integer(ordinal) - 1) * @page_size
    {:noreply, assign(socket, :page_offset, page_offset)}
  end

  @impl Phoenix.LiveView
  def handle_event("edit_json", _, socket) do
    %{selected: selected} = socket.assigns

    {:noreply,
     socket
     |> push_event("monaco_editor_set_options", %{"readOnly" => false})
     |> assign(:edited_json, selected.content)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_edits", _, socket) do
    %{selected: selected} = socket.assigns

    content_json =
      selected.content
      |> Jason.encode!()
      |> Jason.Formatter.pretty_print()

    {:noreply,
     socket
     |> reset_editor(content_json)}
  end

  @impl Phoenix.LiveView
  def handle_event("save_edits", _, socket) do
    {:noreply, socket |> push_event("monaco_editor_get_value", %{action: "save"})}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "monaco_editor_get_value",
        %{"value" => value, "meta" => %{"action" => "save"}},
        socket
      ) do
    %{revisions: revisions} = socket.assigns

    with {:ok, edited} <- Jason.decode(value),
         latest_revision <- fetch_revision(hd(revisions).id) do
      {:noreply,
       socket
       |> reset_editor(value)
       |> mimic_edit(latest_revision, edited)}
    else
      {:error, %Jason.DecodeError{}} ->
        {:noreply, assign(socket, edit_errors: ["Invalid JSON"])}

      {:error, errors} ->
        {:noreply, assign(socket, edit_errors: flatten_validation_errors(errors))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("reset_monaco", _params, socket) do
    {:noreply, assign(socket, details_modal_assigns: nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("edit_attribute", %{"attr-key" => attr_key}, socket) do
    socket =
      assign(socket,
        details_modal_assigns: %{
          title: attr_key,
          key: String.to_existing_atom(attr_key)
        }
      )

    # we want to ensure monaco editor is reseted correctly
    # before assigning new values and showing the modal
    :timer.sleep(200)

    {:noreply,
     push_event(socket, "js-exec", %{
       to: "#edit_attribute_modal_trigger",
       attr: "data-show_edit_attribute_modal"
     })}
  end

  @impl Phoenix.LiveView
  def handle_event("save_edit_attribute", _, socket) do
    {:noreply, socket |> push_event("monaco_editor_get_attribute_value", %{action: "save"})}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "monaco_editor_get_attribute_value",
        %{"value" => value, "meta" => %{"action" => "save"}},
        socket
      ) do
    revision_being_edited = socket.assigns.selected
    key_being_edited = socket.assigns.details_modal_assigns.key

    with {:ok, decoded_value} <- Jason.decode(value),
         {:ok, revision} <-
           Oli.Resources.update_revision(
             revision_being_edited,
             Map.put(%{}, key_being_edited, decoded_value)
           ) do
      {:noreply,
       socket
       |> assign(selected: revision)
       |> put_flash(:info, "Revision '#{key_being_edited}' updated")}
    else
      {:error, %Jason.DecodeError{}} ->
        {:noreply, put_flash(socket, :error, "Could not update revision: Invalid JSON format")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not update revision: #{inspect(changeset.errors)}")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:updated, revision, _}, socket) do
    id = revision.id

    revision = Oli.Resources.get_revision!(id) |> Repo.preload(:author)

    revisions =
      case socket.assigns.revisions do
        [] -> [revision]
        [%{id: ^id} | rest] -> [revision] ++ rest
        list -> [revision] ++ list
      end

    selected =
      if revision.id == socket.assigns.selected.id do
        revision
      else
        socket.assigns.selected
      end

    tree =
      case Map.get(socket.assigns.tree, revision.id) do
        nil -> Oli.Versioning.RevisionTree.Tree.build(revisions, socket.assigns.resource_id)
        node -> Map.put(socket.assigns.tree, revision.id, %{node | revision: revision})
      end

    {:noreply, assign(socket, selected: selected, revisions: revisions, tree: tree)}
  end

  @impl Phoenix.LiveView
  def handle_info({:new_publication, _, _}, socket) do
    mappings =
      Publishing.get_all_mappings_for_resource(
        socket.assigns.resource_id,
        socket.assigns.project.slug
      )

    mappings_by_revision =
      Enum.reduce(mappings, %{}, fn mapping, m -> Map.put(m, mapping.revision_id, mapping) end)

    {:noreply,
     assign(socket,
       mappings: mappings_by_revision,
       publication: determine_most_recent_published(mappings)
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div
      :if={@flash not in [nil, %{}]}
      id="live_flash_container"
      class="flash container mx-auto px-0 top-[80px]"
    >
      <%= if Phoenix.Flash.get(@flash, :info) do %>
        <div class="alert alert-info flex flex-row" role="alert">
          <div class="flex-1">
            <%= Phoenix.Flash.get(@flash, :info) %>
          </div>

          <button
            type="button"
            class="close"
            data-bs-dismiss="alert"
            aria-label="Close"
            phx-click="lv:clear-flash"
            phx-value-key="info"
          >
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      <% end %>

      <%= if Phoenix.Flash.get(@flash, :error) do %>
        <div class="alert alert-danger flex flex-row" role="alert">
          <div class="flex-1">
            <%= Phoenix.Flash.get(@flash, :error) %>
          </div>

          <button
            type="button"
            class="close"
            data-bs-dismiss="alert"
            aria-label="Close"
            phx-click="lv:clear-flash"
            phx-value-key="error"
          >
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      <% end %>
    </div>

    <script
      id="keep-alive"
      type="text/javascript"
      src={Routes.static_path(OliWeb.Endpoint, "/js/keepalive.js")}
    >
    </script>

    <div class="container flex flex-col gap-y-6 p-8">
      <%= render_modal(assigns) %>

      <div class="container">
        <h2>Revision History</h2>
        <h4>Resource ID: <%= @resource_id %></h4>
        <.link
          :if={@selected.slug != @revision_root_slug}
          id="root_hierarchy_link"
          class="torus-button primary"
          navigate={
            ~p[/workspaces/course_author/#{@project.slug}/curriculum/#{@revision_root_slug}/history]
          }
        >
          Hierarchy
        </.link>

        <div class="row" style="margin-bottom: 30px;">
          <div class="col-12">
            <div class="card">
              <div class="card-header">
                Revisions
              </div>
              <div class="card-body">
                <div class="border rounded mb-2">
                  <.live_component
                    id="graph"
                    module={Graph}
                    tree={@tree}
                    root={@root}
                    selected={@selected}
                    project={@project}
                    initial_size={@initial_size}
                  />
                </div>
                <Pagination.render
                  revisions={@revisions}
                  page_offset={@page_offset}
                  page_size={@page_size}
                />
                <Table.render
                  id="attributes_table"
                  tree={@tree}
                  publication={@publication}
                  mappings={@mappings}
                  revisions={@revisions}
                  selected={@selected}
                  page_offset={@page_offset}
                  page_size={@page_size}
                  ctx={@ctx}
                />
              </div>
            </div>
          </div>
        </div>
        <div class="row" style="margin-bottom: 30px;">
          <div class="col-12">
            <div class="card">
              <div class="card-header flex flex-row justify-between mb-2">
                Selected Revision Details
                <div>
                  <%= if @edited_json do %>
                    <button type="button" class="btn btn-primary btn-sm mr-2" phx-click="save_edits">
                      <i class="fas fa-save"></i> Save as New Revision
                    </button>
                    <button
                      type="button"
                      class="btn btn-outline-primary btn-sm"
                      phx-click="cancel_edits"
                    >
                      Cancel
                    </button>
                  <% else %>
                    <button
                      type="button"
                      class="btn btn-outline-primary btn-sm mr-2"
                      phx-click="edit_json"
                    >
                      Edit JSON Content
                    </button>

                    <button
                      type="button"
                      class="btn btn-outline-danger btn-sm"
                      phx-click="show_restore_revision_modal"
                    >
                      Restore
                    </button>
                  <% end %>
                </div>
              </div>
              <div class="card-body" style="width: 95%;">
                <%= if !Enum.empty?(@edit_errors) do %>
                  <div class="text-danger mb-2">
                    Failed to save. JSON is invalid according to schema. Please fix the validation issues below and try again:
                  </div>
                  <%= for error <- @edit_errors do %>
                    <div class="alert alert-warning d-flex" role="alert">
                      <div class="flex-grow-1"><%= error %></div>
                      <div>
                        <a href={@resource_schema.schema["$id"]} target="_blank">
                          JSON Schema <i class="fas fa-external-link-alt"></i>
                        </a>
                      </div>
                    </div>
                  <% end %>
                <% end %>
                <.live_component
                  id="revision_details_table"
                  module={Details}
                  revision={@selected}
                  project={@project}
                  modal_assigns={@details_modal_assigns}
                />
              </div>
            </div>
          </div>
        </div>

        <form id="json-upload" phx-change="validate" phx-submit="save">
          <div class="row">
            <div class="col-12">
              <div class="card">
                <div class="card-header flex flex-row justify-between mb-2">
                  Upload JSON
                  <div>
                    <%= if @uploads.json.entries |> Enum.count() > 0 do %>
                      <button
                        type="submit"
                        class="btn btn-outline-danger btn-sm"
                        phx-disable-with="Uploading"
                      >
                        Set Content
                      </button>
                    <% else %>
                      <div class="btn btn-outline-danger btn-sm disabled">
                        Set Content
                      </div>
                    <% end %>
                  </div>
                </div>
                <div class="card-body">
                  <p>
                    Select a <code>.json</code>
                    file to upload and set as the content of this resource.
                  </p>
                  <section class="flex flex-col my-3" phx-drop-target={@uploads.json.ref}>
                    <.live_file_input upload={@uploads.json} />

                    <%= for entry <- @uploads.json.entries do %>
                      <div class="flex space-x-2 items-center">
                        <span><%= entry.client_name %></span>
                        <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>
                        <button
                          type="button"
                          phx-click="cancel-upload"
                          phx-value-ref={entry.ref}
                          aria-label="cancel"
                        >
                          &times;
                        </button>
                        <%= for err <- upload_errors(@uploads.json, entry) do %>
                          <p class="alert alert-danger">
                            <%= friendly_error(err) %>
                          </p>
                        <% end %>
                      </div>
                    <% end %>

                    <%= for {msg, el} <- @upload_errors do %>
                      <div class="alert alert-danger" role="alert">
                        JSON validation failed: <%= ~s{"#{msg} #{el}"} %>
                      </div>
                    <% end %>
                  </section>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp do_mount(revision, project, socket) do
    Subscriber.subscribe_to_new_revisions(revision.resource_id)
    Subscriber.subscribe_to_new_publications(project.slug)

    revisions = fetch_all_revisions(revision.resource_id)

    # Identified in MER-3625, duplicated resources created in the system prior to the
    # fix will have a first revision that points to the old resource revision. This
    # branch will identify those cases and fall back to using the first revision record
    # for a resource as the root of the revision tree.
    root =
      case Enum.filter(revisions, fn r -> is_nil(r.previous_revision_id) end) do
        [r | _] ->
          r

        _ ->
          # revisions are returned in descending order, so the last one is considered the root
          List.last(revisions)
      end

    tree = Oli.Versioning.RevisionTree.Tree.build(revisions, revision.resource_id)

    mappings = Publishing.get_all_mappings_for_resource(revision.resource_id, project.slug)

    mappings_by_revision =
      Enum.reduce(mappings, %{}, fn mapping, m -> Map.put(m, mapping.revision_id, mapping) end)

    selected = fetch_revision(hd(revisions).id)

    resource_schema =
      case Oli.Resources.ResourceType.get_type_by_id(selected.resource_type_id) do
        "page" ->
          SchemaResolver.resolve("page-content.schema.json")

        "activity" ->
          case selected.activity_type_id do
            1 -> SchemaResolver.resolve("adaptive-activity-content.schema.json")
            _ -> SchemaResolver.resolve("activity-content.schema.json")
          end

        _ ->
          SchemaResolver.resolve("page-content.schema.json")
      end

    {:ok,
     socket
     |> assign(
       breadcrumbs:
         Breadcrumb.trail_to(
           project.slug,
           revision.slug,
           Oli.Publishing.AuthoringResolver,
           project.customizations
         ) ++
           [Breadcrumb.new(%{full_title: "Revision History"})],
       view: "table",
       page_size: @page_size,
       tree: tree,
       root: root,
       resource_id: revision.resource_id,
       mappings: mappings_by_revision,
       publication: determine_most_recent_published(mappings),
       revisions: revisions,
       selected: selected,
       project: project,
       page_offset: 0,
       initial_size: length(revisions),
       uploaded_files: [],
       uploaded_content: nil,
       edit_errors: [],
       upload_errors: [],
       edited_json: nil,
       details_modal_assigns: nil,
       resource_schema: resource_schema
     )
     |> assign_new(:revision_root_slug, fn _ -> Resources.get_revision_root_slug(revision.id) end)
     |> allow_upload(:json, accept: ~w(.json), max_entries: 1)}
  end

  defp fetch_all_revisions(resource_id) do
    Repo.all(
      from(rev in Revision,
        join: a in Author,
        on: a.id == rev.author_id,
        where: rev.resource_id == ^resource_id,
        order_by: [desc: rev.inserted_at],
        preload: [:author],
        select:
          map(rev, [
            :id,
            :previous_revision_id,
            :inserted_at,
            :updated_at,
            :author_id,
            :slug,
            :author_id,
            author: [:email]
          ])
      )
    )
  end

  defp fetch_revision(revision_id) do
    Repo.get!(Revision, revision_id)
  end

  # Sorts newest to oldest
  defp date_sort(d1, d2) do
    case NaiveDateTime.compare(d1, d2) do
      :lt -> false
      _ -> true
    end
  end

  defp determine_most_recent_published(mappings) do
    all =
      Enum.reduce(mappings, MapSet.new(), fn mapping, m -> MapSet.put(m, mapping.publication) end)
      |> MapSet.to_list()
      |> Enum.sort(fn m1, m2 -> date_sort(m1.inserted_at, m2.inserted_at) end)

    case length(all) do
      1 -> nil
      _ -> Enum.at(all, 1)
    end
  end

  defp mimic_edit(socket, base_revision, content) do
    project_slug = socket.assigns.project.slug
    resource_id = socket.assigns.resource_id

    # First clear any lock that might be present on this resource.  Clearing the lock
    # is necessary to prevent an active editing session from stomping on what is about
    # to be restored
    publication = Publishing.project_working_publication(project_slug)

    Publishing.get_published_resource!(publication.id, resource_id)
    |> Publishing.update_published_resource(%{lock_updated_at: nil, locked_by_id: nil})

    # Now create and track the new revision, based on the current head for this project but
    # restoring the content, title and objectives and other settigns from the selected revision
    %Revision{
      title: title,
      objectives: objectives,
      scoring_strategy_id: scoring_strategy_id,
      graded: graded,
      max_attempts: max_attempts,
      author_id: author_id
    } = base_revision

    {:ok, revision} =
      AuthoringResolver.from_resource_id(project_slug, resource_id)
      |> Resources.create_revision_from_previous(%{
        author_id: author_id,
        content: content,
        title: title,
        objectives: objectives,
        scoring_strategy_id: scoring_strategy_id,
        graded: graded,
        max_attempts: max_attempts
      })

    Oli.Publishing.ChangeTracker.track_revision(project_slug, revision)

    Broadcaster.broadcast_revision(revision, project_slug)

    socket
    |> assign(selected: revision)
  end

  defp reset_editor(socket, default_value) do
    socket
    |> assign(
      edit_errors: [],
      edited_json: nil
    )
    |> push_event("monaco_editor_set_value", %{value: default_value})
    |> push_event("monaco_editor_set_options", %{"readOnly" => true})
  end

  defp friendly_error(:too_large), do: "File too large"
  defp friendly_error(:too_many_files), do: "Too many files"
  defp friendly_error(:not_accepted), do: "Unacceptable file type"

  defp flatten_validation_errors(errors) do
    errors
    |> Enum.map(fn {msg, el} -> "#{msg} #{el}" end)
  end
end
