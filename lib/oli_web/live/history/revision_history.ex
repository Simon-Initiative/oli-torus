defmodule OliWeb.RevisionHistory do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias OliWeb.RevisionHistory.Details
  alias OliWeb.RevisionHistory.Graph
  alias OliWeb.RevisionHistory.Table
  alias OliWeb.RevisionHistory.Pagination
  alias Oli.Authoring.Broadcaster
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.{Breadcrumb, SessionContext}
  alias OliWeb.History.RestoreRevisionModal
  alias Oli.Utils.SchemaResolver
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView

  @page_size 15

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @impl Phoenix.LiveView
  def mount(%{"slug" => slug, "project_id" => project_slug}, session, socket) do
    ctx = SessionContext.init(socket, session)

    case AuthoringResolver.from_revision_slug(project_slug, slug) do
      nil ->
        {:ok, LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      revision ->
        do_mount(revision, project_slug, socket, ctx)
    end
  end

  def mount(%{"resource_id" => resource_id_str, "project_id" => project_slug}, session, socket) do
    ctx = SessionContext.init(socket, session)

    case AuthoringResolver.from_resource_id(project_slug, String.to_integer(resource_id_str)) do
      nil ->
        {:ok, LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      revision ->
        do_mount(revision, project_slug, socket, ctx)
    end
  end

  defp do_mount(revision, project_slug, socket, ctx) do
    project = Course.get_project_by_slug(project_slug)
    resource_id = revision.resource_id
    slug = revision.slug

    Subscriber.subscribe_to_new_revisions(resource_id)
    Subscriber.subscribe_to_new_publications(project_slug)

    revisions = fetch_all_revisions(resource_id)

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

    tree = Oli.Versioning.RevisionTree.Tree.build(revisions, resource_id)

    mappings = Publishing.get_all_mappings_for_resource(resource_id, project_slug)

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
       ctx: ctx,
       breadcrumbs:
         Breadcrumb.trail_to(
           project_slug,
           slug,
           Oli.Publishing.AuthoringResolver,
           project.customizations
         ) ++
           [Breadcrumb.new(%{full_title: "Revision History"})],
       view: "table",
       page_size: @page_size,
       tree: tree,
       root: root,
       resource_id: resource_id,
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

  def handle_event("reset_monaco", _params, socket) do
    {:noreply, assign(socket, details_modal_assigns: nil)}
  end

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

  defp friendly_error(:too_large), do: "File too large"
  defp friendly_error(:too_many_files), do: "Too many files"
  defp friendly_error(:not_accepted), do: "Unacceptable file type"

  defp flatten_validation_errors(errors) do
    errors
    |> Enum.map(fn {msg, el} -> "#{msg} #{el}" end)
  end
end
