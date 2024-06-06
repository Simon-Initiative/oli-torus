defmodule OliWeb.Delivery.Student.LessonLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils,
    only: [page_header: 1, scripts: 1]

  import Ecto.Query

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.{Sections, Settings}
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Delivery.Student.Lesson.Annotations
  alias OliWeb.Icons

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :init_context_state}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  def mount(_params, _session, %{assigns: %{view: :practice_page}} = socket) do
    %{current_user: current_user, section: section} = socket.assigns
    is_instructor = Sections.has_instructor_role?(current_user, section.slug)

    # when updating to Liveview 0.20 we should replace this with assign_async/3
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#assign_async/3
    if connected?(socket) do
      async_load_annotations(
        socket.assigns.section,
        socket.assigns.page_context.page.resource_id,
        socket.assigns.current_user,
        socket.assigns.page_context,
        if(is_instructor, do: :public, else: :private),
        nil
      )
    end

    emit_page_viewed_event(socket)

    {:ok,
     socket
     |> assign_html_and_scripts()
     |> annotations_assigns(socket.assigns.page_context, is_instructor)
     |> assign(is_instructor: is_instructor)
     |> assign_objectives()}
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: :graded_page, page_context: %{progress_state: :in_progress}}} = socket
      ) do
    emit_page_viewed_event(socket)

    {:ok,
     socket
     |> assign_html_and_scripts()
     |> assign(begin_attempt?: false)
     |> assign_objectives()}
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: :adaptive_chromeless, page_context: %{progress_state: :in_progress}}} =
          socket
      ) do
    emit_page_viewed_event(socket)

    {:ok,
     socket
     |> assign_scripts()
     |> assign(begin_attempt?: false), layout: false}
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: view}} = socket
      )
      when view in [:graded_page, :adaptive_chromeless] do
    # for graded pages with no attempt in course, we first show the prologue view (we use begin_attempt? flag to distinguish this).
    # When the student clicks "Begin" we load the needed page scripts via the "LoadSurveyScripts" hook and assign the html to the socket.
    # When the scripts end loading, we receive a "survey_scripts_loaded" confirmation event from the client
    # so we then hide the spinner and show the page content.

    {:ok,
     socket
     |> assign_scripts()
     |> assign(begin_attempt?: false)
     |> assign_objectives()}
  end

  def handle_event("begin_attempt", %{"password" => password}, socket)
      when password != socket.assigns.page_context.effective_settings.password do
    {:noreply, put_flash(socket, :error, "Incorrect password")}
  end

  def handle_event("begin_attempt", _params, socket) do
    %{
      current_user: user,
      section: section,
      page_context: %{effective_settings: effective_settings, page: revision},
      ctx: ctx
    } = socket.assigns

    case Settings.check_start_date(effective_settings) do
      {:allowed} ->
        do_start_attempt(socket, section, user, revision, effective_settings)

      {:before_start_date} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This assessment is not yet available. It will be available on #{date(effective_settings.start_date, ctx: ctx, precision: :minutes)}."
         )}
    end
  end

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, put_flash(socket, :error, "We couldn't load the page. Please try again.")}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, show_loader?: false)}
  end

  def handle_event(
        "finalize_attempt",
        _params,
        %{
          assigns: %{
            section: section,
            page_context: page_context,
            datashop_session_id: datashop_session_id,
            request_path: request_path
          }
        } = socket
      ) do
    revision_slug = page_context.page.slug
    attempt_guid = hd(page_context.resource_attempts).attempt_guid

    case PageLifecycle.finalize(section.slug, attempt_guid, datashop_session_id) do
      {:ok,
       %FinalizationSummary{
         graded: true,
         resource_access: %Oli.Delivery.Attempts.Core.ResourceAccess{id: id},
         effective_settings: effective_settings
       }} ->
        # graded resource finalization success
        section = Sections.get_section_by(slug: section.slug)

        if section.grade_passback_enabled,
          do: PageLifecycle.GradeUpdateWorker.create(section.id, id, :inline)

        redirect_to =
          case effective_settings.review_submission do
            :allow ->
              Utils.review_live_path(section.slug, revision_slug, attempt_guid,
                request_path: request_path
              )

            _ ->
              Utils.lesson_live_path(section.slug, revision_slug, request_path: request_path)
          end

        {:noreply, redirect(socket, to: redirect_to)}

      {:ok, %FinalizationSummary{graded: false}} ->
        {:noreply,
         redirect(socket,
           to: Utils.lesson_live_path(section.slug, revision_slug, request_path: request_path)
         )}

      {:error, {reason}}
      when reason in [:already_submitted, :active_attempt_present, :no_more_attempts] ->
        {:noreply, put_flash(socket, :error, "Unable to finalize page")}

      e ->
        error_msg = Kernel.inspect(e)
        Logger.error("Page finalization error encountered: #{error_msg}")
        Oli.Utils.Appsignal.capture_error(error_msg)

        {:noreply, put_flash(socket, :error, "Unable to finalize page")}
    end
  end

  def handle_event("update_point_markers", %{"point_markers" => point_markers}, socket) do
    markers = Enum.map(point_markers, fn pm -> %{id: pm["id"], top: pm["top"]} end)

    {:noreply, assign_annotations(socket, point_markers: markers)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    %{show_sidebar: show_sidebar, selected_point: selected_point} = socket.assigns.annotations

    {:noreply,
     socket
     |> assign_annotations(show_sidebar: !show_sidebar)
     |> push_event("request_point_markers", %{})
     |> then(fn socket ->
       if show_sidebar do
         push_event(socket, "clear_highlighted_point_markers", %{})
       else
         push_event(socket, "highlight_point_marker", %{id: selected_point})
       end
     end)}
  end

  def handle_event("toggle_annotation_point", params, socket) do
    %{is_instructor: is_instructor, annotations: %{selected_point: selected_point}} =
      socket.assigns

    point_marker_id =
      case params do
        %{"point-marker-id" => point_marker_id} -> point_marker_id
        _ -> :page
      end

    if selected_point == point_marker_id do
      # unselect the point marker and load all annotations
      async_load_annotations(
        socket.assigns.section,
        socket.assigns.page_context.page.resource_id,
        socket.assigns.current_user,
        socket.assigns.page_context,
        visibility_for_active_tab(socket.assigns.annotations.active_tab, is_instructor),
        nil
      )

      {:noreply,
       socket
       |> assign_annotations(selected_point: nil, posts: nil)
       |> push_event("clear_highlighted_point_markers", %{})}
    else
      # select the point marker and load annotations for that point
      async_load_annotations(
        socket.assigns.section,
        socket.assigns.page_context.page.resource_id,
        socket.assigns.current_user,
        socket.assigns.page_context,
        visibility_for_active_tab(socket.assigns.annotations.active_tab, is_instructor),
        point_marker_id
      )

      {:noreply,
       socket
       |> assign_annotations(selected_point: point_marker_id, posts: nil)
       |> push_event("highlight_point_marker", %{id: point_marker_id})}
    end
  end

  def handle_event("begin_create_annotation", _, socket) do
    {:noreply, assign_annotations(socket, create_new_annotation: true)}
  end

  def handle_event("cancel_create_annotation", _, socket) do
    {:noreply, assign_annotations(socket, create_new_annotation: false)}
  end

  def handle_event("create_annotation", %{"content" => ""}, socket) do
    {:noreply, put_flash(socket, :error, "Note cannot be empty")}
  end

  def handle_event("create_annotation", %{"content" => value} = params, socket) do
    %{
      current_user: current_user,
      is_instructor: is_instructor,
      section: section,
      page_context: page_context,
      annotations: %{
        selected_point: selected_point,
        active_tab: active_tab,
        auto_approve_annotations: auto_approve_annotations
      }
    } = socket.assigns

    # if the selected point is the page resource id, we treat it as nil
    selected_point =
      if(selected_point == :page, do: nil, else: selected_point)

    attrs = %{
      status: if(auto_approve_annotations, do: :approved, else: :submitted),
      user_id: current_user.id,
      section_id: section.id,
      resource_id: page_context.page.resource_id,
      annotated_resource_id: page_context.page.resource_id,
      annotated_block_id: selected_point,
      annotation_type: if(selected_point, do: :point, else: :none),
      anonymous: params["anonymous"] == "true",
      visibility: visibility_for_active_tab(active_tab, is_instructor),
      content: %Collaboration.PostContent{message: value}
    }

    case Collaboration.create_post(attrs) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note created successfully")
         |> optimistically_add_post(selected_point, post)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create note")}
    end
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    %{is_instructor: is_instructor} = socket.assigns

    tab =
      case tab do
        "my_notes" -> :my_notes
        "class_notes" -> :class_notes
        _ -> :my_notes
      end

    if socket.assigns.annotations.search_term not in [nil, ""] do
      %{
        current_user: current_user,
        section: section,
        page_context: %{
          page: %{resource_id: resource_id}
        },
        annotations: %{
          selected_point: selected_point,
          search_term: search_term
        }
      } = socket.assigns

      async_search_annotations(
        section,
        resource_id,
        current_user,
        visibility_for_active_tab(tab, is_instructor),
        selected_point,
        search_term
      )

      {:noreply,
       socket
       |> assign_annotations(search_results: :loading, active_tab: tab)}
    else
      async_load_annotations(
        socket.assigns.section,
        socket.assigns.page_context.page.resource_id,
        socket.assigns.current_user,
        socket.assigns.page_context,
        visibility_for_active_tab(tab, is_instructor),
        socket.assigns.annotations.selected_point
      )

      {:noreply, assign_annotations(socket, active_tab: tab, posts: nil)}
    end
  end

  def handle_event("toggle_post_replies", %{"post-id" => post_id}, socket) do
    %{current_user: current_user} = socket.assigns

    post_id = String.to_integer(post_id)
    post = get_post(socket, post_id)

    case post.replies do
      nil ->
        # load replies
        async_load_post_replies(current_user.id, post_id)

        {:noreply, update_post_replies(socket, post_id, :loading, fn _ -> :loading end)}

      _ ->
        # unload replies
        {:noreply, update_post_replies(socket, post_id, nil, fn _ -> nil end)}
    end
  end

  # handle toggle_reaction for reply posts
  def handle_event(
        "toggle_reaction",
        %{"parent-post-id" => parent_post_id, "post-id" => post_id, "reaction" => reaction},
        socket
      ) do
    %{current_user: current_user} = socket.assigns

    parent_post_id = String.to_integer(parent_post_id)
    post_id = String.to_integer(post_id)
    reaction = String.to_existing_atom(reaction)

    case Collaboration.toggle_reaction(post_id, current_user.id, reaction) do
      {:ok, change} ->
        {:noreply,
         update_post_replies(socket, parent_post_id, nil, fn replies ->
           Enum.map(
             replies,
             fn post ->
               if post.id == post_id do
                 %{
                   post
                   | reaction_summaries: update_reaction_summaries(post, reaction, change)
                 }
               else
                 post
               end
             end
           )
         end)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update reaction for post")}
    end
  end

  # handle toggle_reaction for root posts
  def handle_event(
        "toggle_reaction",
        %{"post-id" => post_id, "reaction" => reaction},
        socket
      ) do
    %{current_user: current_user, annotations: %{posts: posts}} = socket.assigns

    post_id = String.to_integer(post_id)
    reaction = String.to_existing_atom(reaction)

    case Collaboration.toggle_reaction(post_id, current_user.id, reaction) do
      {:ok, change} ->
        {:noreply,
         assign_annotations(socket,
           posts:
             Enum.map(
               posts,
               fn post ->
                 if post.id == post_id do
                   %{
                     post
                     | reaction_summaries: update_reaction_summaries(post, reaction, change)
                   }
                 else
                   post
                 end
               end
             )
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update reaction for post")}
    end
  end

  def handle_event("create_reply", %{"content" => ""}, socket) do
    {:noreply, put_flash(socket, :error, "Reply cannot be empty")}
  end

  def handle_event(
        "create_reply",
        %{"parent-post-id" => parent_post_id, "content" => value} = params,
        socket
      ) do
    parent_post_id = String.to_integer(parent_post_id)

    %{
      current_user: current_user,
      is_instructor: is_instructor,
      section: section,
      page_context: page_context,
      annotations: %{
        selected_point: selected_point,
        active_tab: active_tab,
        auto_approve_annotations: auto_approve_annotations
      }
    } = socket.assigns

    # if the selected point is the page, we treat it as nil
    selected_point =
      if(selected_point == :page, do: nil, else: selected_point)

    attrs = %{
      status: if(auto_approve_annotations, do: :approved, else: :submitted),
      user_id: current_user.id,
      section_id: section.id,
      resource_id: page_context.page.resource_id,
      annotated_resource_id: page_context.page.resource_id,
      annotated_block_id: selected_point,
      annotation_type: if(selected_point, do: :point, else: :none),
      anonymous: params["anonymous"] == "true",
      visibility: visibility_for_active_tab(active_tab, is_instructor),
      content: %Collaboration.PostContent{message: value},
      parent_post_id: parent_post_id,
      thread_root_id: parent_post_id
    }

    case Collaboration.create_post(attrs) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reply successfully created")
         |> optimistically_add_reply_post(
           %Collaboration.Post{post | reaction_summaries: %{}},
           parent_post_id
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create reply")}
    end
  end

  def handle_event("search", %{"search_term" => ""}, socket) do
    {:noreply, assign_annotations(socket, search_results: nil, search_term: "")}
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    %{
      current_user: current_user,
      is_instructor: is_instructor,
      section: section,
      page_context: %{
        page: %{resource_id: resource_id}
      },
      annotations: %{
        selected_point: selected_point,
        active_tab: active_tab
      }
    } = socket.assigns

    async_search_annotations(
      section,
      resource_id,
      current_user,
      visibility_for_active_tab(active_tab, is_instructor),
      selected_point,
      search_term
    )

    {:noreply, assign_annotations(socket, search_results: :loading, search_term: search_term)}
  end

  def handle_event("clear_search", _, socket) do
    {:noreply, assign_annotations(socket, search_results: nil, search_term: "")}
  end

  def handle_event(
        "reveal_post",
        %{"post-id" => post_id} = params,
        socket
      ) do
    %{
      section: section,
      page_context: page_context,
      current_user: current_user,
      is_instructor: is_instructor,
      annotations: %{
        active_tab: active_tab
      }
    } = socket.assigns

    point_marker_id =
      case params do
        %{"point-marker-id" => point_marker_id} -> point_marker_id
        _ -> :page
      end

    async_load_annotations(
      section,
      page_context.page.resource_id,
      current_user,
      page_context,
      visibility_for_active_tab(active_tab, is_instructor),
      point_marker_id,
      String.to_integer(post_id)
    )

    {:noreply,
     assign_annotations(socket,
       selected_point: point_marker_id,
       search_results: nil,
       search_term: ""
     )}
  end

  def handle_event(
        "set_delete_post_id",
        %{"post-id" => post_id, "visibility" => visibility},
        socket
      ) do
    {:noreply,
     assign_annotations(socket,
       delete_post_id: {String.to_existing_atom(visibility), String.to_integer(post_id)}
     )}
  end

  def handle_event("delete_post", _params, socket) do
    %{annotations: %{delete_post_id: {_visibility, post_id}}} = socket.assigns

    case Collaboration.soft_delete_post(post_id) do
      {1, _} ->
        {:noreply, mark_post_deleted(socket, post_id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete note")}
    end
  end

  # handle assigns directly from async tasks
  def handle_info({ref, result}, socket) do
    Process.demonitor(ref, [:flush])

    case result do
      {:assign_annotations, annotations} ->
        {:noreply, assign_annotations(socket, annotations)}

      {:assign_post_replies, {parent_post_id, replies}} ->
        {:noreply, update_post_replies(socket, parent_post_id, replies, fn _ -> replies end)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load annotations")}

      _ ->
        {:noreply, socket}
    end
  end

  def render(%{view: :practice_page, annotations: %{}} = assigns) do
    # For practice page the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <Annotations.delete_post_modal />

    <.page_content_with_sidebar_layout show_sidebar={@annotations.show_sidebar}>
      <:header>
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          index={@current_page["index"]}
          objectives={@objectives}
          container_label={Utils.get_container_label(@current_page["id"], @section)}
        />
      </:header>

      <div
        id="eventIntercept"
        class="content"
        phx-update="ignore"
        role="page content"
        phx-hook="PointMarkers"
      >
        <%= raw(@html) %>
      </div>

      <:point_markers :if={@annotations.show_sidebar && @annotations.point_markers}>
        <Annotations.annotation_bubble
          point_marker={:page}
          selected={@annotations.selected_point == :page}
          count={@annotations.post_counts && @annotations.post_counts[nil]}
        />
        <Annotations.annotation_bubble
          :for={point_marker <- @annotations.point_markers}
          point_marker={point_marker}
          selected={@annotations.selected_point == point_marker.id}
          count={@annotations.post_counts && @annotations.post_counts[point_marker.id]}
        />
      </:point_markers>

      <:sidebar_toggle>
        <Annotations.toggle_notes_button>
          <Annotations.annotations_icon />
        </Annotations.toggle_notes_button>
      </:sidebar_toggle>

      <:sidebar>
        <Annotations.panel
          section_slug={@section.slug}
          create_new_annotation={@annotations.create_new_annotation}
          annotations={@annotations.posts}
          current_user={@current_user}
          is_instructor={@is_instructor}
          active_tab={@annotations.active_tab}
          search_results={@annotations.search_results}
          search_term={@annotations.search_term}
          selected_point={@annotations.selected_point}
        />
      </:sidebar>
    </.page_content_with_sidebar_layout>

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  def render(%{view: :practice_page} = assigns) do
    # For practice page the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <div class="flex-1 flex flex-col w-full overflow-auto">
      <div class="flex-1 mt-20 px-[80px] relative">
        <div class="container mx-auto max-w-[880px] pb-20">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            objectives={@objectives}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />

          <div id="eventIntercept" class="content" phx-update="ignore" role="page content">
            <%= raw(@html) %>
          </div>
        </div>
      </div>
    </div>

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  def render(
        %{
          view: :graded_page,
          page_context: %{progress_state: :in_progress},
          begin_attempt?: false
        } = assigns
      ) do
    # For graded page with attempt in progress the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner />
        <div class="flex-1 max-w-[720px] pt-20 pb-10 mx-6 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            objectives={@objectives}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />
          <div id="eventIntercept" class="content" phx-update="ignore" role="page content">
            <%= raw(@html) %>
            <div class="flex w-full justify-center">
              <button
                id="submit_answers"
                phx-click="finalize_attempt"
                class="cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight"
              >
                Submit Answers
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  def render(
        %{view: :adaptive_chromeless, page_context: %{progress_state: :in_progress}} = assigns
      ) do
    ~H"""
    <!-- ACTIVITIES -->
    <%= for %{slug: slug, authoring_script: script} <- @activity_types do %>
      <script
        :if={slug == "oli_adaptive"}
        type="text/javascript"
        src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
      >
      </script>
    <% end %>
    <!-- PARTS -->
    <script
      :for={script <- @part_scripts}
      type="text/javascript"
      src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
    >
    </script>

    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/delivery.js")}>
    </script>

    <div id="delivery_container" phx-update="ignore">
      <%= react_component("Components.Delivery", @app_params) %>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    """
  end

  def render(%{view: :graded_page, begin_attempt?: true} = assigns) do
    # For graded page with no started attempts, the js scripts are needed after the user clicks "Begin",
    # so we load them with the hook "load_survey_scripts" in the click handle_event functions.
    ~H"""
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner />
        <div class="flex-1 max-w-[720px] pt-20 pb-10 mx-6 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            objectives={@objectives}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />
          <div id="page_content" phx-hook="LoadSurveyScripts">
            <div
              :if={@show_loader?}
              phx-remove={
                JS.remove_class("opacity-0",
                  to: "#raw_html",
                  transition: {"ease-out duration-1000", "opacity-0", "opacity-100"}
                )
              }
              class="w-full flex justify-center items-center"
            >
              <Layouts.spinner />
            </div>
            <div
              :if={!@show_loader?}
              id="raw_html"
              class="content opacity-0"
              phx-update="ignore"
              role="page content"
            >
              <%= raw(@html) %>
              <div class="flex w-full justify-center">
                <button
                  id="submit_answers"
                  phx-click="finalize_attempt"
                  class="cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight"
                >
                  Submit Answers
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    """
  end

  # this render corresponds to the prologue view for graded pages (when there is no attempt in course)
  # TODO: extend the prologue page to support adaptive pages
  def render(%{view: view, begin_attempt?: false} = assigns)
      when view in [:graded_page, :adaptive_chromeless] do
    ~H"""
    <.password_attempt_modal />

    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex-1 max-w-[720px] pt-20 pb-10 mx-6 flex-col justify-start items-center inline-flex">
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          objectives={@objectives}
          index={@current_page["index"]}
          container_label={Utils.get_container_label(@current_page["id"], @section)}
        />
        <div class="self-stretch h-[0px] opacity-80 dark:opacity-20 bg-white border border-gray-200 mb-10">
        </div>
        <.attempts_summary
          page_context={@page_context}
          attempt_message={@attempt_message}
          ctx={@ctx}
          allow_attempt?={@allow_attempt?}
          section_slug={@section.slug}
          request_path={@request_path}
          adaptive_chromeless?={@view == :adaptive_chromeless}
        />
      </div>
    </div>
    """
  end

  defp password_attempt_modal(assigns) do
    ~H"""
    <Modal.modal id="password_attempt_modal" class="w-1/2">
      <:title>Provide Assessment Password</:title>
      <.form
        phx-submit={JS.push("begin_attempt") |> Modal.hide_modal("password_attempt_modal")}
        for={%{}}
        class="flex flex-col gap-6"
        id="password_attempt_form"
      >
        <input id="password_attempt_input" type="password" name="password" field={:password} value="" />
        <.button type="submit" class="mx-auto btn btn-primary">Begin</.button>
      </.form>
    </Modal.modal>
    """
  end

  attr :show_sidebar, :boolean, default: false
  slot :header, required: true
  slot :inner_block, required: true
  slot :sidebar, default: nil
  slot :sidebar_toggle, default: nil
  slot :point_markers, default: nil

  defp page_content_with_sidebar_layout(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col w-full overflow-hidden">
      <div class={[
        "flex-1 flex flex-col overflow-auto",
        if(@show_sidebar, do: "xl:mr-[520px]")
      ]}>
        <div class={[
          "flex-1 mt-20 px-[80px] relative",
          if(@show_sidebar, do: "border-r border-gray-300 xl:mr-[80px]")
        ]}>
          <div class="container mx-auto max-w-[880px] pb-20">
            <%= render_slot(@header) %>

            <%= render_slot(@inner_block) %>
          </div>

          <%= render_slot(@point_markers) %>
        </div>
      </div>
    </div>
    <div
      :if={@sidebar && @show_sidebar}
      class="flex flex-col w-[520px] absolute top-20 right-0 bottom-0"
    >
      <%= render_slot(@sidebar) %>
    </div>
    <div :if={@sidebar && !@show_sidebar} class="absolute top-20 right-0">
      <%= render_slot(@sidebar_toggle) %>
    </div>
    """
  end

  attr :attempt_message, :string
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :allow_attempt?, :boolean
  attr :adaptive_chromeless?, :boolean
  attr :section_slug, :string
  attr :request_path, :string

  defp attempts_summary(assigns) do
    ~H"""
    <div class="w-full flex-col justify-start items-start gap-3 flex" id="attempts_summary">
      <div class="self-stretch justify-start items-start gap-6 inline-flex relative">
        <div
          id="attempts_summary_with_tooltip"
          phx-hook="TooltipWithTarget"
          data-tooltip-target-id="attempt_tooltip"
          class="opacity-80 cursor-help dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider"
        >
          Attempts <%= get_attempts_count(@page_context) %>/<%= get_max_attempts(@page_context) %>
        </div>
        <div
          id="attempt_tooltip"
          class="absolute hidden left-32 -top-2 text-xs bg-white py-2 px-4 text-black rounded-lg shadow-lg"
        >
          <%= @attempt_message %>
        </div>
      </div>
      <div class="self-stretch flex-col justify-start items-start flex">
        <.attempt_summary
          :for={
            {attempt, index} <-
              Enum.filter(@page_context.historical_attempts, fn a -> a.revision.graded == true end)
              |> Enum.with_index(1)
          }
          index={index}
          section_slug={@section_slug}
          page_revision_slug={@page_context.page.slug}
          attempt={attempt}
          ctx={@ctx}
          allow_review_submission?={@page_context.effective_settings.review_submission == :allow}
          request_path={@request_path}
          adaptive_chromeless?={@adaptive_chromeless?}
        />
      </div>
    </div>
    <button
      :if={@page_context.progress_state == :not_started}
      id="begin_attempt_button"
      disabled={!@allow_attempt?}
      phx-click={
        if(@page_context.effective_settings.password not in [nil, ""],
          do: Modal.show_modal("password_attempt_modal") |> JS.focus(to: "#password_attempt_input"),
          else: "begin_attempt"
        )
      }
      class={[
        "mb-24 cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight",
        if(!@allow_attempt?, do: "opacity-50 dark:opacity-20 disabled !cursor-not-allowed")
      ]}
    >
      Begin <%= get_ordinal_attempt(@page_context) %> Attempt
    </button>
    """
  end

  attr :index, :integer
  attr :attempt, ResourceAttempt
  attr :ctx, OliWeb.Common.SessionContext
  attr :allow_review_submission?, :boolean
  attr :section_slug, :string
  attr :page_revision_slug, :string
  attr :adaptive_chromeless?, :boolean
  attr :request_path, :string

  defp attempt_summary(assigns) do
    ~H"""
    <div
      id={"attempt_#{@index}_summary"}
      class="self-stretch py-1 justify-between items-start inline-flex"
    >
      <div class="justify-start items-center flex">
        <div class="w-[92px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] uppercase leading-normal tracking-wide">
          Attempt <%= @index %>:
        </div>
        <div class="py-1 justify-end items-center gap-1.5 flex text-green-700 dark:text-green-500">
          <div class="w-4 h-4 relative"><Icons.star /></div>
          <div class="justify-end items-center gap-1 flex">
            <div role="attempt score" class="text-xs font-semibold tracking-tight">
              <%= Float.round(@attempt.score, 2) %>
            </div>
            <div class="text-xs font-semibold tracking-[4px]">
              /
            </div>
            <div role="attempt out of" lass="text-xs font-semibold tracking-tight">
              <%= Float.round(@attempt.out_of, 2) %>
            </div>
          </div>
        </div>
      </div>
      <div class="flex-col justify-start items-end inline-flex" role="attempt submission">
        <div class="py-1 justify-start items-start gap-1 inline-flex">
          <div class="opacity-50 dark:text-white text-xs font-normal font-['Open Sans']">
            Submitted:
          </div>
          <div class="dark:text-white text-xs font-normal font-['Open Sans']">
            <%= FormatDateTime.to_formatted_datetime(
              @attempt.date_submitted,
              @ctx,
              "{WDshort} {Mshort} {D}, {YYYY}"
            ) %>
          </div>
        </div>
        <div
          :if={@allow_review_submission?}
          class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex"
        >
          <.link
            href={
              Utils.review_live_path(
                @section_slug,
                @page_revision_slug,
                @attempt.attempt_guid,
                request_path: @request_path
              )
            }
            role="review_attempt_link"
          >
            <div class="cursor-pointer hover:opacity-40 text-blue-500 text-xs font-semibold font-['Open Sans'] uppercase tracking-wide">
              Review
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def scored_page_banner(assigns) do
    ~H"""
    <div class="w-full lg:px-20 px-40 py-9 bg-orange-500 bg-opacity-10 flex flex-col justify-center items-center gap-2.5">
      <div class="px-3 py-1.5 rounded justify-start items-start gap-2.5 flex">
        <div class="dark:text-white text-sm font-bold uppercase tracking-wider">
          Scored Activity
        </div>
      </div>
      <div class="max-w-[720px] w-full mx-auto opacity-90 dark:text-white text-sm font-normal leading-6">
        You can start or stop at any time, and your progress will be saved. When you submit your answers using the Submit button, it will count as an attempt. So make sure you have answered all the questions before submitting.
      </div>
    </div>
    """
  end

  def do_start_attempt(socket, section, user, revision, effective_settings) do
    datashop_session_id = socket.assigns.datashop_session_id
    activity_provider = &Oli.Delivery.ActivityProvider.provide/6

    # We must check gating conditions here to account for gates that activated after
    # the prologue page was rendered, and for malicious/deliberate attempts to start an attempt via
    # hitting this endpoint.
    with :ok <- check_gating_conditions(section, user, revision.resource_id),
         {:ok, _attempt_state} <-
           PageLifecycle.start(
             revision.slug,
             section.slug,
             datashop_session_id,
             user,
             effective_settings,
             activity_provider
           ),
         :ok <- maybe_redirect_adaptive(socket.assigns.view, section.slug, revision.slug) do
      page_context =
        PageContext.create_for_visit(
          section,
          socket.assigns.page_context.page.slug,
          socket.assigns.current_user,
          socket.assigns.datashop_session_id
        )

      {:noreply,
       socket
       |> assign(page_context: page_context)
       |> assign(begin_attempt?: true, show_loader?: true)
       |> clear_flash()
       |> assign_html()
       |> load_scripts_on_client_side()
       |> emit_page_viewed_event()}
    else
      {:redirect, to} ->
        {:noreply, redirect(socket, to: to)}

      {:error, {:gates, _}} ->
        # In the case where a gate exists we want to redirect to this page display, which will
        # then pick up the gate and show that feedback to the user
        {:noreply,
         redirect(socket,
           to: Routes.page_delivery_path(socket, :page, section.slug, revision.slug)
         )}

      {:error, {:end_date_passed}} ->
        {:noreply, put_flash(socket, :error, "This assessment's end date passed.")}

      {:error, {:active_attempt_present}} ->
        {:noreply, put_flash(socket, :error, "You already have an active attempt.")}

      {:error, {:no_more_attempts}} ->
        {:noreply, put_flash(socket, :error, "You have no attempts remaining.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to start new attempt")}
    end
  end

  defp assign_html_and_scripts(socket) do
    socket
    |> assign_scripts()
    |> assign_html()
  end

  defp assign_scripts(socket) do
    assign(socket,
      scripts: Utils.get_required_activity_scripts(socket.assigns.page_context)
    )
  end

  defp assign_html(socket) do
    assign(socket,
      html: Utils.build_html(socket.assigns, :delivery)
    )
  end

  defp assign_objectives(socket) do
    %{page_context: %{page: page}, current_user: current_user, section: section} =
      socket.assigns

    objectives =
      case page.objectives["attached"] do
        objective_ids when objective_ids in [nil, []] ->
          []

        objective_resource_ids ->
          student_proficiency_per_learning_objective =
            Metrics.proficiency_for_student_per_learning_objective(
              section,
              current_user.id
            )

          Resources.get_revisions_by_resource_id(objective_resource_ids)
          |> Enum.map(fn rev ->
            %{
              resource_id: rev.resource_id,
              title: rev.title,
              proficiency:
                Map.get(
                  student_proficiency_per_learning_objective,
                  rev.resource_id,
                  "Not enough data"
                )
            }
          end)
      end

    assign(socket, objectives: objectives)
  end

  defp get_max_attempts(%{effective_settings: %{max_attempts: 0}} = _page_context),
    do: "unlimited"

  defp get_max_attempts(%{effective_settings: %{max_attempts: max_attempts}} = _page_context),
    do: max_attempts

  defp get_attempts_count(%{historical_attempts: resource_attempts} = _page_context) do
    Enum.count(resource_attempts, fn a -> a.revision.graded == true end)
  end

  defp get_ordinal_attempt(page_context) do
    next_attempt_number = get_attempts_count(page_context) + 1

    case {rem(next_attempt_number, 10), rem(next_attempt_number, 100)} do
      {1, _} -> Integer.to_string(next_attempt_number) <> "st"
      {2, _} -> Integer.to_string(next_attempt_number) <> "nd"
      {3, _} -> Integer.to_string(next_attempt_number) <> "rd"
      {_, 11} -> Integer.to_string(next_attempt_number) <> "th"
      {_, 12} -> Integer.to_string(next_attempt_number) <> "th"
      {_, 13} -> Integer.to_string(next_attempt_number) <> "th"
      _ -> Integer.to_string(next_attempt_number) <> "th"
    end
  end

  defp load_scripts_on_client_side(socket) do
    push_event(socket, "load_survey_scripts", %{
      script_sources: Enum.map(socket.assigns.scripts, fn script -> "/js/#{script}" end)
    })
  end

  defp get_post(socket, post_id) do
    Enum.find(socket.assigns.annotations.posts, fn post -> post.id == post_id end)
  end

  defp update_post_replies(socket, post_id, default, updater) do
    %{posts: posts} = socket.assigns.annotations

    socket
    |> assign_annotations(
      posts:
        Enum.map(posts, fn post ->
          if post.id == post_id do
            Map.update(post, :replies, default, updater)
          else
            post
          end
        end)
    )
  end

  defp annotations_assigns(socket, page_context, is_instructor) do
    case page_context do
      %PageContext{
        collab_space_config: %CollabSpaceConfig{status: :enabled, auto_accept: auto_accept}
      } ->
        assign(socket,
          annotations: %{
            show_sidebar: false,
            point_markers: nil,
            selected_point: nil,
            post_counts: nil,
            posts: nil,
            active_tab: if(is_instructor, do: :class_notes, else: :my_notes),
            create_new_annotation: false,
            auto_approve_annotations: auto_accept,
            search_results: nil,
            search_term: "",
            delete_post_id: nil
          }
        )

      _ ->
        assign(socket, annotations: nil)
    end
  end

  defp async_load_annotations(
         section,
         resource_id,
         current_user,
         page_context,
         visibility,
         point_block_id,
         load_replies_for_post_id \\ nil
       ) do
    if current_user do
      Task.async(fn ->
        case page_context do
          %PageContext{
            collab_space_config: %CollabSpaceConfig{status: :enabled, auto_accept: auto_accept}
          } ->
            # load post counts
            post_counts =
              Collaboration.list_post_counts_for_user_in_section(
                section.id,
                resource_id,
                current_user.id,
                visibility
              )

            # load posts
            posts =
              Collaboration.list_posts_for_user_in_point_block(
                section.id,
                resource_id,
                current_user.id,
                visibility,
                point_block_id
              )

            # load_replies_for_post_id is an option that allows a specific post to be loaded with
            # its replies, used for when a user click "View Original Post" in the search results
            posts =
              if load_replies_for_post_id do
                post_replies =
                  Collaboration.list_replies_for_post(
                    current_user.id,
                    load_replies_for_post_id
                  )

                Enum.map(posts, fn post ->
                  if post.id == load_replies_for_post_id do
                    %Collaboration.Post{post | replies: post_replies}
                  else
                    post
                  end
                end)
              else
                posts
              end

            {:assign_annotations,
             %{
               post_counts: post_counts,
               posts: posts,
               auto_approve_annotations: auto_accept
             }}

          _ ->
            # do nothing
            nil
        end
      end)
    end
  end

  defp async_load_post_replies(user_id, post_id) do
    Task.async(fn ->
      post_replies = Collaboration.list_replies_for_post(user_id, post_id)

      {:assign_post_replies, {post_id, post_replies}}
    end)
  end

  defp async_search_annotations(
         section,
         resource_id,
         current_user,
         visibility,
         point_block_id,
         search_term
       ) do
    Task.async(fn ->
      search_results =
        Collaboration.search_posts_for_user_in_point_block(
          section.id,
          resource_id,
          current_user.id,
          visibility,
          point_block_id,
          search_term
        )

      {:assign_annotations, %{search_results: search_results}}
    end)
  end

  defp assign_annotations(socket, annotations) do
    assign(socket, annotations: Enum.into(annotations, socket.assigns.annotations))
  end

  defp visibility_for_active_tab(_, true), do: :public
  defp visibility_for_active_tab(:class_notes, _is_instructor), do: :public
  defp visibility_for_active_tab(:my_notes, _is_instructor), do: :private
  defp visibility_for_active_tab(_, _is_instructor), do: :private

  defp optimistically_add_post(socket, selected_point, post) do
    %{posts: posts, post_counts: post_counts} = socket.assigns.annotations

    socket
    |> assign_annotations(
      posts: [%Collaboration.Post{post | replies_count: 0, reaction_summaries: %{}} | posts],
      post_counts: Map.update(post_counts, selected_point, 1, &(&1 + 1)),
      create_new_annotation: false
    )
  end

  defp optimistically_add_reply_post(socket, reply_post, parent_post_id) do
    %{posts: posts} = socket.assigns.annotations

    socket
    |> assign_annotations(
      posts:
        Annotations.find_and_update_post(posts, parent_post_id, fn post ->
          if post.id == parent_post_id do
            %Collaboration.Post{
              post
              | replies_count: post.replies_count + 1,
                replies:
                  case post.replies do
                    nil -> [reply_post]
                    replies -> replies ++ [reply_post]
                  end
            }
          else
            post
          end
        end)
    )
  end

  def update_reaction_summaries(post, reaction, change) do
    Map.update(
      post.reaction_summaries,
      reaction,
      %{count: 1, reacted: true},
      &%{
        count: &1.count + change,
        reacted: if(change > 0, do: true, else: false)
      }
    )
  end

  defp mark_post_deleted(socket, post_id) do
    %{posts: posts} = socket.assigns.annotations

    socket
    |> assign_annotations(
      posts:
        Annotations.find_and_update_post(posts, post_id, fn post ->
          %Collaboration.Post{post | status: :deleted}
        end)
    )
  end

  defp check_gating_conditions(section, user, resource_id) do
    case Oli.Delivery.Gating.blocked_by(section, user, resource_id) do
      [] -> :ok
      gates -> {:error, {:gates, gates}}
    end
  end

  defp maybe_redirect_adaptive(:adaptive_chromeless, section_slug, revision_slug),
    do: {:redirect, ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}"}

  defp maybe_redirect_adaptive(_, _, _), do: :ok

  defp emit_page_viewed_event(socket) do
    section = socket.assigns.section
    context = socket.assigns.page_context

    page_sub_type =
      if Map.get(context.page.content, "advancedDelivery", false) do
        "advanced"
      else
        "basic"
      end

    {project_id, publication_id} = get_project_and_publication_ids(section.id, context.page.id)

    emit_page_viewed_helper(
      %Oli.Analytics.XAPI.Events.Context{
        user_id: socket.assigns.current_user.id,
        host_name: host_name(),
        section_id: section.id,
        project_id: project_id,
        publication_id: publication_id
      },
      %{
        attempt_guid: List.first(context.resource_attempts).attempt_guid,
        attempt_number: List.first(context.resource_attempts).attempt_number,
        resource_id: context.page.resource_id,
        timestamp: DateTime.utc_now(),
        page_sub_type: page_sub_type
      }
    )

    socket
  end

  defp emit_page_viewed_helper(
         %Oli.Analytics.XAPI.Events.Context{} = context,
         %{
           attempt_guid: _page_attempt_guid,
           attempt_number: _page_attempt_number,
           resource_id: _page_id,
           timestamp: _timestamp,
           page_sub_type: _page_sub_type
         } = page_details
       ) do
    event = Oli.Analytics.XAPI.Events.Attempt.PageViewed.new(context, page_details)
    Oli.Analytics.XAPI.emit(:page_viewed, event)
  end

  defp get_project_and_publication_ids(section_id, revision_id) do
    # From the SectionProjectPublication table, get the project_id and publication_id
    # where a published resource exists for revision_id
    # and the section_id matches the section_id

    query =
      from sp in Oli.Delivery.Sections.SectionsProjectsPublications,
        join: pr in Oli.Publishing.PublishedResource,
        on: pr.publication_id == sp.publication_id,
        where: sp.section_id == ^section_id and pr.revision_id == ^revision_id,
        select: {sp.project_id, sp.publication_id}

    # Return nil if somehow we cannot resolve this resource.  This is just a guaranteed that
    # we can never throw an error here
    case Oli.Repo.all(query) do
      [] -> {nil, nil}
      other -> hd(other)
    end
  end

  defp host_name() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end
end
