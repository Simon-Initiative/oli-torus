defmodule OliWeb.Delivery.Instructor.PreviewLessonLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils, only: [scripts: 1, references: 1]

  alias Phoenix.LiveView.JS
  alias Oli.Accounts
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Revision
  alias OliWeb.Components.Modal
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
         |> assign_preview_shell_state(), layout: false}
    end
  end

  def render(%{graded: true} = assigns) do
    ~H"""
    <div
      id="instructor-preview-lesson"
      data-preview-mode={@preview_mode}
      phx-hook="InstructorPreviewCustomization"
    >
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
      <.preview_attempt_warning_banner
        warning={@preview_attempt_warning}
        dismissed?={@preview_attempt_warning_dismissed?}
      />
      <div
        :if={preview_flash_visible?(@flash)}
        id="flash_container"
        class="container mx-auto sticky top-[8.5rem] z-[60] px-4"
      >
        <.preview_flash_group flash={@flash} />
      </div>

      <.preview_back_nav request_path={@request_path} />

      <.page_content_with_sidebar_layout active_sidebar_panel={nil}>
        <main id="main" class="flex flex-col gap-6">
          <.preview_page_header
            page_context={@page_context}
            ctx={@ctx}
            current_page={@current_page}
            objectives={@objectives}
            section={@section}
          />

          <.preview_jump_to_section jump_targets={@jump_targets} />

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
        </main>
      </.page_content_with_sidebar_layout>

      <.preview_attempt_warning_modal
        pending={@pending_preview_customization}
        warning={@preview_attempt_warning}
      />
      <.preview_footer license={assigns[:license]} />
      <Utils.proficiency_explanation_modal />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div
      id="instructor-preview-lesson"
      data-preview-mode={@preview_mode}
      phx-hook="InstructorPreviewCustomization"
    >
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
      <.preview_attempt_warning_banner
        warning={@preview_attempt_warning}
        dismissed?={@preview_attempt_warning_dismissed?}
      />
      <div
        :if={preview_flash_visible?(@flash)}
        id="flash_container"
        class="container mx-auto sticky top-[8.5rem] z-[60] px-4"
      >
        <.preview_flash_group flash={@flash} />
      </div>

      <.preview_back_nav request_path={@request_path} />
      <.page_content_with_sidebar_layout active_sidebar_panel={@active_sidebar_panel}>
        <main id="main" class="flex flex-col gap-6">
          <.preview_page_header
            page_context={@page_context}
            ctx={@ctx}
            current_page={@current_page}
            objectives={@objectives}
            section={@section}
          />

          <.preview_jump_to_section jump_targets={@jump_targets} />

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
        </main>
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
      <.preview_attempt_warning_modal
        pending={@pending_preview_customization}
        warning={@preview_attempt_warning}
      />
      <.preview_footer license={assigns[:license]} />
      <Utils.proficiency_explanation_modal />
    </div>
    """
  end

  attr :request_path, :string, required: true

  defp preview_back_nav(assigns) do
    ~H"""
    <div class="sticky top-[135px] sm:top-40 z-50 md:h-20 2xl:h-28">
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

  attr :warning, :map, default: nil
  attr :dismissed?, :boolean, default: false

  defp preview_attempt_warning_banner(assigns) do
    ~H"""
    <div
      :if={@warning && !@dismissed?}
      id="preview-attempt-warning-banner"
      role="alert"
      class="mx-auto mt-2 flex min-h-[52px] w-[90%] max-w-[1280px] items-center justify-center rounded-lg bg-Fill-fill-danger px-5 py-4 font-open-sans text-[14px] font-semibold leading-4 text-Text-text-high"
    >
      <div class="flex w-full items-center justify-between gap-4">
        <div class="flex min-w-0 items-center gap-2">
          <OliWeb.Icons.alert class="h-4 w-4 shrink-0 fill-Icon-icon-danger text-Icon-icon-danger" />
          <p class="m-0 break-words">{@warning.message}</p>
        </div>
        <button
          type="button"
          phx-click="dismiss_preview_attempt_warning"
          class="group -m-1 inline-flex h-10 w-10 shrink-0 items-center justify-center rounded p-1 text-Text-text-high/80 transition hover:text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-focus"
          aria-label="Dismiss warning"
        >
          <OliWeb.Icons.close_sm class="h-4 w-4 stroke-current" />
        </button>
      </div>
    </div>
    """
  end

  attr :pending, :map, default: nil
  attr :warning, :map, default: nil

  defp preview_attempt_warning_modal(assigns) do
    modal_copy = preview_attempt_warning_modal_copy(assigns.warning, assigns.pending)

    assigns =
      assign(assigns,
        body: modal_copy.body,
        confirm_label: modal_copy.confirm_label,
        cancel_label: modal_copy.cancel_label
      )

    ~H"""
    <Modal.modal
      :if={@pending && @body}
      id="preview-attempt-warning-modal"
      show={true}
      on_cancel={JS.push("cancel_preview_customization_warning")}
      show_close={false}
      wrapper_class="flex w-full items-center justify-center px-4 py-8"
      container_class="max-w-[673px] rounded-2xl border border-Border-border-default bg-Surface-surface-background shadow-[0px_2px_10px_rgba(0,50,99,0.10)]"
      header_class="items-start justify-between px-8 pb-0 pt-10 sm:px-16 sm:pt-16"
      body_class="px-8 pb-0 pt-6 sm:px-16"
      title_class="m-0 font-open-sans text-[18px] font-semibold leading-6 text-Text-text-high"
      header_level={2}
    >
      <:title>
        Change will affect future attempts
      </:title>
      <:header_actions>
        <button
          type="button"
          phx-click={
            Modal.hide_modal(
              JS.push("cancel_preview_customization_warning"),
              "preview-attempt-warning-modal"
            )
          }
          class="absolute right-4 top-4 inline-flex h-10 w-10 items-center justify-center rounded text-Text-text-low hover:text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-bold"
          aria-label="Close warning modal"
        >
          <span aria-hidden="true" class="text-[28px] font-light leading-5">&times;</span>
        </button>
      </:header_actions>
      <div class="flex w-full flex-col gap-6">
        <div class="flex flex-col items-end gap-6">
          <p
            id="preview-attempt-warning-modal-description"
            class="m-0 w-full font-open-sans text-[16px] font-normal leading-6 text-Text-text-high"
          >
            {@body}
          </p>
        </div>
      </div>
      <:custom_footer>
        <div class="flex flex-wrap items-start justify-end gap-6 px-8 pb-10 pt-6 sm:px-16 sm:pb-16">
          <button
            type="button"
            phx-click="confirm_preview_customization_warning"
            class="inline-flex items-center justify-center rounded-md border border-Border-border-bold bg-Surface-surface-background px-6 py-2 font-open-sans text-[14px] font-semibold leading-4 text-Specially-Tokens-Text-text-button-secondary shadow-[0px_2px_4px_rgba(0,52,99,0.10)] hover:bg-Surface-surface-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-bold"
          >
            {@confirm_label}
          </button>
          <button
            type="button"
            phx-click={
              Modal.hide_modal(
                JS.push("cancel_preview_customization_warning"),
                "preview-attempt-warning-modal"
              )
            }
            class="inline-flex items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-6 py-2 font-open-sans text-[14px] font-semibold leading-4 text-Text-text-white shadow-[0px_2px_4px_rgba(0,52,99,0.10)] hover:bg-Fill-Buttons-fill-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          >
            {@cancel_label}
          </button>
        </div>
      </:custom_footer>
    </Modal.modal>
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

  attr :jump_targets, :list, required: true

  defp preview_jump_to_section(assigns) do
    assigns =
      assigns
      |> assign(:selection_count, jump_target_count(assigns.jump_targets, :selection))
      |> assign(:question_count, jump_target_count(assigns.jump_targets, :question))

    ~H"""
    <div
      :if={Enum.any?(@jump_targets)}
      id="jump-to-section-nav"
      class="sticky top-[148px] z-[55] -mt-3 w-full pointer-events-none"
    >
      <details
        id="jump-to-section-details"
        class="group pointer-events-auto w-full rounded-[6px] border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input shadow-[0px_1px_4px_rgba(16,24,40,0.12)] [&[open]_.jump-to-section-chevron]:rotate-180"
      >
        <summary
          aria-label="Jump to Section"
          class="flex min-h-14 cursor-pointer list-none items-center justify-between gap-4 px-4 py-3 transition hover:bg-Surface-surface-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-Border-border-focus [&::-webkit-details-marker]:hidden"
        >
          <span class="font-open-sans text-sm font-bold uppercase leading-4 text-Text-text-high">
            Jump to Section
          </span>
          <span class="flex min-w-0 items-center gap-3">
            <span class="truncate text-right font-open-sans text-sm font-normal leading-4 text-Text-text-high">
              {jump_target_count_label(
                @selection_count,
                "Activity Bank Selection",
                "Activity Bank Selections"
              )}
              <span aria-hidden="true"> &bull; </span>
              {jump_target_count_label(@question_count, "Embedded Question", "Embedded Questions")}
            </span>
            <OliWeb.Icons.chevron_down class="jump-to-section-chevron h-4 w-4 shrink-0 fill-Icon-icon-active transition-transform" />
          </span>
        </summary>

        <nav
          aria-label="Jump to page section"
          class="flex max-h-[min(18rem,calc(100vh-18rem))] flex-wrap gap-4 overflow-y-auto border-t border-Specially-Tokens-Border-border-input px-4 pb-4 pt-4"
        >
          <a
            :for={target <- @jump_targets}
            href={"##{target.target_id}"}
            phx-click={JS.remove_attribute("open", to: "#jump-to-section-details")}
            class="inline-flex min-h-10 items-center justify-center rounded-[12px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-detail-pill px-5 py-2 font-open-sans text-sm font-medium leading-4 text-Text-text-high no-underline transition hover:border-Border-border-default hover:bg-Surface-surface-secondary-hover hover:text-Text-text-high hover:no-underline focus-visible:border-Specially-Tokens-Text-text-button-secondary focus-visible:bg-Surface-surface-secondary-hover focus-visible:text-Text-text-button focus-visible:outline focus-visible:outline-[3px] focus-visible:outline-offset-0 focus-visible:outline-Specially-Tokens-Text-text-button-secondary"
          >
            <span>{target.label}</span>
          </a>
        </nav>
      </details>
    </div>
    """
  end

  defp jump_target_count(jump_targets, kind) do
    Enum.count(jump_targets, &(&1.kind == kind))
  end

  defp jump_target_count_label(1, singular, _plural), do: "1 #{singular}"
  defp jump_target_count_label(count, _singular, plural), do: "#{count} #{plural}"

  attr :html, :any, required: true
  attr :ctx, :map, required: true
  attr :bib_app_params, :any, required: true
  attr :graded, :boolean, required: true
  attr :question_count, :integer, required: true

  defp preview_page_content(assigns) do
    ~H"""
    <div
      id="page_content"
      class="content"
      role="region"
      aria-label="Page content"
      phx-update="ignore"
    >
      <%!-- Keep the preview body as one client-owned HTML island. React updates button state via
      hook replies, while LiveView diffs only shell-level data like aggregates and flashes. --%>
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

  def handle_event(
        "toggle_preview_activity_customization",
        %{
          "action" => action,
          "target" => %{
            "kind" => "embedded_activity",
            "pageResourceId" => page_resource_id,
            "activityResourceId" => activity_resource_id
          }
        },
        socket
      ) do
    handle_preview_customization_toggle(socket, action, %{
      kind: :embedded_activity,
      page_resource_id: page_resource_id,
      activity_resource_id: activity_resource_id
    })
  end

  def handle_event(
        "toggle_preview_activity_customization",
        %{
          "action" => action,
          "target" => %{
            "kind" => "bank_selection",
            "pageResourceId" => page_resource_id,
            "selectionId" => selection_id
          }
        },
        socket
      ) do
    handle_preview_customization_toggle(socket, action, %{
      kind: :bank_selection,
      page_resource_id: page_resource_id,
      selection_id: selection_id
    })
  end

  def handle_event(
        "toggle_preview_activity_customization",
        %{"target" => %{"kind" => "bank_selection"}},
        socket
      ) do
    {:reply, %{ok: false, reason: :malformed_target},
     put_flash(
       socket,
       :error,
       "Unable to update an activity bank selection because the request was incomplete."
     )}
  end

  def handle_event(
        "toggle_preview_activity_customization",
        %{"action" => _action, "target" => %{"kind" => unsupported_kind}},
        socket
      ) do
    {:reply, %{ok: false},
     put_flash(
       socket,
       :error,
       "Unsupported customization target #{unsupported_kind} for this preview surface."
     )}
  end

  def handle_event("dismiss_preview_attempt_warning", _params, socket) do
    {:noreply, assign(socket, :preview_attempt_warning_dismissed?, true)}
  end

  def handle_event("cancel_preview_customization_warning", _params, socket) do
    {:noreply, assign(socket, :pending_preview_customization, nil)}
  end

  def handle_event("confirm_preview_customization_warning", _params, socket) do
    case socket.assigns.pending_preview_customization do
      nil ->
        {:noreply, socket}

      pending ->
        {reply, socket} =
          socket
          |> assign(:pending_preview_customization, nil)
          |> apply_preview_customization(pending)

        {:noreply, push_event(socket, "preview_customization_reply", reply)}
    end
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

  defp handle_preview_customization_toggle(socket, action, target) do
    pending = %{action: action, target: target}

    case validate_preview_customization_target(socket, target) do
      :ok ->
        if preview_confirmation_required?(socket) do
          {:reply, confirmation_required_reply(pending),
           assign(socket, :pending_preview_customization, pending)}
        else
          {reply, socket} = apply_preview_customization(socket, pending)

          {:reply, reply, socket}
        end

      {:error, reason} ->
        {reply, socket} = preview_customization_error(socket, target, reason)

        {:reply, reply, socket}
    end
  end

  defp apply_preview_customization(socket, %{action: action, target: target}) do
    result =
      with :ok <- validate_preview_customization_target(socket, target) do
        dispatch_preview_customization(socket, action, target)
      end

    case result do
      {:ok, exclusion_view} ->
        page_summary =
          PreviewPageContext.build_page_summary(socket.assigns.preview_metadata, exclusion_view)

        reply = preview_customization_success_reply(socket, action, target)

        {reply,
         socket
         |> assign(:page_summary, page_summary)
         |> put_flash(:info, preview_customization_success_message(action, target))}

      {:error, reason} ->
        preview_customization_error(socket, target, reason)
    end
  end

  defp validate_preview_customization_target(
         socket,
         %{kind: :embedded_activity, page_resource_id: page_resource_id, activity_resource_id: id}
       ) do
    valid_activity_ids = MapSet.new(socket.assigns.preview_metadata.activity_ids)

    cond do
      page_resource_id != socket.assigns.current_page_resource_id ->
        {:error, :invalid_page_target}

      not MapSet.member?(valid_activity_ids, id) ->
        {:error, :invalid_activity_target}

      true ->
        :ok
    end
  end

  defp validate_preview_customization_target(
         socket,
         %{kind: :bank_selection, page_resource_id: page_resource_id, selection_id: selection_id}
       ) do
    valid_selection_ids = MapSet.new(socket.assigns.preview_metadata.bank_selection_ids)

    cond do
      page_resource_id != socket.assigns.current_page_resource_id ->
        {:error, :invalid_page_target}

      not MapSet.member?(valid_selection_ids, selection_id) ->
        {:error, :invalid_selection_target}

      true ->
        :ok
    end
  end

  defp dispatch_preview_customization(
         socket,
         action,
         %{kind: :embedded_activity, page_resource_id: page_resource_id, activity_resource_id: id}
       ) do
    case action do
      "remove" ->
        InstructorCustomizations.exclude_activity(socket.assigns.section, page_resource_id, id,
          actor: socket.assigns.current_user
        )

      "restore" ->
        InstructorCustomizations.restore_activity(socket.assigns.section, page_resource_id, id,
          actor: socket.assigns.current_user
        )

      _ ->
        {:error, {:invalid_action, action}}
    end
  end

  defp dispatch_preview_customization(
         socket,
         action,
         %{kind: :bank_selection, page_resource_id: page_resource_id, selection_id: selection_id}
       ) do
    case action do
      "remove" ->
        InstructorCustomizations.exclude_bank_selection(
          socket.assigns.section,
          page_resource_id,
          selection_id,
          actor: socket.assigns.current_user
        )

      "restore" ->
        InstructorCustomizations.restore_bank_selection(
          socket.assigns.section,
          page_resource_id,
          selection_id,
          actor: socket.assigns.current_user
        )

      _ ->
        {:error, {:invalid_action, action}}
    end
  end

  defp preview_customization_success_reply(
         _socket,
         action,
         %{kind: :embedded_activity, activity_resource_id: id} = target
       ) do
    %{
      ok: true,
      target: client_preview_customization_target(target),
      activityResourceId: id,
      visualState: preview_visual_state(action),
      statusPill: preview_status_pill(action),
      actions: preview_next_actions(action)
    }
  end

  defp preview_customization_success_reply(
         socket,
         action,
         %{kind: :bank_selection, selection_id: selection_id} = target
       ) do
    %{
      ok: true,
      target: client_preview_customization_target(target),
      selectionId: selection_id,
      availableCount: bank_selection_available_count(socket, action, selection_id),
      visualState: preview_visual_state(action),
      statusPill: preview_status_pill(action),
      actions: preview_next_actions(action)
    }
  end

  defp preview_visual_state("remove"), do: "removed"
  defp preview_visual_state(_action), do: "default"

  defp preview_status_pill("remove"), do: %{kind: "removed", label: "Removed"}
  defp preview_status_pill(_action), do: nil

  defp preview_next_actions("remove"), do: [%{kind: "restore", label: "Restore"}]
  defp preview_next_actions(_action), do: [%{kind: "remove", label: "Remove"}]

  defp client_preview_customization_target(%{
         kind: :embedded_activity,
         page_resource_id: page_resource_id,
         activity_resource_id: activity_resource_id
       }) do
    %{
      kind: "embedded_activity",
      pageResourceId: page_resource_id,
      activityResourceId: activity_resource_id
    }
  end

  defp client_preview_customization_target(%{
         kind: :bank_selection,
         page_resource_id: page_resource_id,
         selection_id: selection_id
       }) do
    %{
      kind: "bank_selection",
      pageResourceId: page_resource_id,
      selectionId: selection_id
    }
  end

  defp bank_selection_available_count(_socket, "remove", _selection_id), do: 0

  defp bank_selection_available_count(socket, _action, selection_id) do
    Map.get(
      socket.assigns.preview_metadata.bank_selection_available_counts_by_id,
      selection_id,
      0
    )
  end

  defp preview_customization_success_message(
         "remove",
         %{kind: :embedded_activity}
       ),
       do: "Question removed from this page."

  defp preview_customization_success_message(
         _action,
         %{kind: :embedded_activity}
       ),
       do: "Question restored to this page."

  defp preview_customization_success_message(
         "remove",
         %{kind: :bank_selection}
       ),
       do: "Activity bank selection removed"

  defp preview_customization_success_message(
         _action,
         %{kind: :bank_selection}
       ),
       do: "Activity bank selection restored"

  defp preview_customization_error(socket, %{kind: :embedded_activity}, reason) do
    case reason do
      {:unauthorized, :customize_section} ->
        {%{ok: false}, put_flash(socket, :error, "You are not allowed to customize this page.")}

      :invalid_page_target ->
        {%{ok: false},
         put_flash(socket, :error, "Unable to update a question outside this page preview.")}

      :invalid_activity_target ->
        {%{ok: false},
         put_flash(socket, :error, "Unable to update a question that is not part of this page.")}

      _reason ->
        {%{ok: false}, put_flash(socket, :error, "Unable to update this question.")}
    end
  end

  defp preview_customization_error(
         socket,
         %{kind: :bank_selection, page_resource_id: page_resource_id, selection_id: selection_id},
         reason
       ) do
    case reason do
      {:unauthorized, :customize_section} ->
        {bank_selection_error_reply(page_resource_id, selection_id, :unauthorized),
         put_flash(socket, :error, "You are not allowed to customize this page.")}

      :invalid_page_target ->
        {bank_selection_error_reply(page_resource_id, selection_id, :invalid_page_target),
         put_flash(
           socket,
           :error,
           "Unable to update an activity bank selection outside this page preview."
         )}

      :invalid_selection_target ->
        {bank_selection_error_reply(page_resource_id, selection_id, :invalid_selection_target),
         put_flash(
           socket,
           :error,
           "Unable to update an activity bank selection that is not part of this page."
         )}

      {:invalid_action, _action} ->
        {bank_selection_error_reply(page_resource_id, selection_id, :invalid_action),
         put_flash(socket, :error, "Unable to update this activity bank selection.")}

      _reason ->
        {bank_selection_error_reply(page_resource_id, selection_id, :domain_error),
         put_flash(socket, :error, "Unable to update this activity bank selection.")}
    end
  end

  defp confirmation_required_reply(%{target: target}) do
    %{
      ok: false,
      reason: :confirmation_required,
      target: client_preview_customization_target(target)
    }
  end

  defp preview_confirmation_required?(socket),
    do: not is_nil(socket.assigns.preview_attempt_warning)

  defp preview_attempt_warning_modal_copy(nil, _pending),
    do: %{body: nil, confirm_label: "Remove question", cancel_label: "Keep question"}

  defp preview_attempt_warning_modal_copy(_warning, nil),
    do: %{body: nil, confirm_label: "Remove question", cancel_label: "Keep question"}

  defp preview_attempt_warning_modal_copy(%{kind: warning_kind}, %{action: action, target: target}) do
    action_gerund =
      case action do
        "restore" -> "Restoring"
        _ -> "Removing"
      end

    target_label =
      case target do
        %{kind: :bank_selection} -> "activity bank selection"
        _ -> "question"
      end

    intro =
      case warning_kind do
        :practice -> "Students have already visited this page."
        _ -> "Students have already started this assessment."
      end

    confirm_action =
      case action do
        "restore" -> "Restore"
        _ -> "Remove"
      end

    confirm_target =
      case target do
        %{kind: :bank_selection} -> "selection"
        _ -> "question"
      end

    %{
      body: "#{intro} #{action_gerund} this #{target_label} will only impact future attempts.",
      confirm_label: "#{confirm_action} #{confirm_target}",
      cancel_label: secondary_warning_action_label(action, confirm_target)
    }
  end

  defp secondary_warning_action_label("remove", "selection"), do: "Keep selection"
  defp secondary_warning_action_label("remove", _confirm_target), do: "Keep question"
  defp secondary_warning_action_label(_action, _confirm_target), do: "Cancel"

  defp bank_selection_error_reply(page_resource_id, selection_id, reason) do
    %{
      ok: false,
      reason: reason,
      target: %{
        kind: "bank_selection",
        pageResourceId: page_resource_id,
        selectionId: selection_id
      }
    }
  end

  defp preview_flash_visible?(flash) do
    not is_nil(Phoenix.Flash.get(flash, :info)) or not is_nil(Phoenix.Flash.get(flash, :error))
  end

  defp navigation_params(params, section_slug) do
    %{}
    |> maybe_put_sanitized_navigation_param("return_to", params["return_to"], section_slug)
    |> maybe_put_sanitized_navigation_param("request_path", params["request_path"], section_slug)
  end

  defp adaptive_redirect_params(params) do
    section_slug = params["section_slug"]

    []
    |> maybe_put_adaptive_redirect_param(
      :return_to,
      params["return_to"],
      section_slug
    )
    |> maybe_put_adaptive_redirect_param(
      :request_path,
      params["request_path"],
      section_slug
    )
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, _key, value, _section_slug)
       when value in [nil, ""] do
    navigation_params
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, key, value, section_slug)
       when is_binary(value) do
    case PreviewReturn.sanitize_return_to(value, section_slug) do
      ^value -> Map.put(navigation_params, key, value)
      _fallback -> navigation_params
    end
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, _key, _value, _section_slug),
    do: navigation_params

  defp maybe_put_adaptive_redirect_param(params, _key, value, _section_slug)
       when value in [nil, ""] do
    params
  end

  defp maybe_put_adaptive_redirect_param(params, key, value, section_slug)
       when is_binary(value) and is_binary(section_slug) do
    case PreviewReturn.sanitize_return_to(value, section_slug) do
      ^value -> Keyword.put(params, key, value)
      _fallback -> params
    end
  end

  defp maybe_put_adaptive_redirect_param(params, _key, _value, _section_slug), do: params

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
        "flex-1 flex flex-col overflow-visible",
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
    instructor_preview_return =
      socket.assigns[:instructor_preview_return] ||
        PreviewReturn.fallback_context(socket.assigns.section_slug)

    selected_view =
      preview_selected_view(
        Map.get(socket.assigns.navigation_params, "request_path") ||
          instructor_preview_return.path
      )

    socket = assign(socket, :instructor_preview_return, instructor_preview_return)

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
    |> assign_preview_attempt_warning_state()
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

  defp assign_preview_attempt_warning_state(socket) do
    warning =
      case preview_attempt_warning_kind(
             socket.assigns.section,
             socket.assigns.current_page_resource_id,
             socket.assigns.graded
           ) do
        kind when kind in [:scored, :practice] ->
          %{
            kind: kind,
            message: preview_attempt_warning_message(kind)
          }

        nil ->
          nil
      end

    assign(socket,
      preview_attempt_warning: warning,
      preview_attempt_warning_dismissed?: false,
      pending_preview_customization: nil
    )
  end

  defp preview_attempt_warning_message(kind) do
    subject =
      case kind do
        :practice -> "visited this page"
        _ -> "started this assessment"
      end

    "Students have already #{subject}. Removing or restoring questions and activity bank selections will only impact future attempts."
  end

  defp preview_attempt_warning_kind(section, page_resource_id, true) do
    if Attempts.has_any_resource_attempts?(section, page_resource_id), do: :scored
  end

  defp preview_attempt_warning_kind(section, page_resource_id, false) do
    if Attempts.has_any_resource_accesses?(section, page_resource_id), do: :practice
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
