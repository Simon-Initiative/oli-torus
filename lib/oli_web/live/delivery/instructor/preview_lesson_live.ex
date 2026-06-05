defmodule OliWeb.Delivery.Instructor.PreviewLessonLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils, only: [scripts: 1, references: 1]

  alias Oli.Accounts
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Revision
  alias OliWeb.Delivery.Instructor.PreviewReturn
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Delivery.Instructor.{PreviewPageContext, PreviewRoutes}
  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Delivery.Student.Lesson.Annotations
  alias OliWeb.Delivery.Student.Lesson.Components.OutlineComponent

  def mount(%{"revision_slug" => revision_slug} = params, _session, socket) do
    section = socket.assigns.section

    case Resolver.from_revision_slug(section.slug, revision_slug) do
      nil ->
        {:ok,
         redirect(socket,
           to:
             PreviewRoutes.page_path(
               section.slug,
               revision_slug,
               adaptive_redirect_params(params)
             )
         )}

      %Revision{content: %{"advancedDelivery" => true}} = revision ->
        {:ok,
         redirect(socket,
           to:
             PreviewRoutes.page_path(
               section.slug,
               revision.slug,
               adaptive_redirect_params(params)
             )
         )}

      %Revision{} = revision ->
        sidebar_expanded = preview_sidebar_state(params)
        navigation_params = navigation_params(params, section.slug)

        assigns =
          PreviewPageContext.build(
            section,
            revision,
            socket.assigns[:current_user],
            navigation_params
          )

        {:ok,
         socket
         |> assign(assigns)
         |> assign(
           :sidebar_expanded,
           sidebar_expanded
         )
         |> assign_preview_shell_state()}
    end
  end

  def render(%{graded: true} = assigns) do
    ~H"""
    <div id="instructor-preview-lesson" data-preview-mode={@preview_mode}>
      <.scripts scripts={@scripts} user_token={assigns[:user_token]} />

      <Layouts.instructor_preview_header return_context={@instructor_preview_return} />
      <Layouts.header
        ctx={@ctx}
        is_admin={@is_admin}
        section={@section}
        preview_mode={@preview_mode}
        sidebar_expanded={@sidebar_expanded}
        instructor_preview_return={@instructor_preview_return}
        include_logo
      />

      <.preview_back_nav request_path={@request_path} />

      <.page_content_with_sidebar_layout active_sidebar_panel={nil}>
        <section class="flex flex-col gap-6">
          <.preview_page_header
            page_context={@page_context}
            ctx={@ctx}
            current_page={@current_page}
            objectives={@objectives}
            section={@section}
          />

          <.preview_page_content
            html={@html}
            ctx={@ctx}
            bib_app_params={@bib_app_params}
            graded={@graded}
            question_count={@question_count}
          />

          <.preview_previous_next_nav
            current_page={@current_page}
            next_page={@next_page}
            previous_page={@previous_page}
            section_slug={@section_slug}
            request_path={@request_path}
            selected_view={@selected_view}
            navigation_params={@navigation_params}
          />
        </section>
      </.page_content_with_sidebar_layout>

      <.preview_footer license={assigns[:license]} />
      <Utils.proficiency_explanation_modal />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="instructor-preview-lesson" data-preview-mode={@preview_mode}>
      <.scripts scripts={@scripts} user_token={assigns[:user_token]} />

      <Layouts.instructor_preview_header return_context={@instructor_preview_return} />
      <Layouts.header
        ctx={@ctx}
        is_admin={@is_admin}
        section={@section}
        preview_mode={@preview_mode}
        sidebar_expanded={@sidebar_expanded}
        instructor_preview_return={@instructor_preview_return}
        include_logo
      />

      <.preview_back_nav request_path={@request_path} />
      <.page_content_with_sidebar_layout active_sidebar_panel={@active_sidebar_panel}>
        <section class="flex flex-col gap-6">
          <.preview_page_header
            page_context={@page_context}
            ctx={@ctx}
            current_page={@current_page}
            objectives={@objectives}
            section={@section}
          />

          <.preview_page_content
            html={@html}
            ctx={@ctx}
            bib_app_params={@bib_app_params}
            graded={@graded}
            question_count={@question_count}
          />

          <.preview_previous_next_nav
            current_page={@current_page}
            next_page={@next_page}
            previous_page={@previous_page}
            section_slug={@section_slug}
            request_path={@request_path}
            selected_view={@selected_view}
            navigation_params={@navigation_params}
          />
        </section>
      </.page_content_with_sidebar_layout>

      <div
        id="sticky_panel"
        class="absolute w-full pointer-events-none sm:w-auto sm:top-4 sm:right-0 z-50 sm:h-full"
      >
        <div class="fixed z-50 bottom-0 w-full pointer-events-none sm:sticky sm:ml-auto sm:top-40 sm:right-0">
          <div class={[
            "hidden sm:inline-flex absolute top-24 pointer-events-auto",
            if(@active_sidebar_panel == :outline, do: "sm:right-[380px]"),
            if(@active_sidebar_panel == :notes, do: "sm:right-[505px]"),
            if(@active_sidebar_panel == nil, do: "sm:right-0")
          ]}>
            <div class="inline-flex h-32 rounded-tl-xl rounded-bl-xl justify-start items-center">
              <div class={[
                "px-2 py-6 bg-Surface-surface-background shadow flex-col justify-center gap-4 inline-flex",
                if(@active_sidebar_panel,
                  do: "rounded-t-xl rounded-b-xl",
                  else: "rounded-tl-xl rounded-bl-xl"
                )
              ]}>
                <Annotations.toggle_notes_button
                  :if={@notes_enabled?}
                  is_active={@active_sidebar_panel == :notes}
                >
                  <Annotations.annotations_icon />
                </Annotations.toggle_notes_button>

                <OutlineComponent.toggle_outline_button is_active={@active_sidebar_panel == :outline}>
                  <OutlineComponent.outline_icon />
                </OutlineComponent.toggle_outline_button>
              </div>
            </div>
          </div>

          <%= case @active_sidebar_panel do %>
            <% :notes -> %>
              <div class="pointer-events-auto">
                <Annotations.panel
                  section_slug={@section_slug}
                  collab_space_config={@collab_space_config}
                  create_new_annotation={false}
                  annotations={@annotations.posts}
                  current_user={@current_user}
                  is_instructor={true}
                  active_tab={@annotations.active_tab}
                  search_results={@annotations.search_results}
                  search_term={@annotations.search_term}
                  selected_point={@annotations.selected_point}
                  go_to_page_href_builder={&preview_page_href(&1, @section_slug, @navigation_params)}
                  show_go_to_post_links={true}
                  read_only={true}
                />
              </div>
            <% :outline -> %>
              <div class="pointer-events-auto">
                <.live_component
                  module={OutlineComponent}
                  id="outline_component"
                  hierarchy={@hierarchy}
                  section_slug={@section_slug}
                  section_id={@section.id}
                  user_id={@current_user.id}
                  page_resource_id={@current_page["id"]}
                  selected_view={:gallery}
                  display_curriculum_item_numbering={@display_curriculum_item_numbering}
                  route_builder={&preview_page_href(&1, @section_slug, @navigation_params)}
                  show_progress={false}
                />
              </div>
            <% nil -> %>
              <div></div>
          <% end %>
        </div>
      </div>
      <.preview_footer license={assigns[:license]} />
      <Utils.proficiency_explanation_modal />
    </div>
    """
  end

  attr :request_path, :string, required: true

  defp preview_back_nav(assigns) do
    ~H"""
    <div class="sticky top-40 z-50 md:h-20 2xl:h-28">
      <div class="hidden md:block">
        <Layouts.back_arrow to={@request_path} show_sidebar={false} view={:practice_page} />
      </div>
      <div
        role="navigation"
        aria-label="Preview actions"
        class="flex flex-row justify-between items-center sm:hidden bg-Surface-surface-secondary h-10 px-4"
      >
        <.link navigate={@request_path} class="w-24 text-Text-text-high flex items-center gap-2">
          <OliWeb.Icons.back_arrow /><span>Back</span>
        </.link>
      </div>
    </div>
    """
  end

  attr :page_context, :map, required: true
  attr :ctx, :map, required: true
  attr :current_page, :map, required: true
  attr :objectives, :list, required: true
  attr :section, :map, required: true

  defp preview_page_header(assigns) do
    ~H"""
    <Utils.page_header
      page_context={@page_context}
      ctx={@ctx}
      index={@current_page["index"]}
      objectives={@objectives}
      container_label={
        Utils.get_container_label(
          @current_page["id"],
          @section,
          @section.display_curriculum_item_numbering
        )
      }
      display_curriculum_item_numbering={@section.display_curriculum_item_numbering}
    />
    """
  end

  attr :html, :string, required: true
  attr :ctx, :map, required: true
  attr :bib_app_params, :any, required: true
  attr :graded, :boolean, required: true
  attr :question_count, :integer, required: true

  defp preview_page_content(assigns) do
    ~H"""
    <div
      id="page_content"
      class="content"
      phx-update="ignore"
      role="region"
      aria-label="Page content"
    >
      {raw(@html)}
      <div :if={@graded && @question_count == 0} class="flex w-full justify-center py-8">
        <p>There are no questions available for this page.</p>
      </div>
      <.references ctx={@ctx} bib_app_params={@bib_app_params} />
    </div>
    """
  end

  attr :current_page, :map, required: true
  attr :next_page, :map, default: nil
  attr :previous_page, :map, default: nil
  attr :section_slug, :string, required: true
  attr :request_path, :string, required: true
  attr :selected_view, :atom, required: true
  attr :navigation_params, :map, required: true

  defp preview_previous_next_nav(assigns) do
    ~H"""
    <div class="flex justify-center pt-6">
      <Layouts.previous_next_nav
        current_page={@current_page}
        next_page={@next_page}
        previous_page={@previous_page}
        section_slug={@section_slug}
        request_path={@request_path}
        selected_view={Atom.to_string(@selected_view)}
        preview_mode={true}
        navigation_params={@navigation_params}
      />
    </div>
    """
  end

  attr :license, :map, default: nil

  defp preview_footer(assigns) do
    ~H"""
    <div class="mb-20 px-4 mt-auto relative">
      <div
        id="tech-support-wrapper"
        phx-hook="StickyTechSupportButton"
        class="w-full md:container lg:px-10"
      >
        <OliWeb.Components.Common.tech_support_button
          id="tech-support"
          class="-ml-4 md:-ml-3 xl:fixed xl:bottom-2 xl:left-10 xl:z-[999]"
        />
      </div>
      <OliWeb.Components.Footer.delivery_footer
        license={@license}
        show_cookie_preferences={true}
      />
    </div>
    """
  end

  def handle_event("toggle_outline_sidebar", _params, socket) do
    active_sidebar_panel =
      if socket.assigns.active_sidebar_panel != :outline, do: :outline, else: nil

    if socket.assigns[:current_user] do
      Accounts.set_user_preference(
        socket.assigns.current_user,
        :page_outline_panel_active?,
        active_sidebar_panel == :outline
      )
    end

    {:noreply, assign(socket, active_sidebar_panel: active_sidebar_panel)}
  end

  def handle_event("toggle_notes_sidebar", _params, socket) do
    active_sidebar_panel = if socket.assigns.active_sidebar_panel != :notes, do: :notes, else: nil

    if active_sidebar_panel == :notes && is_nil(socket.assigns.annotations.posts) do
      {:noreply,
       socket
       |> assign_annotations(
         load_annotations(
           socket.assigns.section,
           socket.assigns.current_page["id"],
           socket.assigns.current_user,
           socket.assigns.collab_space_config,
           :public,
           :page
         )
       )
       |> assign(active_sidebar_panel: active_sidebar_panel)}
    else
      {:noreply, assign(socket, active_sidebar_panel: active_sidebar_panel)}
    end
  end

  def handle_event("search", %{"search_term" => ""}, socket) do
    {:noreply, assign_annotations(socket, search_results: nil, search_term: "")}
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    {:noreply,
     assign_annotations(socket,
       search_results:
         search_annotations(
           socket.assigns.section,
           socket.assigns.current_page["id"],
           socket.assigns.current_user,
           :public,
           socket.assigns.annotations.selected_point,
           search_term
         ),
       search_term: search_term
     )}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign_annotations(
       load_annotations(
         socket.assigns.section,
         socket.assigns.current_page["id"],
         socket.assigns.current_user,
         socket.assigns.collab_space_config,
         :public,
         socket.assigns.annotations.selected_point
       )
     )
     |> assign_annotations(search_results: nil, search_term: "")}
  end

  def handle_event("reveal_post", %{"post-id" => post_id} = params, socket) do
    point_marker_id =
      case params do
        %{"point-marker-id" => point_marker_id} when point_marker_id not in [nil, ""] ->
          point_marker_id

        _ ->
          :page
      end

    {:noreply,
     socket
     |> assign_annotations(
       load_annotations(
         socket.assigns.section,
         socket.assigns.current_page["id"],
         socket.assigns.current_user,
         socket.assigns.collab_space_config,
         :public,
         point_marker_id,
         String.to_integer(post_id)
       )
     )
     |> assign_annotations(
       selected_point: point_marker_id,
       search_results: nil,
       search_term: ""
     )}
  end

  defp navigation_params(params, section_slug) do
    params
    |> Map.take(["return_to", "request_path"])
    |> case do
      %{"return_to" => return_to} = params when is_binary(return_to) ->
        case PreviewReturn.sanitize_return_to(return_to, section_slug) do
          ^return_to -> params
          _fallback -> %{}
        end

      %{"request_path" => request_path} = params when is_binary(request_path) ->
        case PreviewReturn.sanitize_return_to(request_path, section_slug) do
          ^request_path -> params
          _fallback -> %{}
        end

      _params ->
        %{}
    end
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp adaptive_redirect_params(params) do
    base =
      case params["return_to"] do
        return_to when is_binary(return_to) and return_to != "" -> [return_to: return_to]
        _ -> []
      end

    case params["request_path"] do
      request_path when is_binary(request_path) and request_path != "" ->
        base ++ [request_path: request_path]

      _ ->
        base
    end
  end

  defp preview_sidebar_state(params) do
    case Map.get(params, "sidebar_expanded") do
      "false" ->
        false

      "true" ->
        true

      _ ->
        case params["return_to"] || params["request_path"] do
          path when is_binary(path) ->
            sidebar_expanded_from_path(path)

          _ ->
            true
        end
    end
  end

  defp sidebar_expanded_from_path(path) when is_binary(path) do
    case URI.parse(path) do
      %URI{query: query} when is_binary(query) and query != "" ->
        query_params = Plug.Conn.Query.decode(query)

        case Map.get(query_params, "sidebar_expanded") do
          "false" -> false
          _ -> true
        end

      _ ->
        true
    end
  end

  defp sidebar_expanded_from_path(_), do: true

  attr :active_sidebar_panel, :atom, default: nil
  slot :inner_block, required: true

  defp page_content_with_sidebar_layout(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col w-full">
      <div class={[
        "flex-1 flex flex-col overflow-auto",
        if(@active_sidebar_panel == :notes, do: "xl:mr-[550px]"),
        if(@active_sidebar_panel == :outline, do: "xl:mr-[360px]")
      ]}>
        <div class={[
          "flex-1 mt-4 sm:mt-20 px-4 sm:px-[80px] relative",
          if(@active_sidebar_panel == :notes,
            do: "border-r border-gray-300 pr-6 mr-8 sm:mr-0 xl:mr-[80px]"
          )
        ]}>
          <div class="container mx-auto max-w-[880px] pb-20 pt-6">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp assign_preview_shell_state(socket) do
    selected_view =
      preview_selected_view(
        Map.get(socket.assigns.navigation_params, "request_path") ||
          socket.assigns.instructor_preview_return.path
      )

    socket
    |> assign(
      active_sidebar_panel:
        if(
          socket.assigns.current_user &&
            Accounts.get_user_preference(
              socket.assigns.current_user.id,
              :page_outline_panel_active?,
              false
            ),
          do: :outline,
          else: nil
        ),
      annotations: default_annotations(),
      selected_view: selected_view,
      request_path: preview_request_path(socket, selected_view)
    )
    |> then(fn socket ->
      if connected?(socket) && socket.assigns.notes_enabled? do
        assign_annotations(
          socket,
          load_annotations(
            socket.assigns.section,
            socket.assigns.current_page["id"],
            socket.assigns.current_user,
            socket.assigns.collab_space_config,
            :public,
            :page
          )
        )
      else
        socket
      end
    end)
  end

  defp default_annotations do
    %{
      point_markers: nil,
      selected_point: :page,
      post_counts: nil,
      posts: nil,
      active_tab: :class_notes,
      create_new_annotation: false,
      auto_approve_annotations: false,
      search_results: nil,
      search_term: "",
      delete_post_id: nil
    }
  end

  # The preview header exits Instructor View back to the origin workflow, but the local
  # back button should return to the nearest preview surface. When there is no explicit
  # preview request_path (for example, entry from Overview > Course Content), synthesize
  # a preview learn URL centered on the current page so the user lands back in course
  # context instead of duplicating the header's "Return to ..." action.
  defp preview_request_path(socket, selected_view) do
    %{
      current_page: current_page,
      instructor_preview_return: instructor_preview_return,
      navigation_params: navigation_params,
      section_slug: section_slug,
      sidebar_expanded: sidebar_expanded
    } = socket.assigns

    case Map.get(navigation_params, "request_path") do
      request_path when is_binary(request_path) and request_path != "" ->
        maybe_update_preview_learn_request_path(
          request_path,
          section_slug,
          current_page["id"],
          selected_view,
          sidebar_expanded,
          instructor_preview_return.path
        )

      _ ->
        case instructor_preview_return.path do
          return_path when is_binary(return_path) ->
            case URI.parse(return_path) do
              %URI{path: path} ->
                if path in [
                     "/sections/#{section_slug}/preview/learn",
                     "/sections/#{section_slug}/learn"
                   ] do
                  PreviewRoutes.update_learn_path(
                    return_path,
                    section_slug,
                    %{}
                    |> Map.put("target_resource_id", current_page["id"])
                    |> Map.put("selected_view", Atom.to_string(selected_view))
                    |> Map.put("sidebar_expanded", sidebar_expanded)
                  )
                else
                  PreviewRoutes.learn_path(
                    section_slug,
                    %{}
                    |> Map.put("target_resource_id", current_page["id"])
                    |> Map.put("selected_view", Atom.to_string(selected_view))
                    |> Map.put("sidebar_expanded", sidebar_expanded)
                    |> maybe_put_return_to(instructor_preview_return.path)
                  )
                end

              _ ->
                PreviewRoutes.learn_path(
                  section_slug,
                  %{}
                  |> Map.put("target_resource_id", current_page["id"])
                  |> Map.put("selected_view", Atom.to_string(selected_view))
                  |> Map.put("sidebar_expanded", sidebar_expanded)
                )
            end

          _ ->
            PreviewRoutes.learn_path(
              section_slug,
              %{}
              |> Map.put("target_resource_id", current_page["id"])
              |> Map.put("selected_view", Atom.to_string(selected_view))
              |> Map.put("sidebar_expanded", sidebar_expanded)
            )
        end
    end
  end

  defp maybe_update_preview_learn_request_path(
         request_path,
         section_slug,
         resource_id,
         selected_view,
         sidebar_expanded,
         return_to
       ) do
    case URI.parse(request_path) do
      %URI{path: path} ->
        if path in ["/sections/#{section_slug}/preview/learn", "/sections/#{section_slug}/learn"] do
          PreviewRoutes.update_learn_path(
            request_path,
            section_slug,
            %{}
            |> Map.put("target_resource_id", resource_id)
            |> Map.put("selected_view", Atom.to_string(selected_view))
            |> Map.put("sidebar_expanded", sidebar_expanded)
            |> maybe_put_return_to(return_to)
          )
        else
          request_path
        end

      _ ->
        request_path
    end
  end

  defp maybe_put_return_to(params, return_to) when is_binary(return_to) and return_to != "" do
    Map.put(params, "return_to", return_to)
  end

  defp maybe_put_return_to(params, _return_to), do: params

  defp load_annotations(
         section,
         resource_id,
         current_user,
         collab_space_config,
         visibility,
         point_block_id,
         load_replies_for_post_id \\ nil
       )

  defp load_annotations(
         section,
         resource_id,
         current_user,
         %CollabSpaceConfig{status: :enabled},
         visibility,
         point_block_id,
         load_replies_for_post_id
       ) do
    if current_user do
      post_counts =
        Collaboration.list_post_counts_for_user_in_section(
          section.id,
          resource_id,
          current_user.id,
          visibility
        )

      posts =
        Collaboration.list_posts_for_user_in_point_block(
          section.id,
          resource_id,
          current_user.id,
          visibility,
          point_block_id
        )

      posts =
        if load_replies_for_post_id do
          post_replies =
            Collaboration.list_replies_for_post(current_user.id, load_replies_for_post_id)

          Enum.map(posts, fn post ->
            if post.id == load_replies_for_post_id do
              %{post | replies: post_replies}
            else
              post
            end
          end)
        else
          posts
        end

      %{
        post_counts: post_counts,
        posts: posts
      }
    end
  end

  defp load_annotations(_, _, _, _, _, _, _), do: %{}

  defp search_annotations(
         section,
         resource_id,
         current_user,
         visibility,
         point_block_id,
         search_term
       ) do
    Collaboration.search_posts_for_user_in_point_block(
      section.id,
      resource_id,
      current_user.id,
      visibility,
      point_block_id,
      search_term
    )
  end

  defp assign_annotations(socket, annotations) do
    assign(socket, annotations: Enum.into(annotations, socket.assigns.annotations))
  end

  defp preview_page_href(revision_slug, section_slug, navigation_params) do
    PreviewRoutes.lesson_path(section_slug, revision_slug, navigation_params)
  end

  defp preview_selected_view(path) do
    case URI.parse(path || "") do
      %URI{query: query} ->
        case Plug.Conn.Query.decode(query || "")["selected_view"] do
          view when view in ["gallery", "outline"] -> String.to_atom(view)
          _ -> :gallery
        end

      _ ->
        :gallery
    end
  end
end
