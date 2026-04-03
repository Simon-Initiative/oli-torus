defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.AssessmentsTile do
  @moduledoc """
  Assessments tile surface for `MER-5254`.
  """

  use OliWeb, :live_component

  alias Oli.InstructorDashboard.Oracles.Grades

  alias OliWeb.Components.DesignTokens.Primitives.Button

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportEmailModal
  alias OliWeb.Delivery.ScoreDisplay
  alias OliWeb.Delivery.ScheduleDisplay

  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    projection = Map.get(assigns, :projection, socket.assigns[:projection] || %{})
    rows = Map.get(projection, :rows, [])

    expanded_assessment_id =
      assigns
      |> Map.get(:expanded_assessment_id, socket.assigns[:expanded_assessment_id])
      |> normalize_expanded_id(rows)

    ctx = Map.get(assigns, :ctx, socket.assigns[:ctx])
    section_slug = Map.get(assigns, :section_slug, socket.assigns[:section_slug])

    email_recipients =
      Map.get(assigns, :email_recipients, socket.assigns[:email_recipients] || [])

    email_assessment = Map.get(assigns, :email_assessment, socket.assigns[:email_assessment])

    show_email_modal =
      Map.get(assigns, :show_email_modal, socket.assigns[:show_email_modal] || false)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:projection, projection)
     |> assign(:rows, rows)
     |> assign(:ctx, ctx)
     |> assign(:section_slug, section_slug)
     |> assign(:email_recipients, email_recipients)
     |> assign(:email_assessment, email_assessment)
     |> assign(:show_email_modal, show_email_modal)
     |> assign(:expanded_assessment_id, expanded_assessment_id)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <article
      id="learning-dashboard-assessments-tile"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-[6px] space-y-[6px]">
        <div class="flex items-start justify-between gap-4 px-1 pb-2">
          <div class="flex items-center gap-2">
            <Icons.assignments is_active={false} />
            <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Assessments</h3>
          </div>

          <%= if @section_slug do %>
            <.link
              navigate={
                Routes.live_path(
                  OliWeb.Endpoint,
                  OliWeb.Grades.GradebookView,
                  @section_slug
                )
              }
              class="pt-1 text-sm font-bold leading-4 text-Text-text-button hover:underline"
            >
              View Assessment Scores
            </.link>
          <% end %>
        </div>

        <p class="max-w-[583px] text-sm font-normal leading-6 text-Text-text-low">
          Track assessment completion and performance.
        </p>
      </div>

      <%= cond do %>
        <% not projection_ready?(@projection) -> %>
          <div class="rounded-xl border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            {status_message(@status)}
          </div>
        <% @rows == [] -> %>
          <div class="rounded-xl border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            No scored assessments were found for the current dashboard scope.
          </div>
        <% true -> %>
          <div class="space-y-[6px]">
            <div class="space-y-[6px]">
              <%= for row <- @rows do %>
                <div
                  id={"learning-dashboard-assessment-card-#{row.assessment_id}"}
                  class={[
                    "group relative overflow-hidden rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] transition-colors",
                    !expanded?(@expanded_assessment_id, row.assessment_id) &&
                      "hover:bg-Surface-surface-secondary-hover"
                  ]}
                >
                  <button
                    type="button"
                    phx-click="assessment_row_toggled"
                    phx-value-assessment_id={row.assessment_id}
                    class="flex min-h-[112px] w-full items-start justify-between gap-5 rounded-xl px-[15px] py-[15px] text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-Fill-Buttons-fill-primary"
                    aria-expanded={expanded?(@expanded_assessment_id, row.assessment_id)}
                    aria-controls={"assessment-details-#{row.assessment_id}"}
                    aria-label={
                      disclosure_label(
                        row.title,
                        expanded?(@expanded_assessment_id, row.assessment_id)
                      )
                    }
                  >
                    <div class="min-w-0 flex-1 space-y-3">
                      <p
                        :if={row.context_label}
                        class="flex flex-wrap items-center gap-2 text-[12px] font-bold uppercase leading-3 text-Text-text-low-alpha"
                      >
                        {formatted_context_label(row.context_label)}
                      </p>

                      <div class="space-y-[10px]">
                        <p class="break-words pr-2 text-[18px] font-semibold leading-6 text-Text-text-high">
                          {row.title}
                        </p>

                        <div class="flex flex-wrap items-center gap-x-6 gap-y-1 text-[12px] font-semibold leading-3">
                          <span class="text-Text-text-high">
                            Available:
                            <span class="ml-1 text-Text-text-low-alpha">
                              {display_available_date(row.available_at, @ctx)}
                            </span>
                          </span>
                          <span class="text-Text-text-high">
                            Due:
                            <span class="ml-1 text-Text-text-low-alpha">
                              {display_due_date(row.due_at, @ctx)}
                            </span>
                          </span>
                        </div>
                      </div>
                    </div>

                    <Icons.chevron_down class={
                        "mt-[2px] h-6 w-6 shrink-0 stroke-Text-text-high transition-transform" <>
                          if(expanded?(@expanded_assessment_id, row.assessment_id),
                            do: " rotate-180",
                            else: ""
                          )
                      } />
                  </button>

                  <div
                    :if={expanded?(@expanded_assessment_id, row.assessment_id)}
                    id={"assessment-details-#{row.assessment_id}"}
                    class="px-4 pb-8 pt-[2px]"
                  >
                    <div class="flex flex-col items-start gap-4">
                      <.completion_status_badge completion={row.completion} />

                      <button
                        type="button"
                        phx-click="open_assessment_email_modal"
                        phx-target={@myself}
                        phx-value-assessment_id={row.assessment_id}
                        class="inline-flex items-center justify-center gap-1 rounded-md py-1 text-sm font-semibold leading-4 text-Text-text-button transition hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                      >
                        <Icons.email class="h-4 w-4 stroke-current" /> Email Students Not Completed
                      </button>

                      <div class="w-full pt-8">
                        <div class="mx-auto flex w-full max-w-[666px] flex-col items-start gap-4">
                          <div class="flex w-full items-end gap-5">
                            <div class="flex w-[19px] shrink-0 flex-col items-center gap-[6px] pb-[34px]">
                              <div class="flex h-[138px] items-center justify-center">
                                <span class="rotate-180 text-sm font-semibold leading-4 text-Text-text-low [writing-mode:vertical-rl]">
                                  # of Students
                                </span>
                              </div>
                              <span class="inline-flex h-[19px] w-[19px] rotate-[-90deg] items-center justify-center rounded-[3px] bg-Background-bg-primary text-sm font-semibold leading-4 text-Text-text-high">
                                Y
                              </span>
                            </div>

                            <div class="min-w-0 flex-1">
                              <div
                                class="relative"
                                role="img"
                                aria-label={histogram_aria_label(row)}
                              >
                                <div class="absolute inset-x-0 bottom-[34px] border-t border-Border-border-hover">
                                </div>

                                <% histogram_max_count = histogram_max_count(row.histogram_bins) %>
                                <div class="grid h-[242px] grid-cols-10 items-end gap-[4px] pb-[19px]">
                                  <%= for bin <- row.histogram_bins do %>
                                    <div class="relative flex h-full items-end justify-center">
                                      <div
                                        class="relative flex w-full items-end justify-center"
                                        style={bar_style(bin.count, histogram_max_count)}
                                      >
                                        <p
                                          :if={bin.count > 0}
                                          class="absolute bottom-full mb-2 inline-flex min-h-[22px] min-w-[26px] items-center justify-center rounded-[2px] border border-Border-border-hover bg-Background-bg-primary px-2 py-1 text-sm font-normal leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
                                        >
                                          {bin.count}
                                        </p>
                                        <div class="-mb-px h-full w-full rounded-t-[3px] bg-Icon-icon-default shadow-[0px_1px_2px_0px_rgba(0,0,0,0.18)]">
                                        </div>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>

                                <div class="grid grid-cols-11 gap-[4px] text-center text-sm font-semibold leading-4 text-Text-text-high">
                                  <%= for tick <- 0..10 do %>
                                    <p>{tick * 10}</p>
                                  <% end %>
                                </div>
                              </div>
                            </div>
                          </div>

                          <div class="flex w-full justify-start pl-[40px]">
                            <div class="flex items-center gap-[6px] text-sm font-semibold leading-4 text-Text-text-high">
                              <span class="inline-flex h-[19px] w-[19px] items-center justify-center rounded-[3px] bg-Background-bg-primary text-sm leading-4 text-Text-text-high">
                                X
                              </span>
                              <span class="font-normal">Scores</span>
                            </div>
                          </div>

                          <div class="flex w-full flex-wrap items-center justify-center gap-1 pt-[6px]">
                            <.metric
                              label="Minimum"
                              value={format_metric(row.metrics.minimum)}
                              accent_class={metric_card_class(:minimum, row.completion.status)}
                            />
                            <.metric
                              label="Median"
                              value={format_metric(row.metrics.median)}
                              accent_class={metric_card_class(:median, row.completion.status)}
                            />
                            <.metric
                              label="Mean"
                              value={format_metric(row.metrics.mean)}
                              accent_class={metric_card_class(:mean, row.metrics.mean)}
                            />
                            <.metric
                              label="Maximum"
                              value={format_metric(row.metrics.maximum)}
                              accent_class={metric_card_class(:maximum, row.completion.status)}
                            />
                            <.metric
                              label="Std Dev"
                              value={format_metric(row.metrics.standard_deviation)}
                              accent_class={
                                metric_card_class(:standard_deviation, row.completion.status)
                              }
                            />
                          </div>

                          <div class="flex w-full justify-center pt-3">
                            <%= if @section_slug && row.review_resource_id do %>
                              <.link
                                navigate={
                                  Routes.live_path(
                                    OliWeb.Endpoint,
                                    OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                                    @section_slug,
                                    :insights,
                                    :scored_pages,
                                    row.review_resource_id
                                  )
                                }
                                class="inline-flex min-w-[181px] items-center justify-center rounded-md border border-Border-border-bold bg-transparent px-6 py-2 text-sm font-semibold leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] transition hover:bg-Surface-surface-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                              >
                                Review Questions
                              </.link>
                            <% else %>
                              <Button.button
                                variant={:secondary}
                                size={:sm}
                                class="min-w-[181px] justify-center bg-transparent"
                              >
                                Review Questions
                              </Button.button>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <.live_component
              :if={@show_email_modal}
              id={"assessments_email_modal_#{@id}"}
              module={StudentSupportEmailModal}
              students={@email_recipients}
              section_title={@section_title}
              instructor_email={@instructor_email}
              instructor_name={@instructor_name}
              section_slug={@section_slug}
              show_modal={@show_email_modal}
              email_handler_id={@id}
              modal_dom_id={"student_support_email_modal_#{@id}"}
              default_subject={email_default_subject(@email_assessment)}
              default_body=""
            />
          </div>
      <% end %>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :accent_class, :string, default: nil

  defp metric(assigns) do
    ~H"""
    <div class={[
      "flex h-[68px] w-[68px] flex-col items-center justify-center rounded-[3px] border px-2 py-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]",
      @accent_class || "border-Border-border-subtle bg-Specially-Tokens-Border-border-card-completed"
    ]}>
      <p class="text-base font-bold leading-6 text-Text-text-high">{@value}</p>
      <p class="text-center text-xs font-normal leading-3 text-Text-text-high">{@label}</p>
    </div>
    """
  end

  attr :completion, :map, required: true

  defp completion_status_badge(assigns) do
    assigns = assign(assigns, :parts, completion_status_parts(assigns.completion))

    ~H"""
    <span class={[
      "inline-flex h-[25px] items-center rounded-[12px] px-3 py-1 text-[14px] font-normal leading-6 text-Text-text-high",
      completion_chip_class(@completion.status)
    ]}>
      <%= case @parts do %>
        <% %{prefix: prefix, value: value, suffix: suffix} -> %>
          <span>{prefix}<span class="font-bold">{value}</span>{suffix}</span>
        <% %{label: label} -> %>
          {label}
      <% end %>
    </span>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("open_assessment_email_modal", %{"assessment_id" => assessment_id}, socket) do
    with {parsed_assessment_id, ""} <- Integer.parse(assessment_id),
         true <- is_integer(socket.assigns[:section_id]),
         assessment when not is_nil(assessment) <-
           Enum.find(socket.assigns.rows, &(&1.assessment_id == parsed_assessment_id)) do
      case Grades.students_without_attempt_emails(
             socket.assigns.section_id,
             parsed_assessment_id
           ) do
        {:ok, recipients} ->
          {:noreply,
           socket
           |> assign(:email_assessment, assessment)
           |> assign(:email_recipients, recipients)
           |> assign(:show_email_modal, true)}

        _ ->
          send(self(), {:flash_message, {:error, "Could not load assessment email recipients"}})

          {:noreply,
           socket
           |> assign(:email_assessment, assessment)
           |> assign(:email_recipients, [])
           |> assign(:show_email_modal, true)}
      end
    else
      false ->
        {:noreply, socket}

      nil ->
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp projection_ready?(projection) do
    is_map(projection) and Map.has_key?(projection, :has_assessments?)
  end

  defp status_message("unavailable"), do: "Assessments data is unavailable right now."
  defp status_message(_status), do: "Loading assessments data..."

  defp normalize_expanded_id(current_id, rows) when is_integer(current_id) do
    if Enum.any?(rows, &(&1.assessment_id == current_id)), do: current_id, else: nil
  end

  defp normalize_expanded_id(_current_id, _rows), do: nil

  defp expanded?(expanded_assessment_id, assessment_id),
    do: expanded_assessment_id == assessment_id

  defp completion_chip_class(:good),
    do: "border border-Fill-Accent-fill-accent-green-bold bg-Fill-Chip-Green"

  defp completion_chip_class(:bad), do: "border border-Icon-icon-danger bg-Fill-fill-danger"
  defp completion_chip_class(_status), do: "border border-Border-border-subtle bg-Fill-Chip-Gray"

  defp metric_card_class(:mean, mean_score) do
    case ScoreDisplay.score_status_from_percentage(mean_score) do
      :good -> "border-Fill-Accent-fill-accent-green-bold bg-Fill-Chip-Green"
      :bad -> "border-Icon-icon-danger bg-Fill-fill-danger"
      _status -> "border-Border-border-subtle bg-Specially-Tokens-Border-border-card-completed"
    end
  end

  defp metric_card_class(_metric, _status),
    do: "border-Border-border-subtle bg-Specially-Tokens-Border-border-card-completed"

  defp completion_status_parts(%{
         completed_count: completed_count,
         total_students: total_students
       })
       when is_integer(completed_count) and is_integer(total_students) do
    %{
      prefix: "Status: ",
      value: "#{completed_count}/#{total_students}",
      suffix: " Students Completed"
    }
  end

  defp completion_status_parts(%{label: label}) when is_binary(label), do: %{label: label}
  defp completion_status_parts(_completion), do: %{label: "Status unavailable"}

  defp format_metric(nil), do: "--"
  defp format_metric(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_metric(value), do: to_string(value)

  defp display_available_date(value, ctx),
    do: ScheduleDisplay.available_date(value, ctx)

  defp display_due_date(value, ctx),
    do: ScheduleDisplay.due_date(value, ctx)

  defp email_default_subject(nil), do: "Checking in about your assessment"

  defp email_default_subject(%{title: title}) when is_binary(title),
    do: "Checking in about #{title}"

  defp email_default_subject(_), do: "Checking in about your assessment"

  defp formatted_context_label(context_label) when is_binary(context_label) do
    context_label
    |> String.split(">")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.upcase/1)
    |> Enum.join(" • ")
  end

  defp formatted_context_label(context_label), do: to_string(context_label)

  defp disclosure_label(title, true), do: "Collapse assessment #{title}"
  defp disclosure_label(title, false), do: "Expand assessment #{title}"

  defp histogram_aria_label(%{title: title, histogram_bins: histogram_bins}) do
    summary =
      histogram_bins
      |> Enum.filter(&(Map.get(&1, :count, 0) > 0))
      |> Enum.map_join(", ", fn bin ->
        "#{Map.get(bin, :range, "unknown")} percent: #{Map.get(bin, :count, 0)} students"
      end)

    case summary do
      "" -> "Score distribution for #{title}. No student submissions are available."
      _ -> "Score distribution for #{title}. #{summary}."
    end
  end

  defp histogram_max_count(histogram_bins) do
    histogram_bins
    |> Enum.map(&Map.get(&1, :count, 0))
    |> Enum.max(fn -> 0 end)
  end

  defp bar_style(count, max_count) do
    height_pct =
      case max_count do
        0 -> 0
        _ when count == 0 -> 0
        _ -> Float.round(count / max_count * 100, 1)
      end

    "height: #{height_pct}%;"
  end
end
