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
  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Phoenix.LiveView.JS

  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :objectives, :list
  attr :index, :string
  attr :container_label, :string
  attr :has_assignments?, :boolean

  def page_header(assigns) do
    ~H"""
    <div id="page_header" class="flex-col justify-start items-start gap-9 flex w-full mb-16">
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
                <Icons.flag />
                <div class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
                  Graded Page
                </div>
              </div>
            </div>
            <div
              :if={@page_context.page.graded}
              class="px-2 py-1 bg-gray-300 bg-opacity-10 dark:bg-white dark:bg-opacity-10 rounded-xl shadow justify-start items-center gap-1 flex"
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
                <Icons.time />
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
        :if={@objectives != []}
        class="flex-col justify-start items-start gap-3 flex w-full mt-4"
        role="page objectives"
      >
        <div class="self-stretch justify-start items-start gap-6 inline-flex mb-6">
          <div>
            <span class="text-neutral-700 dark:text-neutral-300 text-base font-bold font-['Inter'] leading-normal">
              LEARNING OBJECTIVES &
            </span>
            <span
              phx-click={Modal.show_modal("proficiency_explanation_modal")}
              class="text-blue-600 text-base font-bold font-['Inter'] leading-normal hover:underline hover:underline-offset-2 cursor-pointer"
            >
              PROFICIENCY
            </span>
            <div class="h-0">
              <.proficiency_explanation_modal />
            </div>
          </div>
        </div>
        <div
          :for={{objective, index} <- Enum.with_index(@objectives, 1)}
          class="self-stretch flex-col justify-start items-start flex ml-6"
          role={"objective #{index}"}
        >
          <div class="relative h-[21px] justify-start items-center gap-[19px] inline-flex">
            <.proficiency_icon_with_tooltip objective={objective} />
            <div class="justify-start items-start gap-3.5 flex">
              <div class="justify-start items-start gap-[17px] flex">
                <div class="w-5 text-neutral-800 dark:text-neutral-500 text-sm font-bold font-['Inter'] leading-[21px]">
                  L<%= index %>
                </div>
                <div
                  role={"objective #{index} title"}
                  class="text-stone-700 dark:text-stone-300 text-sm font-normal font-['Open Sans'] leading-[21px]"
                >
                  <%= objective.title %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def proficiency_explanation_modal(assigns) do
    assigns =
      assign(assigns, %{
        proficiency_levels: [
          {"Not enough data", "Not enough information",
           "You haven’t completed enough activities for the system to calculate learning proficiency."},
          {"Low", "Beginning Proficiency",
           "You’re beginning to understand key ideas, but there is room to grow."},
          {"Medium", "Growing Proficiency",
           "Your understanding and skills are clearly strengthening and expanding."},
          {"High", "Establishing Proficiency",
           "You know the material well enough to apply it in different contexts."}
        ]
      })

    ~H"""
    <Modal.student_delivery_modal
      id="proficiency_explanation_modal"
      class="lg:!w-3/4 xl:!w-2/3"
      body_class=""
    >
      <:title>Measuring Learning Proficiency</:title>
      <:subtitle>
        This course contains several learning objectives. As you continue the course, you will receive an estimate of your understanding of each objective. This estimate takes into account the activities you complete on each page.
      </:subtitle>
      <div class="mb-11 text-zinc-700 dark:text-white text-base font-bold font-['Inter'] leading-normal">
        LEARNING PROFICIENCY SCALE
      </div>
      <div class="flex-col justify-start items-center gap-[50px] flex">
        <div
          :for={{proficiency, name, description} <- @proficiency_levels}
          class="flex-col justify-start items-start gap-[15px] flex w-full"
        >
          <div class="justify-start items-start gap-2.5 inline-flex">
            <div class="mt-[2px] ml-1 w-6 h-6 scale-125">
              <Icons.proficiency proficiency={proficiency} />
            </div>
            <div class="text-zinc-700 dark:text-white text-base font-bold font-['Inter'] leading-normal">
              <%= name %>
            </div>
          </div>
          <div class="text-zinc-700 dark:text-white text-base font-normal font-['Inter'] leading-normal">
            <%= description %>
          </div>
        </div>
      </div>
    </Modal.student_delivery_modal>
    """
  end

  attr :objective, :map

  defp proficiency_icon_with_tooltip(assigns) do
    ~H"""
    <div
      class="absolute top-0 left-0 z-10 w-6 h-6 cursor-pointer"
      xphx-mouseover={JS.show(to: "#objective_#{@objective.resource_id}_tooltip")}
      xphx-mouseout={JS.hide(to: "#objective_#{@objective.resource_id}_tooltip")}
    >
    </div>
    <div class="w-6 h-6 flex items-center justify-center">
      <Icons.proficiency proficiency={@objective.proficiency} />
    </div>
    <div
      id={"objective_#{@objective.resource_id}_tooltip"}
      class="hidden absolute h-[57px] px-6 pt-[15px] pb-6 -top-[20px] -left-6 text-gray-800 dark:text-gray-700 text-base font-normal font-['Inter'] leading-normal bg-gray-300 dark:bg-white rounded-md border-2 border-gray-700 flex-col justify-start items-start gap-4 -translate-x-full"
    >
      <%= proficiency_to_text(@objective.proficiency) %>
      <div class="absolute h-[40px] w-2 bg-gray-300 dark:bg-white top-2 right-0 z-20"></div>
      <Icons.filled_chevron_up class="absolute -right-[13px] top-[16px] fill-gray-300 dark:fill-white z-10 rotate-90 scale-150 stroke-1.5 stroke-gray-700" />
    </div>
    """
  end

  defp proficiency_to_text("Not enough data"), do: "Not enough information"
  defp proficiency_to_text("Low"), do: "Beginning Proficiency"
  defp proficiency_to_text("Medium"), do: "Growing Proficiency"
  defp proficiency_to_text("High"), do: "Establishing Proficiency"

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

  @doc """
  Generates a URL for the Learn view.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `learn_live_path("math")` returns `"/sections/math/learn"`.
    - `learn_live_path("math", target_resource_id: "123")` returns `"/sections/math/learn?target_resource_id=123"`.
  """
  def learn_live_path(section_slug, params \\ [])

  def learn_live_path(section_slug, []), do: ~p"/sections/#{section_slug}/learn"

  def learn_live_path(section_slug, params),
    do: ~p"/sections/#{section_slug}/learn?#{params}"

  @doc """
  Generates a URL for a specific lesson.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `revision_slug`: The unique identifier for the lesson revision.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `lesson_live_path("math", "intro")` returns `"/sections/math/lesson/intro"`.
    - `lesson_live_path("math", "intro", request_path: "some/previous/url")` returns `"/sections/math/lesson/intro?request_path=some/previous/url"`.
  """
  def lesson_live_path(section_slug, revision_slug, params \\ [])

  def lesson_live_path(section_slug, revision_slug, []),
    do: ~p"/sections/#{section_slug}/lesson/#{revision_slug}"

  def lesson_live_path(section_slug, revision_slug, params),
    do: ~p"/sections/#{section_slug}/lesson/#{revision_slug}?#{params}"

  @doc """
  Generates a URL for reviewing an attempt of a lesson.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `revision_slug`: The unique identifier for the lesson revision.
    - `attempt_guid`: The unique identifier for the attempt.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `review_live_path("math", "intro", "abcd")` returns `"/sections/math/lesson/intro/attempt/abcd/review"`.
    - `review_live_path("math", "intro", "abcd", request_path: "some/previous/url")` returns `"/sections/math/lesson/intro/attempt/abcd/review?request_path=some/previous/url"`.
  """
  def review_live_path(section_slug, revision_slug, attempt_guid, params \\ [])

  def review_live_path(section_slug, revision_slug, attempt_guid, []),
    do: ~p"/sections/#{section_slug}/lesson/#{revision_slug}/attempt/#{attempt_guid}/review"

  def review_live_path(section_slug, revision_slug, attempt_guid, params),
    do:
      ~p"/sections/#{section_slug}/lesson/#{revision_slug}/attempt/#{attempt_guid}/review?#{params}"

  @doc """
  Generates a URL for the course schedule.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `schedule_live_path("math")` returns `"/sections/math/assignments"`.
    - `schedule_live_path("math", request_path: "some/previous/url")` returns `"/sections/math/assignments?request_path=some/previous/url"`.
  """
  def schedule_live_path(section_slug, params \\ [])

  def schedule_live_path(section_slug, []),
    do: ~p"/sections/#{section_slug}/assignments"

  def schedule_live_path(section_slug, params),
    do: ~p"/sections/#{section_slug}/assignments?#{params}"

  # nil case arises for linked loose pages not in in hierarchy index
  def get_container_label(nil, section), do: section.title

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
      effective_settings: page_context.effective_settings,
      # when migrating from page_delivery_controller this key-values were found
      # to apparently not be used by the page template:
      #   project_slug: base_project_slug,
      #   submitted_surveys: submitted_surveys,
      resource_attempt: hd(page_context.resource_attempts)
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
      Map.get(activity, :script)
    end)
    |> Enum.reject(&is_nil/1)
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

  @doc """
  Calculates the date range for a specific week number relative to a given section start date.

  ## Parameters
  - `week_number`: The number of the week for which the range is needed, starting from 1.
  - `section_start_date`: The start date of the section, given as a `DateTime`.

  ## Returns
  - A tuple containing the start and end dates (`Date` structs) of the specified week, starting from Sunday.

  ## Examples
      iex> week_range(5, ~N[2024-01-01T00:00:00])
      {~D[2024-01-28], ~D[2024-02-03]}
  """

  @spec week_range(integer(), DateTime.t()) :: {Date.t(), Date.t()}
  def week_range(week_number, section_start_date) do
    week_start =
      section_start_date
      |> DateTime.to_date()
      |> Date.beginning_of_week(:sunday)
      |> Date.add((week_number - 1) * 7)

    {week_start, Date.add(week_start, 6)}
  end
end
