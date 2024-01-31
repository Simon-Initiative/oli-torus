defmodule OliWeb.Delivery.Student.Utils do
  @moduledoc """
  Common functions for student delivery pages.
  """
  use Phoenix.Component
  use OliWeb, :verified_routes

  import Ecto.Query, warn: false

  alias Oli.Rendering.Context
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Page
  alias OliWeb.Common.FormatDateTime
  alias Oli.Publishing.DeliveryResolver, as: Resolver

  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :index, :string
  attr :container_label, :string
  attr :has_assignments?, :boolean

  def page_header(assigns) do
    ~H"""
    <div id="page_header" class="flex-col justify-start items-start gap-9 flex w-full">
      <div class="flex-col justify-start items-start gap-3 flex w-full">
        <div class="self-stretch flex-col justify-start items-start flex">
          <div class="self-stretch justify-between items-center inline-flex">
            <div class="grow shrink basis-0 self-stretch justify-start items-center gap-3 flex">
              <div
                role="container label"
                class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider"
              >
                <%= @container_label %>
              </div>

              <div
                :if={@page_context.page.graded}
                class="w-px self-stretch opacity-40 bg-black dark:bg-white"
              >
              </div>
              <div
                :if={@page_context.page.graded}
                class="justify-start items-center gap-1.5 flex"
                role="graded page marker"
              >
                <div class="w-[18px] h-[18px] relative">
                  <.flag_icon />
                </div>
                <div class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
                  Graded Page
                </div>
              </div>
            </div>
            <div
              :if={@page_context.page.graded}
              class="px-2 py-1 bg-black bg-opacity-10 dark:bg-white dark:bg-opacity-10 rounded-xl shadow justify-start items-center gap-1 flex"
              role="assignment marker"
            >
              <div class="dark:text-white text-[10px] font-normal font-['Open Sans']">
                Assignment requirement
              </div>
            </div>
          </div>
          <div role="page label" class="self-stretch justify-start items-start gap-2.5 inline-flex">
            <div
              role="page numbering index"
              class="opacity-50 dark:text-white text-[38px] font-bold font-['Open Sans']"
            >
              <%= @index %>.
            </div>
            <div
              role="page title"
              class="grow shrink basis-0 dark:text-white text-[38px] font-bold font-['Open Sans']"
            >
              <%= @page_context.page.title %>
            </div>
          </div>
        </div>
        <div class="justify-start items-center gap-3 inline-flex">
          <div class="opacity-50 justify-start items-center gap-1.5 flex">
            <div role="page read time" class="justify-end items-center gap-1 flex">
              <div class="w-[18px] h-[18px] relative opacity-80">
                <.time_icon />
              </div>
              <div class="justify-end items-end gap-0.5 flex">
                <div class="text-right dark:text-white text-xs font-bold font-['Open Sans'] uppercase tracking-wide">
                  <%= @page_context.page.duration_minutes %>
                </div>
                <div class="dark:text-white text-[9px] font-bold font-['Open Sans'] uppercase tracking-wide">
                  min
                </div>
              </div>
            </div>
          </div>
          <div role="page schedule" class="justify-start items-start gap-1 flex">
            <div class="opacity-50 dark:text-white text-xs font-normal font-['Open Sans']">Due:</div>
            <div class="dark:text-white text-xs font-normal font-['Open Sans']">
              <%= FormatDateTime.to_formatted_datetime(
                @page_context.effective_settings.end_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              ) %>
            </div>
          </div>
        </div>
      </div>
      <div
        :if={@page_context.objectives not in [nil, []]}
        class="flex-col justify-start items-start gap-3 flex w-full"
        role="page objectives"
      >
        <div class="self-stretch justify-start items-start gap-6 inline-flex">
          <div class="opacity-80 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
            Learning objectives
          </div>
          <div class="hidden text-blue-500 text-sm font-semibold font-['Open Sans']">View More</div>
        </div>
        <div
          :for={{objective, index} <- Enum.with_index(@page_context.objectives, 1)}
          class="self-stretch flex-col justify-start items-start flex"
          role={"objective #{index}"}
        >
          <div class="self-stretch py-1 justify-start items-start inline-flex">
            <div class="grow shrink basis-0 h-6 justify-start items-start flex">
              <div class="w-[30px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] leading-normal">
                L<%= index %>
              </div>
              <div class="grow shrink basis-0 opacity-80 dark:text-white text-sm font-normal font-['Open Sans'] leading-normal">
                <%= objective %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def star_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      role="star icon"
    >
      <path
        d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
        fill="#0CAF61"
      />
    </svg>
    """
  end

  def flag_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="18"
      height="18"
      viewBox="0 0 18 18"
      fill="none"
      role="flag icon"
    >
      <path d="M3.75 15.75V3H10.5L10.8 4.5H15V12H9.75L9.45 10.5H5.25V15.75H3.75Z" fill="#F68E2E" />
    </svg>
    """
  end

  def time_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="18"
      height="18"
      viewBox="0 0 18 18"
      fill="none"
      role="time icon"
    >
      <g opacity="0.8">
        <path
          class="fill-black dark:fill-white"
          d="M11.475 12.525L12.525 11.475L9.75 8.7V5.25H8.25V9.3L11.475 12.525ZM9 16.5C7.9625 16.5 6.9875 16.3031 6.075 15.9094C5.1625 15.5156 4.36875 14.9813 3.69375 14.3063C3.01875 13.6313 2.48438 12.8375 2.09063 11.925C1.69688 11.0125 1.5 10.0375 1.5 9C1.5 7.9625 1.69688 6.9875 2.09063 6.075C2.48438 5.1625 3.01875 4.36875 3.69375 3.69375C4.36875 3.01875 5.1625 2.48438 6.075 2.09063C6.9875 1.69688 7.9625 1.5 9 1.5C10.0375 1.5 11.0125 1.69688 11.925 2.09063C12.8375 2.48438 13.6313 3.01875 14.3063 3.69375C14.9813 4.36875 15.5156 5.1625 15.9094 6.075C16.3031 6.9875 16.5 7.9625 16.5 9C16.5 10.0375 16.3031 11.0125 15.9094 11.925C15.5156 12.8375 14.9813 13.6313 14.3063 14.3063C13.6313 14.9813 12.8375 15.5156 11.925 15.9094C11.0125 16.3031 10.0375 16.5 9 16.5ZM9 15C10.6625 15 12.0781 14.4156 13.2469 13.2469C14.4156 12.0781 15 10.6625 15 9C15 7.3375 14.4156 5.92188 13.2469 4.75313C12.0781 3.58438 10.6625 3 9 3C7.3375 3 5.92188 3.58438 4.75313 4.75313C3.58438 5.92188 3 7.3375 3 9C3 10.6625 3.58438 12.0781 4.75313 13.2469C5.92188 14.4156 7.3375 15 9 15Z"
        />
      </g>
    </svg>
    """
  end

  attr :scripts, :list
  attr :user_token, :string

  def scripts(assigns) do
    ~H"""
    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    <script>
      OLI.initActivityBridge('eventIntercept');
    </script>
    <script :for={script <- @scripts} type="text/javascript" src={"/js/#{script}"}>
    </script>
    """
  end

  def learn_live_path(section_slug, target_resource_id \\ nil)

  def learn_live_path(section_slug, nil), do: ~p"/sections/#{section_slug}/learn"

  def learn_live_path(section_slug, target_resource_id),
    do: ~p"/sections/#{section_slug}/learn?target_resource_id=#{target_resource_id}"

  def lesson_live_path(section_slug, revision_slug, nil),
    do: ~p"/sections/#{section_slug}/lesson/#{revision_slug}"

  def lesson_live_path(section_slug, revision_slug, request_path),
    do: ~p"/sections/#{section_slug}/lesson/#{revision_slug}?request_path=#{request_path}"

  def review_live_path(section_slug, revision_slug, attempt_guid, nil),
    do: ~p"/sections/#{section_slug}/lesson/#{revision_slug}/attempt/#{attempt_guid}/review"

  def review_live_path(section_slug, revision_slug, attempt_guid, request_path),
    do:
      ~p"/sections/#{section_slug}/lesson/#{revision_slug}/attempt/#{attempt_guid}/review?request_path=#{request_path}"

  def get_container_label(page_id, section) do
    section_id = section.id

    # Query to find the parent section_resource which contains as a child
    # the section resource whose resource_id matches the given page_id. Just
    # be more robust against weird hierarchies and maybe orphaned containers,
    # we look for only containers with a numbering_level >= 0 and limit to 1.

    query =
      from(s in Oli.Delivery.Sections.SectionResource,
        join: sr in Oli.Delivery.Sections.SectionResource,
        on: sr.section_id == s.section_id and sr.resource_id == ^page_id,
        where:
          s.section_id == ^section_id and
            sr.id in s.children and
            s.numbering_level >= 0,
        select: s,
        limit: 1
      )

    # If we find a container, use it to get the label and numbering. Otherwise,
    # fall back rendering something
    container =
      case Oli.Repo.all(query) do
        [item] -> item
        [] -> %{numbering_index: 0, numbering_level: 0}
      end

    Sections.get_container_label_and_numbering(
      container,
      section.customizations
    )
  end

  def build_html(assigns, mode) do
    %{section: section, current_user: current_user, page_context: page_context} = assigns

    render_context = %Context{
      enrollment:
        Oli.Delivery.Sections.get_enrollment(
          section.slug,
          current_user.id
        ),
      user: current_user,
      section_slug: section.slug,
      mode: mode,
      activity_map: page_context.activities,
      resource_summary_fn: &Oli.Resources.resource_summary(&1, section.slug, Resolver),
      alternatives_groups_fn: fn ->
        Oli.Resources.alternatives_groups(section.slug, Resolver)
      end,
      alternatives_selector_fn: &Oli.Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      bib_app_params: page_context.bib_revisions,
      historical_attempts: page_context.historical_attempts,
      learning_language: Sections.get_section_attributes(section).learning_language,
      effective_settings: page_context.effective_settings
      # when migrating from page_delivery_controller this key-values were found
      # to apparently not be used by the page template:
      #   project_slug: base_project_slug,
      #   submitted_surveys: submitted_surveys,
      #   resource_attempt: hd(context.resource_attempts)
    }

    attempt_content = get_attempt_content(page_context)

    # Cache the page as text to allow the AI agent LV to access it.
    cache_page_as_text(render_context, attempt_content, page_context.page.id)

    Page.render(render_context, attempt_content, Page.Html)
  end

  defp cache_page_as_text(render_context, content, page_id) do
    Oli.Converstation.PageContentCache.put(
      page_id,
      Page.render(render_context, content, Page.Markdown) |> :erlang.iolist_to_binary()
    )
  end

  def get_required_activity_scripts(%{activities: activities} = _page_context)
      when activities != nil do
    # this is an optimization to exclude not needed activity scripts (~1.5mb each)
    Enum.map(activities, fn {_activity_id, activity} ->
      activity.script
    end)
    |> Enum.uniq()
  end

  def get_required_activity_scripts(_page_context) do
    # TODO Optimization: get only activity scripts of activities contained in the page.
    # We could infer the contained activities from the page revision content model.
    all_activities = Oli.Activities.list_activity_registrations()
    Enum.map(all_activities, fn a -> a.delivery_script end)
  end

  defp get_attempt_content(page_context) do
    this_attempt = page_context.resource_attempts |> hd

    if Enum.any?(this_attempt.errors, fn e ->
         e == "Selection failed to fulfill: no values provided for expression"
       end) and page_context.is_student do
      %{"model" => []}
    else
      this_attempt.content
    end
  end
end
