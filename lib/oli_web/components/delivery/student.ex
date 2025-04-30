defmodule OliWeb.Components.Delivery.Student do
  use OliWeb, :html

  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.Attempts.HistoricalGradedAttemptSummary
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias OliWeb.Components.Common
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Icons

  attr(:raw_avg_score, :map)

  def score_summary(assigns) do
    ~H"""
    <div :if={@raw_avg_score[:score]} role="score summary" class="flex items-center gap-[6px] ml-auto">
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
        <path
          d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
          class="fill-[#0CAF61] dark:fill-[#12E56A]"
        />
      </svg>
      <span class="text-[12px] leading-[16px] tracking-[0.02px] text-[#0CAF61] dark:text-[#12E56A] font-semibold whitespace-nowrap">
        <%= Utils.parse_score(@raw_avg_score[:score]) %> / <%= Utils.parse_score(
          @raw_avg_score[:out_of]
        ) %>
      </span>
    </div>
    """
  end

  attr(:raw_avg_score, :map)

  def score_as_you_go_summary(assigns) do
    ~H"""
    <div role="score summary" class="flex gap-[6px] ml-auto">
      <Icons.score_as_you_go />
      <span class="text-[12px] leading-[16px] tracking-[0.02px] text-[#0CAF61] dark:text-[#12E56A] font-semibold whitespace-nowrap">
        <%= Utils.format_score(@raw_avg_score[:score]) %> / <%= Utils.format_score(
          @raw_avg_score[:out_of]
        ) %>
      </span>
    </div>
    """
  end

  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)
  attr(:attempts_count, :integer)
  attr(:resource_access, :any, default: nil)
  attr(:attempt_summary, HistoricalGradedAttemptSummary)
  attr(:effective_settings, :map)

  def attempts_dropdown(assigns) do
    assigns = assign(assigns, :id, "page-#{assigns[:page_revision_slug]}-attempts")
    assigns = case assigns[:effective_settings].batch_scoring do
      true -> assign(assigns, :label, "Attempts #{assigns[:attempts_count]}/#{max_attempts(assigns[:effective_settings])}")
      false -> assign(assigns, :label, "Score as you go")
    end
    assigns = case {assigns[:effective_settings].batch_scoring, assigns[:resource_access]} do
      {true, _} -> assign(assigns, :raw_avg_score, %{score: nil, out_of: nil})
      {false, nil} -> assign(assigns, :raw_avg_score, %{score: nil, out_of: nil})
      {false, resource_access} -> case resource_access.score do
        nil -> assign(assigns, :raw_avg_score, %{score: nil, out_of: nil})
        _ -> assign(assigns, :raw_avg_score, %{score: resource_access.score, out_of: resource_access.out_of})
      end
    end

    ~H"""
    <div class="self-stretch justify-start items-start gap-6 inline-flex relative mb-1">
      <button
        id={"#{@id}-dropdown-button"}
        class="opacity-80 dark:text-white text-sm font-bold font-['Open Sans'] uppercase whitespace-nowrap tracking-wider"
        phx-click={show_attempts_dropdown("##{@id}-dropdown", @page_revision_slug)}
        phx-value-hide-target={"##{@id}-dropdown"}
      >
        <div class="flex flex-row gap-1">
          <div>
            <%= @label %>
            <span><i class="fa-solid fa-caret-down"></i></span>
          </div>
        </div>
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"}>
        <Common.loading_spinner :if={
          !@attempt_summary || @attempt_summary.page_revision_slug != @page_revision_slug
        } />
        <.attempts_summary
          :if={(@attempt_summary != nil && @attempt_summary.page_revision_slug == @page_revision_slug) or @label == "Score as you go"}
          ctx={@ctx}
          attempt_summary={@attempt_summary}
          raw_avg_score={@raw_avg_score}
          section_slug={@section_slug}
          effective_settings={@effective_settings}
          page_revision_slug={@page_revision_slug}
        />
      </.dropdown_menu>
    </div>
    """
  end

  defp max_attempts(%{max_attempts: 0}), do: "∞"
  defp max_attempts(%{max_attempts: max_attempts}), do: max_attempts

  attr(:id, :string, required: true)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def dropdown_menu(assigns) do
    ~H"""
    <div
      id={@id}
      class={"hidden absolute top-[50px] right-0 z-50 whitespace-nowrap bg-white dark:bg-black p-2 rounded-lg shadow-lg #{@class}"}
    >
      <ul>
        <%= render_slot(@inner_block) %>
      </ul>
    </div>
    """
  end

  defp show_attempts_dropdown(id, page_revision_slug) do
    %JS{}
    |> JS.toggle(
      to: id,
      in: {"ease-out duration-300", "opacity-0 top-[40px]", "opacity-100"},
      out: {"ease-out duration-300", "opacity-100", "opacity-0 top-[40px]"}
    )
    |> JS.push("load_historical_graded_attempt_summary",
      value: %{page_revision_slug: page_revision_slug}
    )
  end

  defp hide_attempts_dropdown(id) do
    %JS{}
    |> JS.hide(
      to: id,
      transition: {"ease-out duration-300", "opacity-100", "opacity-0 top-[40px]"}
    )
    |> JS.push("clear_historical_graded_attempt_summary")
  end

  attr(:attempt_summary, HistoricalGradedAttemptSummary)
  attr(:effective_settings, :map)
  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:section_slug, :string)
  attr(:raw_avg_score, :map)
  attr(:page_revision_slug, :string)


  defp attempts_summary(%{effective_settings: %{batch_scoring: false}} = assigns) do
    ~H"""
    <div
      id="attempts_summary"
      class="flex flex-col gap-3"
      phx-click-away={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}
    >
      <div class="flex flex-row justify-between p-2">
        <div class="text-sm uppercase">
          Score Information
        </div>
        <button phx-click={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}>
          <i class="fa-solid fa-xmark"></i>
        </button>
      </div>
      <div class="flex flex-row p-2 justify-start vertical-align">
        <div class="mr-2"><strong>SCORE AS YOU GO</strong></div>
        <div>
          <Icons.score_as_you_go />
          <span class="text-[12px] leading-[16px] tracking-[0.02px] text-[#0CAF61] dark:text-[#12E56A] font-semibold whitespace-nowrap">
            <%= Utils.format_score(@raw_avg_score[:score]) %> / <%= Utils.format_score(
              @raw_avg_score[:out_of]
            ) %>
          </span>
        </div>
      </div>
      <div class="flex flex-col p-2">
        <div>Your score is updated as you complete questions on this page.</div>
      </div>
    </div>
    """
  end

  defp attempts_summary(
         %{attempt_summary: %HistoricalGradedAttemptSummary{historical_attempts: []}} = assigns
       ) do
    ~H"""
    <div
      id="attempts_summary"
      class="w-full flex-col justify-start items-start gap-3 flex"
      phx-click-away={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}
    >
      <div class="self-stretch flex-col justify-start items-start flex p-3">
        There are no attempts for this page.
      </div>
    </div>
    """
  end


  defp attempts_summary(assigns) do
    ~H"""
    <div
      id="attempts_summary"
      class="flex flex-col gap-3"
      phx-click-away={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}
    >
      <div class="flex flex-row justify-between p-2">
        <div class="text-sm uppercase">
          Score Information
        </div>
        <button phx-click={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}>
          <i class="fa-solid fa-xmark"></i>
        </button>
      </div>
      <div class="flex flex-col p-2">
        <.attempt_summary
          :for={
            {attempt, index} <-
              @attempt_summary.historical_attempts
              |> Enum.with_index(1)
          }
          index={index}
          section_slug={@section_slug}
          page_revision_slug={@page_revision_slug}
          attempt={attempt}
          ctx={@ctx}
          effective_settings={@effective_settings}
        />
      </div>
    </div>
    """
  end

  attr(:index, :integer)
  attr(:attempt, ResourceAttempt)
  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:effective_settings, :map)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)

  defp attempt_summary(assigns) do
    ~H"""
    <div id={"attempt_#{@index}_summary"} class="py-1">
      <.attempt_details
        ctx={@ctx}
        index={@index}
        attempt={@attempt}
        section_slug={@section_slug}
        page_revision_slug={@page_revision_slug}
        effective_settings={@effective_settings}
      />
    </div>
    """
  end

  attr(:index, :integer)
  attr(:attempt, ResourceAttempt)
  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)
  attr(:effective_settings, :map)

  defp attempt_details(%{attempt: %ResourceAttempt{lifecycle_state: :active}} = assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex flex-row justify-between gap-10 text-xs">
        <div class="flex flex-row gap-10 text-xs font-semibold w-full">
          <div class="font-semibold uppercase text-gray-500 mr-1">Attempt <%= @index %>:</div>
          <div class="ml-auto flex flex-col gap-1 items-end">
            <.time_remaining
              :if={attempt_expires?(@attempt, @effective_settings)}
              end_date={effective_attempt_expiration_date(@attempt, @effective_settings)}
            />
            <div
              :if={allow_review_submission?(@effective_settings)}
              class="w-[124px] justify-end items-center gap-2.5 inline-flex"
            >
              <.link
                href={~p"/sections/#{@section_slug}/lesson/#{@page_revision_slug}"}
                role="review_attempt_link"
              >
                <div class="cursor-pointer hover:opacity-40 text-blue-500 text-xs font-semibold font-['Open Sans'] uppercase tracking-wide">
                  Continue
                </div>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp attempt_details(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex flex-row justify-between gap-10 text-xs">
        <div class="flex flex-row gap-1 text-xs font-semibold text-green-700 dark:text-green-500">
          <div class="font-semibold uppercase text-gray-500 mr-1">Attempt <%= @index %>:</div>
          <div class="w-4 h-4 relative"><Icons.star /></div>

          <div role="attempt score" class="tracking-tight">
            <%= Float.round(@attempt.score, 2) %>
          </div>
          <div class="text-emerald-600">
            /
          </div>
          <div role="attempt out of" class="tracking-tight">
            <%= Float.round(@attempt.out_of, 2) %>
          </div>
        </div>
        <div>
          <%= FormatDateTime.to_formatted_datetime(
            @attempt.date_submitted,
            @ctx,
            "{WDshort} {Mshort} {D}, {YYYY}"
          ) %>
        </div>
      </div>
      <div class="flex flex-row justify-end">
        <div
          :if={allow_review_submission?(@effective_settings)}
          class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex"
        >
          <.link
            href={
              Utils.review_live_path(
                @section_slug,
                @page_revision_slug,
                @attempt.attempt_guid,
                request_path: Utils.schedule_live_path(@section_slug)
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

  defp attempt_expires?(attempt, effective_settings) do
    Utils.attempt_expires?(
      attempt.lifecycle_state,
      effective_settings.time_limit,
      effective_settings.late_submit,
      effective_settings.end_date
    )
  end

  defp effective_attempt_expiration_date(attempt, effective_settings) do
    Utils.effective_attempt_expiration_date(
      attempt.inserted_at,
      effective_settings.time_limit,
      effective_settings.late_submit,
      effective_settings.end_date
    )
  end

  defp allow_review_submission?(%{review_submission: :allow}), do: true
  defp allow_review_submission?(_), do: false

  attr :end_date, :string, required: true

  defp time_remaining(%{end_date: nil} = assigns) do
    ~H"""
    """
  end

  defp time_remaining(assigns) do
    ~H"""
    <div class="w-fit h-4 pl-1 justify-center items-start gap-1 inline-flex">
      <span class="text-xs text-gray-500 mr-1">
        Time Remaining:
      </span>
      <div role="countdown">
        <%= Utils.format_time_remaining(@end_date) %>
      </div>
    </div>
    """
  end

  attr :graded, :boolean, default: false
  attr :duration_minutes, :integer

  def duration_in_minutes(assigns) do
    assigns = Map.put(assigns, :duration_minutes, parse_minutes(assigns.duration_minutes))

    ~H"""
    <div :if={@duration_minutes} class="ml-auto items-center gap-1.5 flex">
      <div :if={@graded} class="w-[22px] h-[22px] opacity-60 flex items-center justify-center">
        <Icons.clock />
      </div>
      <div class="text-right dark:text-white opacity-60 whitespace-nowrap">
        <span class="text-sm font-semibold" role="duration in minutes">
          <%= @duration_minutes %>
          <span class="w-[25px] self-stretch text-[13px] font-semibold">
            min
          </span>
        </span>
      </div>
    </div>
    """
  end

  defp parse_minutes(minutes) when minutes in ["", nil], do: nil
  defp parse_minutes(minutes), do: minutes

  attr :type, :atom, required: true
  attr :long, :boolean, default: true

  def resource_type(%{type: :exploration} = assigns) do
    ~H"""
    <div role="resource_type" aria-label="exploration" class="justify-start items-start flex">
      <div class="px-3 py-1 text-exploration dark:text-exploration-dark bg-[#815499]/[.25] rounded-3xl justify-center items-center gap-1.5 flex">
        <div class="w-5 h-5 relative opacity-80">
          <div class="w-3 h-3.5 absolute">
            <Icons.world />
          </div>
        </div>
        <div :if={@long} class="pr-1 justify-center items-center gap-2.5 flex">
          <div class="text-sm font-semibold tracking-tight">
            Exploration
          </div>
        </div>
      </div>
    </div>
    """
  end

  def resource_type(%{type: :checkpoint} = assigns) do
    ~H"""
    <div role="resource_type" aria-label="checkpoint" class="justify-start items-start flex">
      <div class="px-3 py-1 text-checkpoint dark:text-checkpoint-dark bg-[#B87439]/[.25] rounded-3xl justify-center items-center gap-1.5 flex">
        <div class="w-5 h-5 relative opacity-80">
          <div class="w-3 h-3.5 absolute">
            <Icons.transparent_flag />
          </div>
        </div>
        <div :if={@long} class="pr-1 justify-center items-center gap-2.5 flex">
          <div class="text-sm font-semibold tracking-tight">
            Assignment
          </div>
        </div>
      </div>
    </div>
    """
  end

  def resource_type(%{type: :practice} = assigns) do
    ~H"""
    <div role="resource_type" aria-label="practice" class="justify-start items-start flex">
      <div class="px-3 py-1 text-practice dark:text-practice-dark bg-[#3959B8]/[.25] rounded-3xl justify-center items-center gap-1.5 flex">
        <div class="w-5 h-5 relative opacity-80">
          <div class="w-3 h-3.5 absolute">
            <Icons.clipboard />
          </div>
        </div>
        <div :if={@long} class="pr-1 justify-center items-center gap-2.5 flex">
          <div class="text-sm font-semibold tracking-tight">
            Practice
          </div>
        </div>
      </div>
    </div>
    """
  end

  def resource_type(%{type: :lesson} = assigns) do
    ~H"""
    <div role="resource_type" aria-label="reading" class="justify-start items-start flex">
      <div class="px-3 py-1 text-teal-700 dark:text-[#6DD1DF] bg-[#3E7981]/[.25] rounded-3xl justify-center items-center gap-1.5 flex">
        <div class="w-5 h-5 relative opacity-80">
          <div class="w-3 h-3.5 absolute">
            <Icons.book />
          </div>
        </div>
        <div :if={@long} class="pr-1 opacity-80 justify-center items-center gap-2.5 flex">
          <div class="text-sm font-semibold tracking-tight">
            Lesson
          </div>
        </div>
      </div>
    </div>
    """
  end

  def type_from_resource(%{purpose: :application}), do: :exploration
  def type_from_resource(%{graded: true}), do: :checkpoint
  def type_from_resource(%{graded: false}), do: :practice
  def type_from_resource(_), do: :lesson
end
