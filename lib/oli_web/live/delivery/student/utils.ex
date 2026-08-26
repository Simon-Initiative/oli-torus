defmodule OliWeb.Delivery.Student.Utils do
  @moduledoc """
  Common functions for student delivery pages.
  """
  use Phoenix.Component
  use OliWeb, :verified_routes
  use Appsignal.Instrumentation.Decorators

  import Ecto.Query, warn: false

  alias Oli.Rendering.Context
  alias Oli.Delivery.LearningObjectives.PageElement, as: LearningObjectivesPageElement
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Page
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Oli.Delivery.LearningObjectives.ProficiencyDisplay
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Delivery.Instructor.PreviewRoutes
  alias OliWeb.Common.SessionContext

  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, SessionContext
  attr :objectives, :list
  attr :index, :string
  attr :container_label, :string
  attr :has_assignments?, :boolean
  attr :display_curriculum_item_numbering, :boolean, default: true
  attr :show_divider, :boolean, default: true
  attr :show_assignment_marker, :boolean, default: true
  attr :show_schedule_dates, :boolean, default: true

  def page_header(assigns) do
    ~H"""
    <div id="page_header" class="flex-col justify-start items-start gap-3 sm:gap-9 flex w-full">
      <div class="flex-col justify-start items-start gap-3 flex w-full">
        <div class="self-stretch flex-col justify-start items-start flex gap-3">
          <div class="self-stretch justify-between items-center inline-flex">
            <div class="grow shrink basis-0 self-stretch justify-start items-center gap-3 flex">
              <div
                :if={@container_label not in [nil, ""]}
                role="container label"
                class="text-Text-text-high text-sm font-bold uppercase tracking-wider"
              >
                {@container_label}
              </div>

              <div
                :if={@page_context.page.graded and @container_label not in [nil, ""]}
                aria-hidden="true"
                class="w-px self-stretch opacity-40 bg-black dark:bg-white"
              >
              </div>
              <div
                :if={@page_context.page.graded}
                class="justify-start items-center gap-1.5 flex"
                role="scored page marker"
              >
                <Icons.flag />
                <div class="text-Text-text-high text-sm font-bold uppercase tracking-wider opacity-75">
                  Scored Page
                </div>
              </div>
            </div>
            <div
              :if={@show_assignment_marker and @page_context.page.graded}
              class="px-2 py-1 bg-Specially-Tokens-Fill-fill-detail-pill rounded-xl shadow justify-start items-center gap-1 flex"
              role="assignment marker"
            >
              <div class="text-Text-text-high text-[10px] font-normal">
                Assignment requirement
              </div>
            </div>
          </div>
          <div role="page label" class="self-stretch justify-start items-baseline gap-2.5 inline-flex">
            <div
              :if={@index}
              role="page numbering index"
              class="text-Text-text-low text-[32px] sm:text-[40px] leading-[44px] font-bold opacity-75"
            >
              {@index}.
            </div>
            <h1
              role="page title"
              class="grow shrink basis-0 text-Text-text-high text-[32px] sm:text-[40px] leading-[44px] font-bold"
            >
              {@page_context.page.title}
            </h1>
          </div>
        </div>
        <div class="justify-start items-center gap-3 flex">
          <div
            :if={@page_context.page.duration_minutes}
            class="ml-10 sm:ml-0 justify-start items-center gap-1.5 flex"
          >
            <div role="page read time" class="justify-end items-center gap-1 flex">
              <div class="w-[18px] h-[18px] relative text-Text-text-low">
                <Icons.time />
              </div>
              <div class="justify-end items-end gap-0.5 flex">
                <div class="text-right text-Text-text-low text-xs font-semibold tracking-wide">
                  {@page_context.page.duration_minutes}
                </div>
                <div class="text-Text-text-low text-[9px] self-center font-semibold tracking-wide">
                  min
                </div>
              </div>
            </div>
          </div>
          <div
            :if={@show_schedule_dates and @page_context.effective_settings.start_date}
            role="page start schedule"
            class="justify-start items-start gap-1 flex"
          >
            <div class="text-Text-text-low text-xs font-semibold">
              Available by:
            </div>
            <div class="text-Text-text-low text-xs font-semibold">
              {FormatDateTime.to_formatted_datetime(
                @page_context.effective_settings.start_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              )}
            </div>
          </div>
          <div
            :if={@show_schedule_dates and @page_context.effective_settings.end_date}
            role="page schedule"
            class="justify-start items-start gap-1 flex"
          >
            <div class="text-Text-text-high text-xs font-semibold">
              {label_for_scheduling_type(@page_context.effective_settings.scheduling_type)}
            </div>
            <div class="text-Text-text-high text-xs font-semibold">
              {FormatDateTime.to_formatted_datetime(
                @page_context.effective_settings.end_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              )}
            </div>
          </div>
        </div>
      </div>
      <section
        :if={@objectives != []}
        class="flex w-full flex-col items-start gap-4 rounded-xl border border-Border-border-bold p-4"
        role="region"
        aria-label="Learning objectives"
        data-testid="page-objectives"
      >
        <div class="flex items-center justify-center gap-2">
          <h2 class="m-0 font-open-sans text-base font-bold leading-4 text-Text-text-high">
            LEARNING OBJECTIVES
          </h2>
        </div>
        <div class="flex w-full flex-col items-start gap-4 px-4 py-2" role="list">
          <div
            :for={{objective, index} <- Enum.with_index(@objectives, 1)}
            class="flex min-h-7 w-full items-center gap-3"
            role="listitem"
            data-objective-id={objective.resource_id}
          >
            <.proficiency_chip objective={objective} />
            <div class="flex min-h-7 min-w-0 flex-1 translate-y-px items-center gap-[6px]">
              <div class="shrink-0 font-open-sans text-xs font-bold uppercase leading-[18px] text-Text-text-low-alpha">
                L{index}
              </div>
              <div
                data-testid={"objective-#{objective.resource_id}-title"}
                class="min-w-0 break-words font-open-sans text-sm font-normal leading-[18px] text-Text-text-high"
              >
                {objective.title}
              </div>
            </div>
          </div>
          <details class="group/page-proficiency w-full">
            <summary class="flex h-10 cursor-pointer list-none items-start justify-center border-b border-Border-border-default px-1 [&::-webkit-details-marker]:hidden">
              <div class="flex h-[35px] min-w-0 flex-1 items-center gap-1">
                <Icons.support
                  class="h-5 w-5 shrink-0 text-Icon-icon-default"
                  width="20"
                  height="20"
                  view_box="0 0 20 20"
                  variant="figma_20"
                />
                <span class="min-w-0 flex-1 font-open-sans text-xs font-semibold leading-3 text-Text-text-low-alpha">
                  What is proficiency and how is it estimated?
                </span>
                <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center text-Icon-icon-default transition-transform group-open/page-proficiency:rotate-180">
                  <Icons.chevron_down
                    class="h-4 w-4 text-Icon-icon-default"
                    width="16"
                    height="16"
                    view_box="0 0 16 16"
                    variant="stroke"
                    path="M4 7L8 11L12 7"
                  />
                </span>
              </div>
            </summary>
            <div class="pt-3">
              <p class="m-0 font-open-sans text-sm font-normal leading-6 text-Text-text-high">
                Proficiency is our best estimate of how likely you are to successfully apply a learning objective the next time you use it. It updates as you complete course activities and is based on evidence from your overall work. Proficiency estimates become more reliable as you complete more activities.
              </p>
              <div class="mt-[10px] grid grid-cols-2 gap-[6px] md:grid-cols-4">
                <.proficiency_explanation_card
                  proficiency="Not enough data"
                  id_suffix="page_explanation_not_enough"
                />
                <.proficiency_explanation_card proficiency="Low" />
                <.proficiency_explanation_card proficiency="Medium" />
                <.proficiency_explanation_card proficiency="High" />
              </div>
            </div>
          </details>
        </div>
      </section>
      <span :if={@show_divider} class="mb-6 border-b border-Border-border-default w-full"></span>
    </div>
    """
  end

  attr :terms, :list, required: true
  attr :is_adaptive, :boolean

  def page_terms(assigns) do
    ~H"""
    <div
      id="page_terms"
      class="dark:text-[#eeebf5] text-base leading-normal font-normal flex flex-col w-full mb-10"
    >
      <span class="font-bold">
        TERMS
      </span>
      <ul class="list-disc ml-6">
        <li :for={term <- @terms} id={term.id}>
          <%= for {kind, value} <- term.segments do %>
            <%= case kind do %>
              <% :strong -> %>
                <strong>{value}</strong>
              <% _ -> %>
                {value}
            <% end %>
          <% end %>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Parses the minutes into a human-readable format.

  iex> parse_minutes(1)
  "1 minute"

  iex> parse_minutes(60)
  "1 hour"

  iex> parse_minutes(61)
  "1 hour and 1 minute"

  iex> parse_minutes(120)
  "2 hours"

  iex> parse_minutes(125)
  "2 hours and 5 minutes"
  """
  def parse_minutes(minutes), do: Oli.Delivery.Page.PrologueTerms.parse_minutes(minutes)

  @doc """
  Returns the scheduling type label for the container.
  When all the contained resources are of :read_by type, then
  the label will be "Read by: "
  """
  def container_label_for_scheduling_type([:read_by]), do: "Read by: "
  def container_label_for_scheduling_type(_), do: "Due by: "

  def label_for_scheduling_type(type) when type in [:due_by, nil], do: "Due by: "
  def label_for_scheduling_type(:read_by), do: "Read by: "
  def label_for_scheduling_type(:inclass_activity), do: "In-class activity by: "
  def label_for_scheduling_type(_), do: ""

  def proficiency_explanation_modal(assigns) do
    assigns = assign(assigns, :proficiency_levels, ProficiencyDisplay.levels())

    ~H"""
    <Modal.student_delivery_modal
      id="proficiency_explanation_modal"
      class="lg:!w-3/4 xl:!w-2/3"
      body_class=""
    >
      <:title>Measuring Learning Proficiency</:title>
      <:subtitle>
        Proficiency is our best estimate of how likely you are to successfully apply a learning objective the next time you use it. It updates as you complete course activities and is based on evidence from your overall work.
      </:subtitle>
      <div class="mb-6 sm:mb-11 font-open-sans text-base font-bold leading-normal text-Text-text-high">
        LEARNING PROFICIENCY SCALE
      </div>
      <div class="flex flex-col items-start gap-[24px]">
        <div
          :for={proficiency <- @proficiency_levels}
          class="flex w-full flex-col items-start gap-[10px]"
        >
          <% display = proficiency_display(proficiency) %>
          <div class="inline-flex items-center gap-2.5">
            <span class="inline-flex h-6 w-6 items-center justify-center">
              <.proficiency_level_icon
                display={display}
                id_suffix={"modal_explanation_#{display.id_key}"}
              />
            </span>
            <div class="font-open-sans text-base font-bold leading-normal text-Text-text-high">
              {display.label}
            </div>
          </div>
          <div class="font-open-sans text-base font-normal leading-normal text-Text-text-high">
            {display.description}
          </div>
        </div>
      </div>
    </Modal.student_delivery_modal>
    """
  end

  attr :objective, :map

  defp proficiency_chip(assigns) do
    assigns =
      assigns
      |> assign(:display, proficiency_display(assigns.objective.proficiency))

    ~H"""
    <span
      class={[
        "group relative inline-flex shrink-0 items-center justify-center rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        @display.chip_class
      ]}
      tabindex="0"
      role="img"
      aria-label={@display.label}
      title={@display.label}
    >
      <.proficiency_level_icon
        display={@display}
        id_suffix={"objective_#{@objective.resource_id}_not_enough"}
      />
      <span
        id={"objective_#{@objective.resource_id}_tooltip"}
        role="tooltip"
        class="pointer-events-none absolute bottom-full left-1/2 z-10 mb-2 -translate-x-1/2 whitespace-nowrap rounded bg-Specially-Tokens-Fill-fill-inverse px-2 py-1 font-open-sans text-xs font-semibold text-Specially-Tokens-Text-text-inverse opacity-0 shadow transition-opacity group-hover:opacity-100 group-focus:opacity-100"
      >
        {@display.label}
      </span>
    </span>
    """
  end

  attr :proficiency, :string, required: true
  attr :id_suffix, :string, default: nil

  defp proficiency_explanation_card(assigns) do
    assigns = assign(assigns, :display, proficiency_display(assigns.proficiency))

    ~H"""
    <div class={[
      "flex h-[255px] min-w-0 flex-col items-center rounded-[9px] text-center font-open-sans",
      @display.order_class,
      @display.card_class
    ]}>
      <div class={["flex flex-col items-center gap-[15px]", @display.content_class]}>
        <div class="flex h-6 items-center justify-center">
          <span class="inline-flex h-6 w-6 items-center justify-center">
            <.proficiency_level_icon
              display={@display}
              id_suffix={@id_suffix || "page_explanation_#{@display.id_key}"}
            />
          </span>
        </div>
        <div class="text-center text-[14px] font-bold leading-[17.5px] text-Text-text-high">
          <span :for={line <- @display.label_lines} class="block">{line}</span>
        </div>
        <p class="m-0 text-center text-[12px] font-normal leading-[15px] text-Text-text-high">
          {@display.description}
        </p>
      </div>
    </div>
    """
  end

  attr :display, :map, required: true
  attr :id_suffix, :string, default: nil

  defp proficiency_level_icon(%{display: %{icon: :empty_pot}} = assigns) do
    ~H"""
    <Icons.proficiency_empty_pot class={@display.icon_class} id_suffix={@id_suffix} />
    """
  end

  defp proficiency_level_icon(%{display: %{icon: :seed}} = assigns) do
    ~H"""
    <Icons.proficiency_seed class={@display.icon_class} />
    """
  end

  defp proficiency_level_icon(%{display: %{icon: :sprout}} = assigns) do
    ~H"""
    <Icons.proficiency_sprout class={@display.icon_class} />
    """
  end

  defp proficiency_level_icon(%{display: %{icon: :tree}} = assigns) do
    ~H"""
    <Icons.proficiency_tree class={@display.icon_class} />
    """
  end

  defp proficiency_display(proficiency) do
    ProficiencyDisplay.display_for(proficiency)
    |> Map.merge(proficiency_styles(proficiency))
  end

  defp proficiency_styles(proficiency) do
    proficiency
    |> shared_card_styles_for()
    |> Map.merge(chip_styles_for(proficiency))
  end

  defp shared_card_styles_for("High") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Text-text-accent-green",
      card_class: "justify-start bg-Fill-Chip-Green px-[17px] pt-[25px]",
      content_class: "w-[126px]",
      order_class: "order-3 md:order-4"
    }
  end

  defp shared_card_styles_for("Medium") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Icon-icon-accent-purple",
      card_class: "justify-start bg-Fill-Accent-fill-accent-purple px-[15px] pt-[28px]",
      content_class: "w-[130px]",
      order_class: "order-4 md:order-3"
    }
  end

  defp shared_card_styles_for("Low") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Icon-icon-accent-orange",
      card_class: "justify-start bg-Fill-Accent-fill-accent-orange/70 px-6 pt-[23px]",
      content_class: "w-[112px]",
      order_class: "order-2"
    }
  end

  defp shared_card_styles_for(_) do
    %{
      icon_class: "h-6 w-6 shrink-0",
      card_class:
        "justify-start bg-Fill-Chip-Gray px-4 pt-[31px] md:[html:not(.dark)_&]:bg-Table-table-row-1",
      content_class: "w-32",
      order_class: "order-1"
    }
  end

  defp chip_styles_for("High"), do: %{chip_class: "bg-Fill-Chip-Green px-[10px] py-[3px]"}

  defp chip_styles_for("Medium"),
    do: %{chip_class: "bg-Fill-Accent-fill-accent-purple px-[10px] py-[3px]"}

  defp chip_styles_for("Low"),
    do: %{chip_class: "bg-Fill-Accent-fill-accent-orange px-[10px] py-[3px]"}

  defp chip_styles_for(_),
    do: %{chip_class: "px-[9px] py-[3px]", icon_class: "h-[22px] w-[22px] shrink-0"}

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

  attr :activity_count, :integer, default: 0
  attr :advanced_delivery, :boolean, default: false
  attr :page_context, :map, required: true
  attr :section_slug, :string, required: true

  def reset_attempts_button(assigns) do
    ~H"""
    <button
      :if={@page_context.review_mode == false && not @advanced_delivery && @activity_count > 0}
      id="reset_answers"
      class="btn btn-sm text-center mb-10 text-Text-text-link"
      onClick={"window.OLI.finalize('#{@section_slug}', '#{@page_context.page.slug}', '#{hd(@page_context.resource_attempts).attempt_guid}', false, 'reset_answers')"}
    >
      <i class="fa-solid fa-rotate-right mr-2"></i> Reset Answers
    </button>
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
  def section_home_path(section_slug, preview_mode \\ false)

  def section_home_path(section_slug, true),
    do: ~p"/sections/#{section_slug}/preview"

  def section_home_path(section_slug, _preview_mode),
    do: ~p"/sections/#{section_slug}"

  def learn_live_path(section_slug, params \\ [])

  def learn_live_path(section_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/preview/learn"

      {true, params} ->
        ~p"/sections/#{section_slug}/preview/learn?#{params}"

      {false, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/learn"

      {false, params} ->
        ~p"/sections/#{section_slug}/learn?#{params}"
    end
  end

  @doc """
  Generates a URL for a specific lesson.

  Preview mode opens lessons through the instructor customization preview shell. Student delivery
  previews should omit preview mode and use the normal delivery routes.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `revision_slug`: The unique identifier for the lesson revision.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `lesson_live_path("math", "intro")` returns `"/sections/math/lesson/intro"`.
    - `lesson_live_path("math", "intro", request_path: "some/previous/url")` returns `"/sections/math/lesson/intro?request_path=some/previous/url"`.
  """
  def lesson_live_path(section_slug, revision_slug, params \\ [])

  def lesson_live_path(section_slug, revision_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, params} ->
        PreviewRoutes.lesson_path(section_slug, revision_slug, params)

      {false, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/lesson/#{revision_slug}"

      {false, params} ->
        ~p"/sections/#{section_slug}/lesson/#{revision_slug}?#{params}"
    end
  end

  @doc """
  Generates a URL for the Prologue view for a given graded page.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `revision_slug`: The unique identifier for the lesson revision.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `prologue_live_path("math", "intro")` returns `"/sections/math/prologue/intro"`.
    - `prologue_live_path("math", "intro", request_path: "some/previous/url")` returns `"/sections/math/prologue/intro?request_path=some/previous/url"`.
  """
  def prologue_live_path(section_slug, revision_slug, params \\ [])

  def prologue_live_path(section_slug, revision_slug, []),
    do: ~p"/sections/#{section_slug}/prologue/#{revision_slug}"

  def prologue_live_path(section_slug, revision_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, params} ->
        PreviewRoutes.lesson_path(section_slug, revision_slug, params)

      {false, params} ->
        ~p"/sections/#{section_slug}/prologue/#{revision_slug}?#{params}"
    end
  end

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
    - `schedule_live_path("math")` returns `"/sections/math/student_schedule"`.
    - `schedule_live_path("math", request_path: "some/previous/url")` returns `"/sections/math/student_schedule?request_path=some/previous/url"`.
  """
  def schedule_live_path(section_slug, params \\ [])

  def schedule_live_path(section_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/preview/student_schedule"

      {true, params} ->
        ~p"/sections/#{section_slug}/preview/student_schedule?#{params}"

      {false, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/student_schedule"

      {false, params} ->
        ~p"/sections/#{section_slug}/student_schedule?#{params}"
    end
  end

  @doc """
  Generates a URL for the course assignments.

  ## Parameters
    - `section_slug`: The unique identifier for the section.
    - `params`: (Optional) Additional query parameters in a list or map format. If omitted, a URL is generated without additional parameters.

  ## Examples
    - `assignments_live_path("math")` returns `"/sections/math/assignments"`.
    - `assignments_live_path("math", request_path: "some/previous/url")` returns `"/sections/math/assignments?request_path=some/previous/url"`.
  """
  def assignments_live_path(section_slug, params \\ [])

  def assignments_live_path(section_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/preview/assignments"

      {true, params} ->
        ~p"/sections/#{section_slug}/preview/assignments?#{params}"

      {false, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/assignments"

      {false, params} ->
        ~p"/sections/#{section_slug}/assignments?#{params}"
    end
  end

  def explorations_live_path(section_slug, params \\ [])

  def explorations_live_path(section_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/preview/explorations"

      {true, params} ->
        ~p"/sections/#{section_slug}/preview/explorations?#{params}"

      {false, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/explorations"

      {false, params} ->
        ~p"/sections/#{section_slug}/explorations?#{params}"
    end
  end

  def practice_live_path(section_slug, params \\ [])

  def practice_live_path(section_slug, params) do
    {preview_mode, params} = route_preview_mode_and_params(params)

    case {preview_mode, params} do
      {true, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/preview/practice"

      {true, params} ->
        ~p"/sections/#{section_slug}/preview/practice?#{params}"

      {false, %{} = params} when map_size(params) == 0 ->
        ~p"/sections/#{section_slug}/practice"

      {false, params} ->
        ~p"/sections/#{section_slug}/practice?#{params}"
    end
  end

  def get_container_label(page_id, section, display_curriculum_item_numbering \\ true)

  # nil case arises for linked loose pages not in in hierarchy index
  def get_container_label(nil, section, _display_curriculum_item_numbering),
    do: section.title

  def get_container_label(page_id, section, display_curriculum_item_numbering) do
    if display_curriculum_item_numbering do
      case normalize_page_id(page_id) do
        nil ->
          nil

        normalized_page_id ->
          hierarchy =
            Oli.Delivery.Sections.SectionResourceDepot.get_full_hierarchy(section, hidden: false)

          case Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
                 hierarchy,
                 &(&1["resource_id"] == normalized_page_id)
               ) do
            %{"display_numbering" => nil} ->
              nil

            %{"display_numbering" => display_numbering} when is_map(display_numbering) ->
              Sections.get_container_label_and_numbering(
                display_numbering["level"],
                display_numbering["index"],
                section.customizations
              )

            %{"numbering" => numbering} ->
              Sections.get_container_label_and_numbering(
                numbering["level"],
                numbering["index"],
                section.customizations
              )

            _ ->
              nil
          end
      end
    else
      nil
    end
  end

  defp normalize_page_id(page_id) when is_integer(page_id), do: page_id

  defp normalize_page_id(page_id) when is_binary(page_id) do
    case Integer.parse(page_id) do
      {parsed_page_id, ""} -> parsed_page_id
      _ -> nil
    end
  end

  defp normalize_page_id(_), do: nil

  def route_preview_mode_and_params(params) do
    params = Enum.into(params, %{})

    preview_mode =
      case Map.get(params, :preview_mode, Map.get(params, "preview_mode", false)) do
        true -> true
        _ -> false
      end

    cleaned_params =
      params
      |> Map.delete(:preview_mode)
      |> Map.delete("preview_mode")

    {preview_mode, cleaned_params}
  end

  def build_html(assigns, mode, opts \\ []) do
    %{section: section, page_context: page_context} = assigns

    page_link_params =
      build_page_link_params(
        assigns.section.slug,
        assigns.page_context.page,
        assigns.request_path,
        assigns.selected_view
      )

    render_context = %Context{
      enrollment:
        Oli.Delivery.Sections.get_enrollment(
          section.slug,
          page_context.user.id
        ),
      user: page_context.user,
      page_id: page_context.page.resource_id,
      section_id: section.id,
      section_slug: section.slug,
      project_slug: Oli.Repo.get(Oli.Authoring.Course.Project, section.base_project_id).slug,
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
      resource_attempt: hd(page_context.resource_attempts),
      page_link_params: page_link_params,
      internal_link_url: &lesson_live_path(section.slug, &1, page_link_params),
      is_liveview: opts[:is_liveview] || false
    }

    attempt_content = get_attempt_content(page_context)

    render_context = %Context{
      render_context
      | learning_objectives:
          LearningObjectivesPageElement.prepare_render_payload(
            section,
            page_context.page.resource_id,
            attempt_content,
            render_context.user
          )
    }

    # Cache the page as text to allow the AI agent LV to access it.
    cache_page_as_text(render_context, attempt_content, page_context.page.id)

    Appsignal.instrument("Page.render", fn ->
      Page.render(render_context, attempt_content, Page.Html)
    end)
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

  @decorate transaction_event()
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

  @doc """
  Calculates the number of days from today to the given end date of a resource and returns a human-readable string describing the difference.
  It considers the user's timezone to calculate the difference.

  ## Parameters:
  - `resource_end_date`: The `DateTime` representing the end date of the resource.
  - `scheduling_type`: The type of scheduling for the resource, such as `:read_by`, `:due_by`, or `:inclass_activity`.
  - `context`: The `SessionContext` struct containing the user's timezone information.

  ## Returns:
  - A string indicating the number of days until or since the resource end date, such as "Due Today", "1 day left", or "Past Due by X days".
  - "Not yet scheduled" if the provided end date is nil.

  ## Examples:
      iex> days_difference(~U[2024-05-12T00:00:00Z], :read_by, %SessionContext{local_tz: "America/Montevideo"})
      "1 day left"
  """

  def days_difference(nil, _scheduling_type, _context), do: "Not yet scheduled"

  def days_difference(resource_end_date, scheduling_type, context) do
    {localized_end_date, today} =
      case FormatDateTime.maybe_localized_datetime(resource_end_date, context) do
        {:not_localized, datetime} ->
          {DateTime.to_date(datetime), Oli.DateTime.utc_now() |> DateTime.to_date()}

        localized_datetime ->
          {DateTime.to_date(localized_datetime),
           context.local_tz |> Oli.DateTime.now!() |> DateTime.to_date()}
      end

    case {Timex.diff(localized_end_date, today, :days), scheduling_type} do
      {0, :read_by} ->
        "Suggested for Today"

      {0, _scheduling_type} ->
        "Due Today"

      {1, _scheduling_type} ->
        "1 day left"

      {-1, :read_by} ->
        "Past suggested date by a day"

      {-1, _scheduling_type} ->
        "Past Due by a day"

      {days, :read_by} when days < 0 ->
        "Past suggested date by #{abs(days)} days"

      {days, _scheduling_type} when days < 0 ->
        "Past Due by #{abs(days)} days"

      {days, _scheduling_type} ->
        "#{days} days left"
    end
  end

  @doc """
  Calculates and formats the percentage score based on the given score and out_of value.

  Returns `nil` if the score is `nil`.

  ## Examples

      iex> parse_percentage(45, 50)
      "90%"

      iex> parse_percentage(nil, 50)
      nil
  """
  @spec parse_percentage(number() | nil, number() | nil) :: String.t() | nil
  def parse_percentage(nil, _), do: nil

  def parse_percentage(score, out_of), do: parse_score(score / out_of * 100)

  @doc """
  Rounds a given score to two decimal places and converts it to an integer if the result is a whole number.

  ## Parameters:
  - `score`: The floating-point number representing a score.

  ## Returns:
  - Either a floating-point number or an integer, depending on whether rounding results in a whole number.

  ## Examples:
      iex> parse_score(84.236)
      84.24
      iex> parse_score(85.00)
      85
  """
  @spec parse_score(float()) :: float() | integer()
  def parse_score(score) do
    score = Float.round(score, 2)

    if trunc(score) == score do
      trunc(score)
    else
      score
    end
  end

  def format_score(nil), do: "--"
  def format_score(v), do: parse_score(v)

  @doc """
  Evaluates if an attempt is expired based on the attempt state and the time limit, late submission policy, and end date.
  An attempt can expire if its state is :active and either has a time limit and/or disallows late submissions.
  """
  @spec attempt_expires?(atom(), integer(), atom(), DateTime.t()) :: boolean()
  def attempt_expires?(state, time_limit, late_submit, end_date) do
    case {state, time_limit, late_submit, end_date} do
      {state, _time_limit, _late_submit, _end_date} when state != :active ->
        false

      {:active, 0, :allow, _end_date} ->
        false

      {:active, time_limit, _late_submit, _end_date} when time_limit > 0 ->
        true

      {:active, _time_limit, :disallow, end_date} when end_date != nil ->
        true

      {_, _, _, _} ->
        false
    end
  end

  @doc """
    Calculates the effective expiration date for an attempt based on the inserted date, time limit, late submission policy, and end date.

    ## Parameters:
    - `inserted_at`: The `DateTime` representing the time the attempt was inserted (when the attempt started).
    - `time_limit`: The time limit in minutes for the attempt.
    - `late_submit`: The policy for late submission, either `:allow` or `:disallow`.
    - `end_date`: The `DateTime` representing the end date of the resource.

    ## Returns:
    - The effective expiration date for the attempt, which is the earlier of the time limit expiration and the end date (for the case late submissions are not allowed).

    ## Examples:
        iex> effective_attempt_expiration_date(~U[2024-05-12T00:00:00Z], 60, :allow, ~U[2024-05-12T00:30:00Z])
        ~U[2024-05-12 01:00:00Z]
        iex> effective_attempt_expiration_date(~U[2024-05-12T00:00:00Z], 60, :disallow, ~U[2024-05-12T00:30:00Z])
        ~U[2024-05-12 00:30:00Z]
        iex> effective_attempt_expiration_date(~U[2024-05-12T00:00:00Z], 15, :disallow, ~U[2024-05-12T00:30:00Z])
        ~U[2024-05-12 00:15:00Z]
  """
  @spec effective_attempt_expiration_date(DateTime.t(), integer(), atom(), DateTime.t()) ::
          DateTime.t()
  def effective_attempt_expiration_date(inserted_at, time_limit, late_submit, end_date) do
    case {inserted_at, time_limit, late_submit, end_date} do
      {_inserted_at, 0, :disallow, end_date} ->
        end_date

      {inserted_at, time_limit, :allow, _end_date} when time_limit > 0 ->
        Timex.shift(inserted_at, minutes: time_limit)

      {inserted_at, time_limit, :disallow, end_date} when time_limit > 0 ->
        datetime_with_limit = Timex.shift(inserted_at, minutes: time_limit)

        if DateTime.compare(datetime_with_limit, end_date) == :lt,
          do: datetime_with_limit,
          else: end_date
    end
  end

  @doc """
  Calculates the time remaining from the current moment until a specified end date
  and formats it as "DD:HH:MM:SS" or "HH:MM:SS" depending on the duration.

  ## Parameters
  - `end_date`: The resource `end_date` as a `DateTime`.

  ## Returns
  - A string representing the formatted time remaining as "DD:HH:MM:SS" or "HH:MM:SS". If the time difference is negative, it returns "00:00:00".

  ## Examples
      iex> format_time_remaining(Timex.shift(Timex.now(), seconds: 3661))
      "01:01:01"
      iex> format_time_remaining(Timex.shift(Timex.now(), seconds: 266460))
      "03:02:01:00"
  """

  @spec format_time_remaining(DateTime.t()) :: String.t()
  def format_time_remaining(end_date) do
    # Get the current time
    current_time = Oli.DateTime.utc_now()

    # Calculate the difference in seconds, clamp negative values to 0
    diff_seconds =
      Timex.diff(end_date, current_time, :seconds)
      |> max(0)

    # Calculate days, hours, minutes and seconds
    days = div(diff_seconds, 86400)
    hours = div(rem(diff_seconds, 86400), 3600)
    minutes = div(rem(diff_seconds, 3600), 60)
    seconds = rem(diff_seconds, 60)

    # Format the duration based on the number of days remaining (DD:HH:MM:SS or HH:MM:SS)
    days_parsed =
      (days
       |> Integer.to_string()
       |> String.pad_leading(2, "0")) <>
        ":"

    if(days > 0, do: days_parsed, else: "") <>
      (hours
       |> Integer.to_string()
       |> String.pad_leading(2, "0")) <>
      ":" <>
      (minutes
       |> Integer.to_string()
       |> String.pad_leading(2, "0")) <>
      ":" <>
      (seconds
       |> Integer.to_string()
       |> String.pad_leading(2, "0"))
  end

  attr :bib_app_params, :map, required: true
  attr :ctx, :map, required: true

  def references(assigns) do
    ~H"""
    <div class="content">
      {OliWeb.Common.React.component(@ctx, "Components.References", @bib_app_params, id: "references")}
    </div>
    """
  end

  attr :attempt_message, :any

  def blocking_gates_warning(assigns) do
    ~H"""
    <div id="blocking_gates_warning" class="container">
      <div class="grid grid-cols-12">
        <div class="col-span-12 text-center pt-4">
          <p><i class="far fa-hand-paper" aria-hidden="true" style="font-size: 64px"></i></p>
          <h2 class="mt-4 mb-4">This Resource is Gated</h2>
          <p>
            You are trying to access a resource that is gated by the following condition{if Enum.count(
                                                                                              @attempt_message
                                                                                            ) >
                                                                                              1,
                                                                                            do: "s",
                                                                                            else: ""}:
            <ul style="list-style-position: inside">
              <li :for={reason <- @attempt_message}>{reason}</li>
            </ul>
          </p>

          <p class="mt-4">
            If you think this is an error or would like more information, please <OliWeb.Components.Common.tech_support_link
              id="tech_support_lti_error"
              class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline text-base font-['Open Sans'] tracking-tight cursor-pointer"
            >
              contact support
            </OliWeb.Components.Common.tech_support_link>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def coalesce(first, second) do
    case {first, second} do
      {nil, nil} -> nil
      {nil, s} -> s
      {f, _s} -> f
    end
  end

  def is_adaptive_page(%Oli.Resources.Revision{content: %{"advancedDelivery" => true}}), do: true
  def is_adaptive_page(_), do: false

  @doc """
  Returns the grouped agenda resources for a section and user considering if the section is scheduled or not.
  - If it is scheduled, returns the schedule for the current week and the next week.
  - If it is not scheduled, returns the first incomplete chunk of the agenda.
  Each chunk is a list of 6 container groups, ordered by the order they appear in the curriculum.
  Incomplete chunk means that at least one container group has a progress != 100.0
  """
  def grouped_agenda_resources(
        section,
        combined_settings,
        current_user_id,
        true = _has_scheduled_resources?
      ) do
    Sections.get_schedule_for_current_and_next_week(
      section,
      combined_settings,
      current_user_id
    )
  end

  def grouped_agenda_resources(
        section,
        combined_settings,
        current_user_id,
        false = _has_scheduled_resources?
      ) do
    %{{nil, nil} => sorted_container_groups} =
      Sections.get_not_scheduled_agenda(section, combined_settings, current_user_id)

    %{{nil, nil} => get_first_incomplete_chunk(sorted_container_groups)}
  end

  defp get_first_incomplete_chunk(sorted_container_groups, chunk_size \\ 6) do
    # returns the first chunk that has a group with progress != 100.0
    # if all chunks have groups with progress == 100.0, returns an empty list
    # this is used to determine which chunk to display in the agenda when the section is not scheduled

    sorted_container_groups
    |> Enum.chunk_every(chunk_size)
    |> Enum.find([], fn chunk ->
      Enum.any?(chunk, fn group -> group.progress != 100.0 end)
    end)
  end

  defp build_page_link_params(section_slug, page, request_path, selected_view) do
    current_page_path =
      lesson_live_path(section_slug, page.slug,
        request_path: request_path,
        selected_view: selected_view
      )

    [
      request_path: current_page_path,
      selected_view: selected_view
    ]
  end

  @doc """
  Parses the enrollment status and returns a human-readable string.
  """

  @spec parse_enrollment_status(atom()) :: String.t()
  def parse_enrollment_status(:enrolled), do: "Enrolled"
  def parse_enrollment_status(:suspended), do: "Suspended"
  def parse_enrollment_status(:pending_confirmation), do: "Pending confirmation"
  def parse_enrollment_status(:rejected), do: "Rejected invitation"
  def parse_enrollment_status(_status), do: "Unknown"

  @doc """
  Parses the certificate status and returns a human-readable string.
  """
  @spec parse_certificate_status(atom()) :: String.t()
  def parse_certificate_status(:earned), do: "Approved"
  def parse_certificate_status(:denied), do: "Denied"
  def parse_certificate_status(_), do: "In Progress"

  def emit_page_viewed_event(socket) do
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
