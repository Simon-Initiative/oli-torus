defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile do
  @moduledoc """
  Minimal Student Support tile for architecture validation in `MER-5252`.
  """

  use OliWeb, :live_component

  @bucket_colors %{
    "struggling" => "#D95D39",
    "on_track" => "#2176AE",
    "excelling" => "#2A9D8F",
    "not_enough_information" => "#94A3B8"
  }

  @impl Phoenix.LiveComponent
  def render(assigns) do
    projection = Map.get(assigns, :projection, %{})
    tile_state = Map.get(assigns, :tile_state, %{})
    selected_bucket_id = selected_bucket_id(projection, tile_state)
    buckets = Map.get(projection, :buckets, [])
    selected_bucket = Enum.find(buckets, &(&1.id == selected_bucket_id))
    selected_filter = Map.get(tile_state, :selected_activity_filter, :all)
    search_term = Map.get(tile_state, :search_term, "")
    visible_count = Map.get(tile_state, :visible_count, 20)
    filtered_students = filter_students(selected_bucket, selected_filter, search_term)
    visible_students = Enum.take(filtered_students, visible_count)
    remaining_count = max(length(filtered_students) - length(visible_students), 0)

    assigns =
      assigns
      |> assign(:bucket_colors, @bucket_colors)
      |> assign(:projection, projection)
      |> assign(:buckets, buckets)
      |> assign(:selected_bucket_id, selected_bucket_id)
      |> assign(:selected_bucket, selected_bucket)
      |> assign(:selected_filter, selected_filter)
      |> assign(:search_term, search_term)
      |> assign(:visible_students, visible_students)
      |> assign(:remaining_count, remaining_count)
      |> assign(:chart_spec, build_chart_spec(buckets, selected_bucket_id))

    ~H"""
    <article
      id="learning-dashboard-student-support-tile"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-4 flex items-start justify-between gap-4">
        <div>
          <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Student Support</h3>
          <p class="mt-1 max-w-[32rem] text-sm leading-5 text-Text-text-low">
            Filter students by progress and proficiency to identify who needs support or is excelling.
          </p>
        </div>
        <span class="rounded-md border border-Border-border-default bg-Background-bg-primary px-2 py-1 text-xs font-semibold leading-4 text-Text-text-low-alpha">
          Phase 1
        </span>
      </div>

      <%= cond do %>
        <% not projection_ready?(@projection) -> %>
          <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            Loading student support data...
          </div>
        <% no_activity?(@projection) -> %>
          <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            Student support insights will appear once students begin engaging. Students with no activity
            will appear with an inactivity indicator once the course begins.
          </div>
        <% true -> %>
          <div class="grid gap-4 xl:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]">
            <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-4">
              <div
                id={"student-support-chart-#{@id}"}
                phx-hook="StudentSupportChart"
                data-spec={Jason.encode!(@chart_spec)}
                data-chart-target={"student-support-chart-canvas-#{@id}"}
                class="min-h-[240px]"
              >
                <div
                  id={"student-support-chart-canvas-#{@id}"}
                  phx-update="ignore"
                  class="min-h-[240px]"
                >
                </div>
              </div>

              <div class="mt-4 space-y-2">
                <%= for bucket <- @buckets do %>
                  <.link
                    patch={tile_patch_path(assigns, %{"bucket" => bucket.id, "page" => 1})}
                    data-bucket-id={bucket.id}
                    class={[
                      "flex w-full items-center justify-between rounded-lg border px-3 py-2 text-left transition",
                      bucket.id == @selected_bucket_id &&
                        "border-Border-border-bold bg-Surface-surface-secondary",
                      bucket.id != @selected_bucket_id &&
                        "border-Border-border-subtle bg-Surface-surface-primary hover:bg-Surface-surface-secondary"
                    ]}
                  >
                    <span class="flex items-center gap-3">
                      <span
                        class="h-3 w-3 rounded-full"
                        style={"background-color: #{Map.get(@bucket_colors, bucket.id, "#94A3B8")}"}
                      >
                      </span>
                      <span>
                        <span class="block text-sm font-semibold text-Text-text-high">
                          {bucket.label}
                        </span>
                        <span class="block text-xs text-Text-text-low">
                          {bucket.count} students · {Float.round(bucket.pct * 100.0, 1)}%
                        </span>
                      </span>
                    </span>
                  </.link>
                <% end %>
              </div>
            </div>

            <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-4">
              <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-Text-text-high">
                    {bucket_title(@selected_bucket)}
                  </p>
                  <p class="text-xs text-Text-text-low">
                    {length(@visible_students) + @remaining_count} students in this bucket · {selected_bucket_pct(
                      @selected_bucket
                    )}
                  </p>
                </div>
                <div class="flex items-center gap-2">
                  <.filter_button
                    current={@selected_filter}
                    value="all"
                    count={activity_count(@selected_bucket, :all)}
                    patch_path={tile_patch_path(assigns, %{"filter" => "all", "page" => 1})}
                  />
                  <.filter_button
                    current={@selected_filter}
                    value="active"
                    count={activity_count(@selected_bucket, :active)}
                    patch_path={tile_patch_path(assigns, %{"filter" => "active", "page" => 1})}
                  />
                  <.filter_button
                    current={@selected_filter}
                    value="inactive"
                    count={activity_count(@selected_bucket, :inactive)}
                    patch_path={tile_patch_path(assigns, %{"filter" => "inactive", "page" => 1})}
                  />
                </div>
              </div>

              <form phx-change="student_support_search_changed">
                <input
                  type="text"
                  name="value"
                  value={@search_term}
                  phx-debounce="300"
                  placeholder="Search students"
                  class="mb-3 w-full rounded-md border border-Border-border-default bg-Surface-surface-primary px-3 py-2 text-sm text-Text-text-high"
                />
              </form>

              <div class="space-y-2">
                <%= for student <- @visible_students do %>
                  <div class="flex items-center justify-between rounded-lg border border-Border-border-subtle bg-Surface-surface-primary px-3 py-2">
                    <div>
                      <p class="text-sm font-semibold text-Text-text-high">{student.display_name}</p>
                      <p class="text-xs text-Text-text-low">
                        {student.email} · {format_pct(student.progress_pct)} progress · {format_pct(
                          student.proficiency_pct
                        )} proficiency
                      </p>
                    </div>
                    <span class={[
                      "rounded-full px-2 py-1 text-xs font-semibold",
                      student.activity_status == :inactive &&
                        "bg-[#FEE2E2] text-[#B91C1C]",
                      student.activity_status == :active &&
                        "bg-[#DCFCE7] text-[#166534]"
                    ]}>
                      {student.activity_status}
                    </span>
                  </div>
                <% end %>
              </div>

              <%= if @visible_students == [] do %>
                <div class="rounded-lg border border-dashed border-Border-border-default p-4 text-sm text-Text-text-low">
                  No students match this filter.
                </div>
              <% end %>

              <%= if @remaining_count > 0 do %>
                <.link
                  patch={
                    tile_patch_path(assigns, %{
                      "page" => Map.get(assigns.tile_state, :page, 1) + 1
                    })
                  }
                  data-role="load-more"
                  class="mt-3 rounded-md border border-Border-border-default px-3 py-2 text-sm font-semibold text-Text-text-high"
                >
                  Load more ({@remaining_count})
                </.link>
              <% end %>
            </div>
          </div>
      <% end %>
    </article>
    """
  end

  attr :current, :atom, required: true
  attr :value, :string, required: true
  attr :count, :integer, required: true
  attr :patch_path, :string, required: true

  defp filter_button(assigns) do
    atom_value = String.to_existing_atom(assigns.value)
    assigns = assign(assigns, :atom_value, atom_value)

    ~H"""
    <.link
      patch={@patch_path}
      data-filter={@value}
      class={[
        "rounded-md border px-3 py-1.5 text-xs font-semibold transition",
        @current == @atom_value &&
          "border-Border-border-bold bg-Surface-surface-secondary text-Text-text-high",
        @current != @atom_value &&
          "border-Border-border-subtle bg-Surface-surface-primary text-Text-text-low"
      ]}
    >
      {String.capitalize(String.replace(@value, "_", " "))} ({@count})
    </.link>
    """
  end

  defp selected_bucket_id(projection, tile_state) do
    selected_bucket_id = Map.get(tile_state, :selected_bucket_id)
    bucket_ids = projection |> Map.get(:buckets, []) |> Enum.map(& &1.id)

    cond do
      selected_bucket_id in bucket_ids -> selected_bucket_id
      true -> Map.get(projection, :default_bucket_id)
    end
  end

  defp filter_students(nil, _selected_filter, _search_term), do: []

  defp filter_students(bucket, selected_filter, search_term) do
    bucket
    |> Map.get(:students, [])
    |> maybe_filter_by_activity(selected_filter)
    |> maybe_filter_by_search(search_term)
  end

  defp maybe_filter_by_activity(students, :all), do: students

  defp maybe_filter_by_activity(students, filter) do
    Enum.filter(students, &(&1.activity_status == filter))
  end

  defp maybe_filter_by_search(students, ""), do: students

  defp maybe_filter_by_search(students, search_term) do
    query = String.downcase(search_term)

    Enum.filter(students, fn student ->
      String.contains?(String.downcase(student.display_name), query) or
        String.contains?(String.downcase(student.email || ""), query)
    end)
  end

  defp build_chart_spec(buckets, selected_bucket_id) do
    # Phase 1 intentionally ships a minimal chart spec for renderer and interaction
    # validation. Final visual fidelity is deferred to the follow-up UI slice.
    values =
      Enum.map(buckets, fn bucket ->
        %{
          bucket_id: bucket.id,
          label: bucket.label,
          count: bucket.count,
          pct: Float.round(bucket.pct * 100.0, 1),
          selected: bucket.id == selected_bucket_id
        }
      end)

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "width" => 240,
      "height" => 240,
      "data" => %{"values" => values},
      "view" => %{"stroke" => nil},
      "encoding" => %{
        "theta" => %{"field" => "count", "type" => "quantitative"},
        "color" => %{
          "field" => "bucket_id",
          "type" => "nominal",
          "legend" => nil,
          "scale" => %{
            "domain" => Map.keys(@bucket_colors),
            "range" => Map.values(@bucket_colors)
          }
        },
        "opacity" => %{
          "condition" => %{"test" => "datum.selected", "value" => 1},
          "value" => 0.45
        },
        "tooltip" => [
          %{"field" => "label", "type" => "nominal", "title" => "Bucket"},
          %{"field" => "count", "type" => "quantitative", "title" => "Students"},
          %{"field" => "pct", "type" => "quantitative", "title" => "Percent"}
        ]
      },
      "mark" => %{
        "type" => "arc",
        "innerRadius" => 64,
        "outerRadius" => 108,
        "stroke" => "#FFFFFF",
        "strokeWidth" => 2
      }
    }
  end

  defp projection_ready?(projection) do
    is_map(projection) and Map.has_key?(projection, :buckets) and
      Map.has_key?(projection, :has_activity_data?)
  end

  defp no_activity?(projection), do: Map.get(projection, :has_activity_data?) == false

  defp bucket_title(nil), do: "Student list"
  defp bucket_title(bucket), do: bucket.label

  defp activity_count(nil, _status), do: 0
  defp activity_count(bucket, :all), do: bucket.count
  defp activity_count(bucket, :active), do: Map.get(bucket, :active_count, 0)
  defp activity_count(bucket, :inactive), do: Map.get(bucket, :inactive_count, 0)

  defp format_pct(nil), do: "N/A"
  defp format_pct(value), do: "#{Float.round(value, 1)}%"

  defp selected_bucket_pct(nil), do: "0.0%"
  defp selected_bucket_pct(bucket), do: "#{Float.round(Map.get(bucket, :pct, 0.0) * 100.0, 1)}%"

  defp tile_patch_path(assigns, updates) do
    params =
      assigns
      |> Map.get(:params, %{})
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)

    tile_support =
      params
      |> Map.get("tile_support", %{})
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(updates)
      |> Enum.reject(fn
        {"page", 1} -> true
        {"page", "1"} -> true
        {"filter", "all"} -> true
        {"q", ""} -> true
        {_key, nil} -> true
        _ -> false
      end)
      |> Map.new()

    params =
      if map_size(tile_support) == 0 do
        Map.delete(params, "tile_support")
      else
        Map.put(params, "tile_support", tile_support)
      end

    OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab.path_for_section(
      assigns.section_slug,
      assigns.dashboard_scope,
      params
    )
  end
end
