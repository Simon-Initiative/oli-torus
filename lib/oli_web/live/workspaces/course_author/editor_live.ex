defmodule OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLive do
  use OliWeb, :live_view
  use Phoenix.HTML

  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.PartComponents
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.React
  alias OliWeb.Workspaces.CourseAuthor.HistoryLive

  @impl true
  def mount(
        %{"project_id" => project_slug, "revision_slug" => revision_slug} = params,
        _session,
        socket
      ) do
    author = socket.assigns[:current_author]
    project = socket.assigns.project
    is_admin? = Accounts.at_least_content_admin?(author)

    case PageEditor.create_context(project_slug, revision_slug, author) do
      {:ok, context} ->
        live_edit(socket, project, context, project_slug, revision_slug, is_admin?, params)

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Revision not found")
         |> push_navigate(to: ~p"/workspaces/course_author")}
    end
  end

  @impl true
  def render(%{app_params: _app_params} = assigns) do
    ~H"""
    <div id="react_to_live_view" phx-hook="ReactToLiveView" phx-update="ignore"></div>
    <.scripts_wrapper socket={@socket} error={@error} maybe_scripts_loaded={@maybe_scripts_loaded}>
      <div id="editor" class="container">
        {React.component(@ctx, "Components.Authoring", @app_params, id: "authoring_editor")}
      </div>
      {render_prev_next_nav(assigns)}
    </.scripts_wrapper>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="react_to_live_view" phx-hook="ReactToLiveView" phx-update="ignore"></div>
    <.scripts_wrapper socket={@socket} error={@error} maybe_scripts_loaded={@maybe_scripts_loaded}>
      <%= if @is_admin? do %>
        <div
          class="alert alert-warning alert-dismissible flex flex-row fade show container mt-2 mx-auto"
          role="alert"
        >
          <div class="flex-1">
            <strong>You are editing as an administrator</strong>
          </div>

          <div>
            <%= link class: "toolbar-link", to: Routes.live_path(OliWeb.Endpoint, HistoryLive, @project_slug, @revision_slug) do %>
              <span style="margin-right: 5px"><i class="fas fa-history"></i></span><span>View History</span>
            <% end %>
          </div>

          <button type="button" class="close ml-4" data-bs-dismiss="alert" aria-label="Close">
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      <% end %>

      <div id="editor" style="width: 95%;" class="container mx-auto">
        {React.component(@ctx, "Components.PageEditor", @raw_context, id: "page_editor")}
      </div>

      <div class="container mx-auto mt-5">
        {live_render(@socket, OliWeb.CollaborationLive.CollabSpaceConfigView,
          id: "collab-space-#{@project_slug}-#{@revision_slug}",
          session: %{
            "collab_space_config" => @collab_space_config,
            "project_slug" => @project_slug,
            "resource_slug" => @revision_slug
          }
        )}
      </div>

      {render_prev_next_nav(assigns)}
    </.scripts_wrapper>
    """
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
  end

  @impl true
  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply,
     socket
     |> assign(:error, true)
     |> assign(:maybe_scripts_loaded, true)
     |> maybe_enable_preview_after_scripts_load()}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply,
     socket
     |> assign(:maybe_scripts_loaded, true)
     |> maybe_enable_preview_after_scripts_load()}
  end

  def handle_event("authoring_title_lock_state_changed", %{"editable" => editable}, socket) do
    _ = editable
    {:noreply, socket}
  end

  def handle_event("authoring_readonly_state_changed", %{"readonly" => readonly}, socket) do
    readonly = normalize_boolean(readonly)

    {:noreply,
     socket
     |> assign(:authoring_notice, nil)
     |> assign(:adaptive_read_only, readonly)
     |> refresh_title_editable(readonly)}
  end

  def handle_event(
        "authoring_readonly_toggle_failed",
        %{"message" => message, "readonly" => readonly},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:adaptive_read_only, normalize_boolean(readonly))
     |> put_flash(:error, message)}
  end

  def handle_event("authoring_readonly_toggle_failed", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("authoring_readonly_edit_blocked", %{"message" => message}, socket) do
    {:noreply, assign(socket, :authoring_notice, message)}
  end

  def handle_event("dismiss_authoring_notice", _params, socket) do
    {:noreply, assign(socket, :authoring_notice, nil)}
  end

  def handle_event("authoring_preview_state_changed", %{"enabled" => enabled}, socket) do
    {:noreply, assign(socket, :preview_enabled, normalize_boolean(enabled))}
  end

  def handle_event("toggle_adaptive_read_only", params, socket) do
    desired_read_only = Map.has_key?(params, "adaptive_read_only")

    cond do
      !socket.assigns.lock_controls_enabled ->
        {:noreply, socket}

      !socket.assigns.preview_enabled ->
        {:noreply, socket}

      desired_read_only == socket.assigns.adaptive_read_only ->
        {:noreply, socket}

      true ->
        {:noreply,
         socket
         |> assign(:adaptive_read_only, desired_read_only)
         |> push_event("adaptive_readonly_toggle_requested", %{readonly: desired_read_only})}
    end
  end

  def handle_event("begin_title_edit", _params, socket) do
    socket = refresh_title_editable(socket)

    if socket.assigns.title_editable do
      {:noreply,
       assign(socket,
         title_editing: true,
         title_input: socket.assigns.page_title
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_title_edit", _params, socket) do
    {:noreply,
     assign(socket,
       title_editing: false,
       title_input: socket.assigns.page_title
     )}
  end

  def handle_event("save_title", %{"title_editor" => %{"title" => title}}, socket) do
    title = String.trim(title)
    socket = refresh_title_editable(socket)

    cond do
      !socket.assigns.title_editable ->
        {:noreply,
         socket
         |> assign(:title_editing, false)
         |> maybe_put_title_lock_conflict_flash()}

      title == "" ->
        {:noreply, put_flash(socket, :error, "Title cannot be blank")}

      title == socket.assigns.page_title ->
        {:noreply,
         assign(socket,
           title_editing: false,
           title_input: socket.assigns.page_title
         )}

      true ->
        save_page_title(socket, title)
    end
  end

  def handle_event("request_authoring_preview", _params, socket) do
    if socket.assigns.preview_enabled do
      {:noreply,
       push_event(socket, "authoring_preview_requested", %{
         url: preview_url(socket),
         window_name: preview_window_name(socket)
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {:lock_acquired, publication_id, resource_id, author_id},
        %{assigns: %{current_author: current_author, context: context}} = socket
      ) do
    cond do
      publication_id != socket.assigns.unpublished_publication_id ->
        {:noreply, socket}

      resource_id != context.resourceId ->
        {:noreply, socket}

      author_id == current_author.id ->
        {:noreply,
         socket
         |> assign(:lock_holder_id, current_author.id)
         |> assign(:lock_holder_email, current_author.email)
         |> refresh_lock_controls_enabled()
         |> refresh_title_editable()}

      true ->
        if socket.assigns.is_advanced_authoring do
          {:noreply,
           socket
           |> assign(:lock_holder_id, author_id)
           |> assign(:lock_holder_email, nil)
           |> assign(:adaptive_read_only, true)
           |> assign(:lock_controls_enabled, false)
           |> assign(:title_editable, false)
           |> assign(:title_editing, false)}
        else
          {:noreply,
           socket
           |> assign(:lock_holder_id, author_id)
           |> assign(:lock_holder_email, nil)
           |> assign(:title_editable, false)
           |> assign(:title_editing, false)}
        end
    end
  end

  def handle_info(
        {:lock_released, publication_id, resource_id},
        %{assigns: %{context: context}} = socket
      ) do
    cond do
      publication_id != socket.assigns.unpublished_publication_id ->
        {:noreply, socket}

      resource_id != context.resourceId ->
        {:noreply, socket}

      true ->
        {:noreply,
         socket
         |> assign(:lock_holder_id, nil)
         |> assign(:lock_holder_email, nil)
         |> refresh_lock_controls_enabled()
         |> refresh_title_editable()}
    end
  end

  defp maybe_show_error(assigns) do
    ~H"""
    <div :if={@error} class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
      Something went wrong when loading the JS dependencies.
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:title_input, :string, required: true)
  attr(:title_editing, :boolean, required: true)
  attr(:title_editable, :boolean, required: true)
  attr(:adaptive_read_only, :boolean, required: true)
  attr(:is_advanced_authoring, :boolean, required: true)
  attr(:preview_enabled, :boolean, required: true)
  attr(:lock_controls_enabled, :boolean, required: true)
  attr(:authoring_notice, :string, default: nil)

  def authoring_header(assigns) do
    ~H"""
    <div class="container mx-auto">
      <div class="resource-editor row">
        <div class="col-span-12">
          <div class="TitleBar w-100 align-items-baseline z-40" style="top: 64px;">
            <div class="d-flex flex-wrap items-center justify-between gap-3 px-3 md:px-4 pt-1 pb-2">
              <div class="d-flex align-items-baseline flex-grow-1 mr-2 min-w-0">
                <%= if @title_editing do %>
                  <.form
                    for={%{}}
                    as={:title_editor}
                    phx-submit="save_title"
                    class="d-flex inline-flex flex-grow-1"
                  >
                    <input
                      id="page_title_input"
                      type="text"
                      name="title_editor[title]"
                      value={@title_input}
                      aria-label="Page Title"
                      class="form-control form-control-sm flex-1"
                      autocomplete="off"
                    />
                    <div class="whitespace-nowrap">
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm ml-2"
                      >
                        Save
                      </button>
                      <button
                        type="button"
                        class="btn btn-secondary btn-sm ml-1"
                        phx-click="cancel_title_edit"
                      >
                        Cancel
                      </button>
                    </div>
                  </.form>
                <% else %>
                  <h1 style="display: inline-block; white-space: normal; text-align: left; font-weight: normal; font-size: 1.5rem; margin: 0;">
                    {@title}
                  </h1>
                  <button
                    type="button"
                    class={[
                      "btn btn-link btn-sm",
                      if(!@title_editable, do: "disabled opacity-60 cursor-not-allowed")
                    ]}
                    phx-click="begin_title_edit"
                    disabled={!@title_editable}
                  >
                    Edit Title
                  </button>
                <% end %>
              </div>
              <div class="d-flex shrink-0 items-center gap-3 whitespace-nowrap">
                <.read_only_toggle
                  :if={@is_advanced_authoring}
                  adaptive_read_only={@adaptive_read_only}
                  enabled={@preview_enabled && @lock_controls_enabled}
                />
                <button
                  type="button"
                  class={[
                    "btn btn-primary btn-sm rounded-pill px-4 d-inline-flex items-center gap-2",
                    if(!@preview_enabled, do: "disabled opacity-60 cursor-not-allowed")
                  ]}
                  phx-click="request_authoring_preview"
                  disabled={!@preview_enabled}
                >
                  <i class="fa-regular fa-file-lines"></i>
                  <span>Preview</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div
        :if={@authoring_notice}
        class="pointer-events-none fixed right-4 top-[8.5rem] z-50 max-w-md"
      >
        <div class="pointer-events-auto alert alert-info shadow-lg flex flex-row gap-3 items-start mb-0">
          <div class="flex-1">
            {@authoring_notice}
          </div>
          <button
            type="button"
            class="close"
            aria-label="Close"
            phx-click="dismiss_authoring_notice"
          >
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr(:adaptive_read_only, :boolean, required: true)
  attr(:enabled, :boolean, required: true)

  def read_only_toggle(assigns) do
    ~H"""
    <div>
      <form id="adaptive_read_only_toggle" phx-change="toggle_adaptive_read_only" class="mb-0">
        <label class={[
          "mb-0 inline-flex items-center gap-2",
          if(@enabled, do: "cursor-pointer", else: "cursor-not-allowed opacity-60")
        ]}>
          <span class="text-sm font-semibold text-[#111827] dark:text-[#F5F5F5]">Read only</span>
          <input
            type="checkbox"
            name="adaptive_read_only"
            class="sr-only peer"
            role="switch"
            aria-checked={to_string(@adaptive_read_only)}
            checked={@adaptive_read_only}
            disabled={!@enabled}
          />
          <div class="relative h-6 w-11 rounded-full bg-gray-200 transition-colors duration-300 ease-in-out after:absolute after:start-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-gray-300 after:bg-white after:transition-transform after:duration-300 after:ease-in-out after:content-[''] peer-checked:bg-primary peer-checked:after:translate-x-full peer-checked:after:border-white peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary-300 dark:bg-gray-700 dark:peer-focus:ring-primary-800 dark:border-gray-600">
          </div>
        </label>
      </form>
    </div>
    """
  end

  slot :inner_block, required: true
  attr(:socket, :any, required: true)
  attr(:error, :boolean, required: true)
  attr(:maybe_scripts_loaded, :boolean, required: true)

  def scripts_wrapper(assigns) do
    ~H"""
    <div id="eventIntercept" phx-hook="LoadSurveyScripts">
      <%= if connected?(@socket) and @maybe_scripts_loaded do %>
        <.maybe_show_error error={@error} />
        {render_slot(@inner_block)}
      <% else %>
        <.loader />
      <% end %>
    </div>
    """
  end

  defp live_edit(socket, project, context, project_slug, revision_slug, is_admin?, params) do
    context = Map.put(context, :hasExperiments, project.has_experiments)
    activity_types = Activities.activities_for_project(project)
    part_component_types = PartComponents.part_components_for_project(project)

    breadcrumbs =
      Breadcrumb.trail_to(project_slug, revision_slug, AuthoringResolver, project.customizations)

    is_advanced_authoring =
      context.content && Map.get(context.content, "advancedAuthoring", false)

    content = %{
      active: :curriculum,
      activity_types: activity_types,
      breadcrumbs: breadcrumbs,
      collab_space_config: context.collab_space_config,
      graded: context.graded,
      is_admin?: is_admin?,
      part_component_types: part_component_types,
      part_scripts: PartComponents.get_part_component_scripts(),
      project_slug: project_slug,
      context: context,
      raw_context: context,
      revision_slug: revision_slug,
      scripts: Activities.get_activity_scripts(),
      title: "Edit | " <> context.title,
      resource_title: project.title,
      resource_slug: project.slug
    }

    {content, target_scripts} =
      case context do
        %{content: %{"advancedAuthoring" => true}} ->
          activity_type_scripts =
            Enum.reduce(activity_types, [], fn %{slug: slug, authoring_script: authoring_script},
                                               acc ->
              if slug == "oli_adaptive", do: [authoring_script | acc], else: acc
            end)

          updated_content =
            Map.put(content, :app_params, %{
              isAdmin: is_admin?,
              revisionSlug: revision_slug,
              projectSlug: project_slug,
              graded: context.graded,
              content: context,
              creationModeHint: creation_mode_hint(params, context),
              paths: %{images: Routes.static_path(socket, "/images")},
              activityTypes: activity_types,
              partComponentTypes: part_component_types,
              appsignalKey: Application.get_env(:appsignal, :client_key),
              initialSidebarExpanded: socket.assigns[:sidebar_expanded]
            })

          {updated_content, ["authoring.js"] ++ activity_type_scripts}

        _ ->
          {content, ["pageeditor.js"]}
      end

    all_scripts = content.part_scripts ++ content.scripts ++ target_scripts
    all_scripts = all_scripts |> Enum.uniq() |> Enum.map(&"/js/#{&1}")
    unpublished_publication_id = Publishing.get_unpublished_publication_id!(project.id)
    lock_info = Publishing.retrieve_lock_info([context.resourceId], unpublished_publication_id)

    %{lock_holder_id: lock_holder_id, lock_holder_email: lock_holder_email} =
      lock_holder_assigns(lock_info)

    socket =
      socket
      |> assign(maybe_scripts_loaded: false)
      |> assign(error: false)
      |> assign(breadcrumbs: breadcrumbs)
      |> assign(is_advanced_authoring: is_advanced_authoring)
      |> assign(page_title: context.title)
      |> assign(title_input: context.title)
      |> assign(title_editing: false)
      |> assign(authoring_notice: nil)
      |> assign(
        title_editable:
          current_author_holds_lock?(lock_holder_id, socket.assigns.current_author.id) and
            not is_advanced_authoring
      )
      |> assign(adaptive_read_only: is_advanced_authoring)
      |> assign(preview_enabled: false)
      |> assign(unpublished_publication_id: unpublished_publication_id)
      |> assign(lock_holder_id: lock_holder_id)
      |> assign(lock_holder_email: lock_holder_email)
      |> assign(
        :lock_controls_enabled,
        if(is_advanced_authoring,
          do: initial_lock_controls_enabled(lock_info, socket.assigns.current_author.id),
          else: false
        )
      )
      |> assign(show_authoring_header: true)
      |> push_event("load_survey_scripts", %{script_sources: all_scripts})

    if connected?(socket) do
      Subscriber.subscribe_to_locks_acquired(project_slug, context.resourceId)
      Subscriber.subscribe_to_locks_released(project_slug, context.resourceId)
    end

    {:ok, assign(socket, content)}
  end

  defp save_page_title(socket, title) do
    project_slug = socket.assigns.project_slug
    revision_slug = socket.assigns.revision_slug
    author = socket.assigns.current_author

    with {:acquired} <- PageEditor.acquire_lock(project_slug, revision_slug, author.email),
         {:ok, revision} <-
           PageEditor.edit(project_slug, revision_slug, author.email, %{
             "title" => title,
             "releaseLock" => false
           }) do
      breadcrumbs =
        Breadcrumb.trail_to(
          project_slug,
          revision.slug,
          AuthoringResolver,
          socket.assigns.project.customizations
        )

      socket =
        socket
        |> assign(:breadcrumbs, breadcrumbs)
        |> assign(:page_title, revision.title)
        |> assign(:revision_slug, revision.slug)
        |> assign(:title_input, revision.title)
        |> assign(:title_editing, false)
        |> assign(:title, "Edit | " <> revision.title)
        |> assign(:lock_holder_id, author.id)
        |> assign(:lock_holder_email, author.email)
        |> refresh_title_editable()
        |> update_context_assigns(revision.title, revision.slug)
        |> push_event("authoring_page_title_updated", %{
          title: revision.title,
          revision_slug: revision.slug
        })

      socket =
        if revision.slug != revision_slug do
          push_patch(
            socket,
            to: ~p"/workspaces/course_author/#{project_slug}/curriculum/#{revision.slug}/edit"
          )
        else
          socket
        end

      {:noreply, socket}
    else
      {:lock_not_acquired, {user, _updated_at}} ->
        {:noreply, put_flash(socket, :error, lock_conflict_message(user))}

      {:error, {:lock_not_acquired, {user, _updated_at}}} ->
        {:noreply, put_flash(socket, :error, lock_conflict_message(user))}

      {:error, {:not_found}} ->
        {:noreply, put_flash(socket, :error, "This page could not be found")}

      {:error, {:not_authorized}} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to edit this page")}

      {:error, {:error}} ->
        {:noreply, put_flash(socket, :error, "Could not save the updated title")}

      error ->
        {_, msg} = Oli.Utils.log_error("Could not update page title", error)
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  defp update_context_assigns(socket, title, revision_slug) do
    updated_raw_context =
      socket.assigns.raw_context
      |> Map.put(:title, title)
      |> Map.put(:resourceSlug, revision_slug)

    socket
    |> maybe_assign_app_params(title, revision_slug)
    |> assign(:raw_context, updated_raw_context)
  end

  defp maybe_assign_app_params(socket, title, revision_slug) do
    case Map.get(socket.assigns, :app_params) do
      nil ->
        socket

      app_params ->
        assign(socket, :app_params, %{
          app_params
          | revisionSlug: revision_slug,
            content:
              app_params.content
              |> Map.put(:title, title)
              |> Map.put(:resourceSlug, revision_slug)
        })
    end
  end

  defp creation_mode_hint(%{"creation_mode" => "expert"}, %{
         content: %{"advancedAuthoring" => true}
       }),
       do: "expert"

  defp creation_mode_hint(_params, _context), do: nil

  defp preview_url(socket),
    do:
      "/authoring/project/#{socket.assigns.project_slug}/preview/#{socket.assigns.revision_slug}"

  defp preview_window_name(socket), do: "preview-#{socket.assigns.project_slug}"

  defp maybe_enable_preview_after_scripts_load(socket) do
    if socket.assigns.is_advanced_authoring do
      socket
    else
      assign(socket, :preview_enabled, true)
    end
  end

  defp lock_conflict_message(user),
    do:
      "This page is currently being edited by #{user}. You can change the title after the edit lock is released."

  defp maybe_put_title_lock_conflict_flash(socket) do
    case socket.assigns.lock_holder_email do
      email when is_binary(email) ->
        put_flash(socket, :error, lock_conflict_message(email))

      _ ->
        socket
    end
  end

  defp refresh_title_editable(socket, adaptive_read_only \\ nil) do
    adaptive_read_only =
      if is_nil(adaptive_read_only),
        do: socket.assigns.adaptive_read_only,
        else: adaptive_read_only

    assign(socket, :title_editable, title_editable?(socket, adaptive_read_only))
  end

  defp refresh_lock_controls_enabled(socket) do
    if socket.assigns.is_advanced_authoring do
      assign(socket, :lock_controls_enabled, lock_controls_enabled?(socket))
    else
      socket
    end
  end

  defp title_editable?(socket, adaptive_read_only) do
    current_author_holds_lock?(socket) and
      (!socket.assigns.is_advanced_authoring or !adaptive_read_only)
  end

  defp lock_controls_enabled?(socket) do
    is_nil(socket.assigns.lock_holder_id) or current_author_holds_lock?(socket)
  end

  defp current_author_holds_lock?(socket) do
    current_author_holds_lock?(socket.assigns.lock_holder_id, socket.assigns.current_author.id)
  end

  defp current_author_holds_lock?(lock_holder_id, current_author_id),
    do: lock_holder_id == current_author_id

  defp lock_holder_assigns([%{author: %{id: id, email: email}} | _]) do
    %{lock_holder_id: id, lock_holder_email: email}
  end

  defp lock_holder_assigns(_), do: %{lock_holder_id: nil, lock_holder_email: nil}

  defp normalize_boolean(value) do
    case value do
      true -> true
      false -> false
      "true" -> true
      "false" -> false
      _ -> false
    end
  end

  defp initial_lock_controls_enabled(lock_info, current_author_id) do
    case lock_info do
      [] -> true
      [%{author: %{id: ^current_author_id}}] -> true
      _ -> false
    end
  end

  defp render_prev_next_nav(assigns) do
    ~H"""
    <nav class="previous-next-nav d-flex flex-row" aria-label="Page navigation">
      <%= if @context.previous_page do %>
        <.link
          class="page-nav-link btn"
          navigate={
            ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@context.previous_page["slug"]}/edit"
          }
        >
          <div class="flex items-center justify-between">
            <div class="mr-4">
              <i class="fas fa-arrow-left nav-icon"></i>
            </div>
            <div class="flex flex-col text-right overflow-hidden">
              <div class="nav-label">{"Previous"}</div>
              <div class="nav-title">{@context.previous_page["title"]}</div>
            </div>
          </div>
        </.link>
      <% else %>
        <div class="page-nav-link-placeholder"></div>
      <% end %>

      <div class="flex-grow-1"></div>

      <%= if @context.next_page do %>
        <.link
          class="page-nav-link btn"
          navigate={
            ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@context.next_page["slug"]}/edit"
          }
        >
          <div class="flex items-center justify-between">
            <div class="flex flex-col text-left overflow-hidden">
              <div class="nav-label">{"Next"}</div>
              <div class="nav-title">{@context.next_page["title"]}</div>
            </div>
            <div class="ml-4">
              <i class="fas fa-arrow-right nav-icon"></i>
            </div>
          </div>
        </.link>
      <% else %>
        <div class="page-nav-link-placeholder"></div>
      <% end %>
    </nav>
    """
  end
end
