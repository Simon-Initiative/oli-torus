defmodule OliWeb.Delivery.Student.LessonLive do
  use OliWeb, :live_view
  use Appsignal.Instrumentation.Decorators

  import OliWeb.Delivery.Student.Utils,
    only: [
      page_header: 1,
      references: 1,
      reset_attempts_button: 1,
      emit_page_viewed_event: 1
    ]

  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Delivery.Student.Lesson.Annotations

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :init_context_state}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[:id, :slug, :title, :brand, :lti_1p3_deployment, :customizations], %Sections.Section{}},
    current_user: {[:id, :name, :email], %User{}}
  }

  @decorate transaction_event()
  def mount(_params, _session, %{assigns: %{view: :practice_page}} = socket) do
    # when updating to Liveview 0.20 we should replace this with assign_async/3
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#assign_async/3
    if connected?(socket) do
      %{current_user: current_user, section: section, page_context: page_context} = socket.assigns
      is_instructor = Sections.has_instructor_role?(current_user, section.slug)

      async_load_annotations(
        section,
        page_context.page.resource_id,
        current_user,
        page_context.collab_space_config,
        if(is_instructor, do: :public, else: :private),
        nil
      )

      send(self(), :gc)

      socket =
        socket
        |> emit_page_viewed_event()
        |> assign_html_and_scripts()
        |> annotations_assigns(page_context.collab_space_config, is_instructor)
        |> assign(is_instructor: is_instructor, page_resource_id: page_context.page.resource_id)
        |> assign_objectives()
        |> slim_assigns()

      script_sources =
        Enum.map(socket.assigns.scripts, fn script -> "/js/#{script}" end)

      {:ok, push_event(socket, "load_survey_scripts", %{script_sources: script_sources})}
      # These temp assigns were disabled in MER-3672
      #  temporary_assigns: [scripts: [], html: [], page_context: %{}]}
    else
      {:ok, socket}
    end
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: :graded_page}} =
          socket
      ) do
    %{page_context: page_context} = socket.assigns

    if connected?(socket) do
      send(self(), :gc)
      resource_attempt = hd(page_context.resource_attempts)

      effective_end_time =
        Settings.determine_effective_deadline(resource_attempt, page_context.effective_settings)
        |> to_epoch()

      socket =
        socket
        |> emit_page_viewed_event()
        |> assign_html_and_scripts()
        |> assign_objectives()
        |> maybe_assign_questions(page_context.effective_settings.assessment_mode)
        |> assign(
          revision_slug: page_context.page.slug,
          attempt_guid: hd(page_context.resource_attempts).attempt_guid,
          effective_end_time: effective_end_time,
          auto_submit: page_context.effective_settings.late_submit == :disallow,
          time_limit: page_context.effective_settings.time_limit,
          grace_period: page_context.effective_settings.grace_period,
          attempt_start_time: resource_attempt.inserted_at |> to_epoch,
          review_mode: page_context.review_mode
        )
        |> slim_assigns()

      script_sources =
        Enum.map(socket.assigns.scripts, fn script -> "/js/#{script}" end)

      {:ok,
       push_event(socket, "load_survey_scripts", %{
         script_sources: script_sources
       })}

      # These temp assigns were disabled in MER-3672
      #  , temporary_assigns: [scripts: [], html: [], page_context: %{}]}
    else
      {:ok, socket}
    end
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: :adaptive_chromeless}} =
          socket
      ) do
    if connected?(socket) do
      send(self(), :gc)

      socket =
        socket
        |> emit_page_viewed_event()
        |> assign_scripts()
        |> slim_assigns()

      authoring_scripts =
        Enum.map(socket.assigns.activity_types, fn at -> at.authoring_script end)

      script_sources =
        Enum.map(
          socket.assigns.scripts ++
            socket.assigns.part_scripts ++ ["delivery.js"] ++ authoring_scripts,
          fn script ->
            "/js/#{script}"
          end
        )

      {:ok, push_event(socket, "load_survey_scripts", %{script_sources: script_sources}),
       layout: false}

      # These temp assigns were disabled in MER-3672
      #  , temporary_assigns: [scripts: [], page_context: %{}]}
    else
      {:ok, socket}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, scripts_loaded: true)}
  end

  def handle_event("select_question", %{"id" => selected_id}, socket) do
    questions =
      socket.assigns.questions
      |> Enum.into(%{}, fn {id, question} ->
        {id, Map.put(question, :selected, id == selected_id)}
      end)

    {:noreply, assign(socket, questions: questions)}
  end

  def handle_event(
        "finalize_attempt",
        _params,
        %{
          assigns: %{
            section: section,
            datashop_session_id: datashop_session_id,
            request_path: request_path,
            revision_slug: revision_slug,
            attempt_guid: attempt_guid
          }
        } = socket
      ) do
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
    %{
      is_instructor: is_instructor,
      annotations: %{selected_point: selected_point},
      page_resource_id: page_resource_id,
      collab_space_config: collab_space_config
    } =
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
        page_resource_id,
        socket.assigns.current_user,
        collab_space_config,
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
        page_resource_id,
        socket.assigns.current_user,
        collab_space_config,
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
      page_resource_id: page_resource_id,
      collab_space_config: collab_space_config,
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
      resource_id: page_resource_id,
      annotated_resource_id: page_resource_id,
      annotated_block_id: selected_point,
      annotation_type: if(selected_point, do: :point, else: :none),
      anonymous: collab_space_config.anonymous_posting && params["anonymous"] == "true",
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
        page_resource_id: page_resource_id,
        annotations: %{
          selected_point: selected_point,
          search_term: search_term
        }
      } = socket.assigns

      async_search_annotations(
        section,
        page_resource_id,
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
        socket.assigns.page_resource_id,
        socket.assigns.current_user,
        socket.assigns.collab_space_config,
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
      page_resource_id: page_resource_id,
      collab_space_config: collab_space_config,
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
      resource_id: page_resource_id,
      annotated_resource_id: page_resource_id,
      annotated_block_id: selected_point,
      annotation_type: if(selected_point, do: :point, else: :none),
      anonymous: collab_space_config.anonymous_posting && params["anonymous"] == "true",
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
      page_resource_id: page_resource_id,
      annotations: %{
        selected_point: selected_point,
        active_tab: active_tab
      }
    } = socket.assigns

    async_search_annotations(
      section,
      page_resource_id,
      current_user,
      visibility_for_active_tab(active_tab, is_instructor),
      selected_point,
      search_term
    )

    {:noreply, assign_annotations(socket, search_results: :loading, search_term: search_term)}
  end

  def handle_event("clear_search", _, socket) do
    async_load_annotations(
      socket.assigns.section,
      socket.assigns.page_resource_id,
      socket.assigns.current_user,
      socket.assigns.collab_space_config,
      visibility_for_active_tab(
        socket.assigns.annotations.active_tab,
        socket.assigns.is_instructor
      ),
      socket.assigns.annotations.selected_point
    )

    {:noreply, assign_annotations(socket, search_results: nil, posts: nil, search_term: "")}
  end

  def handle_event(
        "reveal_post",
        %{"post-id" => post_id} = params,
        socket
      ) do
    %{
      section: section,
      page_resource_id: page_resource_id,
      current_user: current_user,
      is_instructor: is_instructor,
      annotations: %{
        active_tab: active_tab
      },
      collab_space_config: collab_space_config
    } = socket.assigns

    point_marker_id =
      case params do
        %{"point-marker-id" => point_marker_id} -> point_marker_id
        _ -> :page
      end

    async_load_annotations(
      section,
      page_resource_id,
      current_user,
      collab_space_config,
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

  def handle_info(:gc, socket) do
    :erlang.garbage_collect(socket.transport_pid)
    :erlang.garbage_collect(self())
    {:noreply, socket}
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
        id="page_content"
        class="content"
        phx-update="ignore"
        role="page content"
        phx-hook="PointMarkers"
      >
        <%= raw(@html) %>
        <div class="flex w-full justify-center">
          <.reset_attempts_button
            activity_count={@activity_count}
            advanced_delivery={@advanced_delivery}
            page_context={@page_context}
            section_slug={@section.slug}
          />
        </div>
        <.references ctx={@ctx} bib_app_params={@bib_app_params} />
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
          collab_space_config={@collab_space_config}
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

          <div id="page_content" class="content" phx-update="ignore" role="page content">
            <%= raw(@html) %>
            <div class="flex w-full justify-center">
              <.reset_attempts_button
                activity_count={@activity_count}
                advanced_delivery={@advanced_delivery}
                page_context={@page_context}
                section_slug={@section.slug}
              />
            </div>
            <.references ctx={@ctx} bib_app_params={@bib_app_params} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(%{view: :graded_page} = assigns) do
    # For graded page with attempt in progress the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <.countdown {assigns} />
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner />
        <div class="flex-1 w-full max-w-[1040px] px-[80px] pt-20 pb-10 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            objectives={@objectives}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />
          <div id="page_content" class="content w-full" phx-update="ignore" role="page content">
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
            <.references ctx={@ctx} bib_app_params={@bib_app_params} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(%{view: :adaptive_chromeless} = assigns) do
    ~H"""
    <div id="eventIntercept" phx-hook="LoadSurveyScripts">
      <div :if={connected?(@socket) and assigns[:scripts_loaded]}>
        <script>
          window.userToken = "<%= @user_token %>";
        </script>
        <%= OliWeb.Common.React.component(
          %{is_liveview: true},
          "Components.Delivery",
          @app_params,
          id: "adaptive_content"
        ) %>
      </div>

      <%= OliWeb.LayoutView.additional_stylesheets(%{additional_stylesheets: @additional_stylesheets}) %>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end

  def questions_menu(assigns) do
    ~H"""
    <div id="questions_menu" class="w-[157px] h-[468px] ml-0 my-2 overflow-y-scroll flex flex-col">
      <button
        :for={{id, question} <- @questions}
        id={"question_#{id}_button"}
        phx-click={select_question(id)}
        phx-value-id={id}
        class={[
          "flex items-center gap-[18px] h-[33px] pl-[16.5px]",
          if(question.selected, do: "!bg-[#0f6bf5]/5")
        ]}
      >
        <div class={[
          "w-2.5 h-2.5 bg-[#d9d9d9] rounded-full",
          if(question.selected, do: "!border-2 !border-[#0062f2]")
        ]}>
        </div>
        <span class={[
          "text-[#353740] text-base font-normal font-['Open Sans'] leading-normal",
          if(question.selected, do: "!text-[#0f6bf5] !font-bold")
        ]}>
          Question <%= id %>
        </span>
      </button>
    </div>
    """
  end

  defp select_question(js \\ %JS{}, id) do
    js
    |> JS.push("select_question", value: %{id: id})
    |> JS.hide(to: "div[role='one at a time question']")
    |> JS.show(to: "#question_#{id}")
  end

  def countdown(assigns) do
    ~H"""
    <%= if !@review_mode and @time_limit > 0 do %>
      <div
        id="countdown_timer_display"
        phx-update="ignore"
        class="text-lg text-center absolute mt-4 top-2 right-6 font-['Open Sans'] tracking-tight text-zinc-700"
        phx-hook="CountdownTimer"
        data-timer-id="countdown_timer_display"
        data-submit-button-id="submit_answers"
        data-time-out-in-mins={@time_limit}
        data-start-time-in-ms={@attempt_start_time}
        data-effective-time-in-ms={@effective_end_time}
        data-grace-period-in-mins={@grace_period}
        data-auto-submit={if @auto_submit, do: "true", else: "false"}
      >
      </div>
    <% else %>
      <%= if !@review_mode and !is_nil(@effective_end_time) do %>
        <div
          id="countdown_timer_display"
          phx-update="ignore"
          class="text-lg text-center absolute mt-4 top-2 right-6 font-['Open Sans'] tracking-tight text-zinc-700"
          phx-hook="EndDateTimer"
          data-timer-id="countdown_timer_display"
          data-submit-button-id="submit_answers"
          data-effective-time-in-ms={@effective_end_time}
          data-auto-submit={if @auto_submit, do: "true", else: "false"}
        >
        </div>
      <% end %>
    <% end %>
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

  def scored_page_banner(assigns) do
    ~H"""
    <div class="w-full lg:px-20 px-40 py-9 bg-orange-500 bg-opacity-10 flex flex-col justify-center items-center gap-2.5">
      <div class="px-3 py-1.5 rounded justify-start items-start gap-2.5 flex">
        <div class="dark:text-white text-sm font-bold uppercase tracking-wider">
          Scored Activity
        </div>
      </div>
      <div class="max-w-[880px] w-full mx-auto opacity-90 dark:text-white text-sm font-normal leading-6">
        You can start or stop at any time, and your progress will be saved. When you submit your answers using the Submit button, it will count as an attempt. So make sure you have answered all the questions before submitting.
      </div>
    </div>
    """
  end

  defp assign_html_and_scripts(socket) do
    socket
    |> assign_scripts()
    |> assign_html()
  end

  @decorate transaction_event()
  defp assign_scripts(socket) do
    assign(socket,
      scripts: Utils.get_required_activity_scripts(socket.assigns.page_context)
    )
  end

  @decorate transaction_event()
  defp assign_html(socket) do
    assign(socket,
      html: Utils.build_html(socket.assigns, :delivery, is_liveview: true)
    )
  end

  @decorate transaction_event()
  defp assign_objectives(socket) do
    %{page_context: %{page: page}, current_user: current_user, section: section} =
      socket.assigns

    page_attached_objectives =
      Resolver.objectives_by_resource_ids(page.objectives["attached"], section.slug)

    student_proficiency_per_page_level_learning_objective =
      Metrics.proficiency_for_student_per_learning_objective(
        page_attached_objectives,
        current_user.id,
        section
      )

    objectives =
      page_attached_objectives
      |> Enum.map(fn rev ->
        %{
          resource_id: rev.resource_id,
          title: rev.title,
          proficiency:
            Map.get(
              student_proficiency_per_page_level_learning_objective,
              rev.resource_id,
              "Not enough data"
            )
        }
      end)

    assign(socket,
      objectives: objectives
    )
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

  defp annotations_assigns(socket, collab_space_config, is_instructor) do
    case collab_space_config do
      %CollabSpaceConfig{status: :enabled, auto_accept: auto_accept} ->
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
          },
          collab_space_config: collab_space_config
        )

      _ ->
        assign(socket, annotations: nil)
    end
  end

  defp async_load_annotations(
         section,
         resource_id,
         current_user,
         collab_space_config,
         visibility,
         point_block_id,
         load_replies_for_post_id \\ nil
       ) do
    if current_user do
      Task.async(fn ->
        case collab_space_config do
          %CollabSpaceConfig{status: :enabled, auto_accept: auto_accept} ->
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

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end

  _docp = """
  In case the page is configured to show one question at a time,
  we pre-process the html content to assign all the questions to the socket.
  """

  defp maybe_assign_questions(socket, :traditional), do: socket

  defp maybe_assign_questions(socket, :one_at_a_time) do
    questions =
      socket.assigns.html
      |> List.flatten()
      |> Enum.reduce({1, %{}}, fn element, {index, map} ->
        if String.contains?(element, "activity-container") do
          {index + 1, Map.put(map, index, %{raw_content: element, selected: index == 1})}
        else
          {index, map}
        end
      end)
      |> elem(1)

    assign(socket, questions: questions)
  end

  defp to_epoch(nil), do: nil

  defp to_epoch(date_time) do
    date_time
    |> DateTime.to_unix(:second)
    |> Kernel.*(1000)
  end
end
