defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ChallengingObjectivesTile do
  @moduledoc """
  Challenging Objectives tile for Intelligent Dashboard (`MER-5253`).
  """

  use OliWeb, :html

  alias OliWeb.Icons

  attr :projection, :map, default: nil
  attr :projection_status, :map, default: %{status: :loading}
  attr :projection_identity, :string, default: "loading"
  attr :section_slug, :string, required: true

  def tile(assigns) do
    assigns =
      assigns
      |> assign(:tile_state, tile_state(assigns.projection_status, assigns.projection))
      |> assign(:scope_reference, scope_reference(assigns.projection))
      |> assign(:view_all_navigation, view_all_navigation(assigns.projection))
      |> assign(:show_intro_copy, populated?(assigns.projection_status, assigns.projection))

    ~H"""
    <article
      id={"learning-dashboard-challenging-objectives-#{@projection_identity}"}
      data-state={@tile_state}
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="space-y-1.5 px-1 py-1">
        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center gap-2">
            <Icons.book class="h-5 w-5 shrink-0 stroke-Text-text-high" />
            <h3 class="text-lg font-semibold leading-6 text-Text-text-high">
              Challenging Objectives
            </h3>
          </div>
          <.view_all_link
            section_slug={@section_slug}
            navigation={@view_all_navigation}
            class="shrink-0"
          />
        </div>
        <p :if={@show_intro_copy} class="text-sm leading-6 text-Text-text-high">
          Your class is demonstrating
          <span class="font-bold text-Text-text-danger"> low proficiency (&le; 40%) </span>
          for these learning objectives.
        </p>
      </div>

      <%= case @tile_state do %>
        <% :loading -> %>
          <div class="mt-3 rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-4 text-sm text-Text-text-low">
            Loading challenging objectives for this scope.
          </div>
        <% :unavailable -> %>
          <div class="mt-3 rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-4">
            <p class="text-sm font-semibold text-Text-text-high">
              Objective insights are unavailable.
            </p>
            <p class="mt-1 text-sm text-Text-text-low">
              The dashboard could not prepare challenging-objective data for this scope.
            </p>
          </div>
        <% :no_data -> %>
          <div class="mt-3 rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-4">
            <p class="text-sm font-semibold text-Text-text-high">No objective data yet.</p>
            <p class="mt-1 text-sm text-Text-text-low">
              There is not enough proficiency data yet to highlight challenging objectives in {@scope_reference}.
            </p>
          </div>
        <% :empty_low_proficiency -> %>
          <div class="mt-3 rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-4">
            <p class="text-sm font-semibold text-Text-text-high">No low-proficiency objectives.</p>
            <p class="mt-1 text-sm text-Text-text-low">
              There are currently no learning objectives with low proficiency in {@scope_reference}.
            </p>
          </div>
        <% :populated -> %>
          <div class="mt-3 space-y-1">
            <%= for row <- @projection.rows do %>
              <.objective_row row={decorate_row(row)} section_slug={@section_slug} />
            <% end %>
          </div>
      <% end %>
    </article>
    """
  end

  attr :row, :map, required: true
  attr :section_slug, :string, required: true

  defp objective_row(%{row: %{has_children: true} = row} = assigns) do
    assigns =
      assigns
      |> assign(:row, row)
      |> assign(:link_path, learning_objectives_path(assigns.section_slug, row.navigation))

    ~H"""
    <div class="group rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] transition-colors hover:border-Border-border-hover hover:bg-Surface-surface-secondary-hover focus-within:border-Border-border-hover focus-within:bg-Surface-surface-secondary-hover">
      <div class="flex items-start gap-2.5 px-1 py-1">
        <span class="min-w-[40px] pt-1 text-right text-sm font-semibold leading-4 text-Text-text-low-alpha">
          {objective_display_number(@row)}
        </span>
        <.link
          navigate={@link_path}
          aria-label={objective_link_aria_label(@row.title, :objective)}
          class="min-w-0 flex-1 text-base font-semibold leading-6 text-Text-text-high focus:outline-none"
        >
          {@row.title}
        </.link>
      </div>
      <details class="mt-1 [&[open]_.tile-chevron]:rotate-180">
        <summary
          aria-label={"Toggle sub-objectives for #{@row.title}"}
          class="ml-2 inline-flex cursor-pointer list-none items-center gap-2 rounded-full bg-Fill-Buttons-fill-primary px-4 py-1 text-sm font-semibold leading-4 text-Text-text-white shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] focus:outline-none focus-visible:ring-2 focus-visible:ring-Fill-Buttons-fill-primary"
        >
          <span>{subobjective_count_label(length(@row.children))}</span>
          <span>
            <Icons.chevron_down class="tile-chevron h-4 w-4 fill-Text-text-white transition-transform" />
          </span>
        </summary>
        <div class="mt-2 rounded-xl border border-Border-border-subtle bg-Surface-surface-transparent p-2">
          <div class="space-y-1 px-3">
            <%= for child <- @row.children do %>
              <.subobjective_row row={child} section_slug={@section_slug} />
            <% end %>
          </div>
        </div>
      </details>
    </div>
    """
  end

  defp objective_row(assigns) do
    assigns =
      assign(
        assigns,
        :link_path,
        learning_objectives_path(assigns.section_slug, assigns.row.navigation)
      )

    ~H"""
    <div class="group rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] transition-colors hover:border-Border-border-hover hover:bg-Surface-surface-secondary-hover focus-within:border-Border-border-hover focus-within:bg-Surface-surface-secondary-hover">
      <%= if @row.row_type == :subobjective do %>
        <div class="rounded-xl border border-Border-border-subtle bg-Surface-surface-transparent p-2">
          <div class="space-y-1 px-3">
            <.subobjective_row row={@row} section_slug={@section_slug} />
          </div>
        </div>
      <% else %>
        <div class="flex items-start gap-2.5 px-1 py-1">
          <span class="min-w-[40px] pt-1 text-right text-sm font-semibold leading-4 text-Text-text-low-alpha">
            {objective_display_number(@row)}
          </span>
          <.link
            navigate={@link_path}
            aria-label={objective_link_aria_label(@row.title, @row.row_type)}
            class="min-w-0 flex-1 text-base font-semibold leading-6 text-Text-text-high focus:outline-none"
          >
            {@row.title}
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  attr :row, :map, required: true
  attr :section_slug, :string, required: true

  defp subobjective_row(assigns) do
    assigns =
      assign(
        assigns,
        :link_path,
        learning_objectives_path(assigns.section_slug, assigns.row.navigation)
      )

    ~H"""
    <div class="rounded-lg px-2 py-2 transition-colors hover:bg-Fill-fill-hover focus-within:bg-Fill-fill-hover">
      <div class="flex items-start gap-5">
        <span class="min-w-[30px] pt-1 text-right text-sm font-semibold leading-4 text-Text-text-low-alpha">
          {@row.display_number}
        </span>
        <div class="flex min-w-0 flex-1 items-start gap-4">
          <.link
            navigate={@link_path}
            aria-label={objective_link_aria_label(@row.title, :subobjective)}
            class="min-w-0 flex-1 text-base font-normal leading-6 text-Text-text-high focus:outline-none"
          >
            {@row.title}
          </.link>
          <span class="inline-flex shrink-0 items-center rounded-full bg-Fill-fill-danger px-4 py-1 text-base font-semibold leading-6 text-Text-text-danger shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]">
            {@row.proficiency_label}
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :section_slug, :string, required: true
  attr :navigation, :map, required: true
  attr :class, :string, default: nil

  defp view_all_link(assigns) do
    assigns =
      assign(assigns, :path, learning_objectives_path(assigns.section_slug, assigns.navigation))

    ~H"""
    <.link
      navigate={@path}
      aria-label="View Learning Objectives for this scope. Navigates to Learning Objectives."
      class={["text-sm font-bold leading-4 text-Text-text-button hover:underline", @class]}
    >
      View Learning Objectives
    </.link>
    """
  end

  defp learning_objectives_path(section_slug, navigation) do
    query =
      navigation
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    ~p"/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives?#{query}"
  end

  defp tile_state(%{status: status}, _projection) when status in [:failed, :unavailable],
    do: :unavailable

  defp tile_state(%{status: :loading}, _projection), do: :loading
  defp tile_state(_status, nil), do: :loading
  defp tile_state(_status, %{state: state}), do: state

  defp populated?(%{status: :ready}, %{state: :populated}), do: true
  defp populated?(_, _), do: false

  defp scope_reference(%{scope: %{label: label}}) when is_binary(label) and label != "", do: label
  defp scope_reference(_), do: "this scope"

  defp view_all_navigation(%{navigation: %{view_all: navigation}}), do: navigation
  defp view_all_navigation(_), do: %{}

  defp decorate_row(row), do: decorate_row(row, nil, nil)

  defp decorate_row(row, nil, nil) do
    children =
      row.children
      |> Enum.map(&decorate_row(&1, row.numbering, row.numbering_index))

    Map.put(row, :display_number, row.numbering)
    |> Map.put(:children, children)
  end

  defp decorate_row(row, _parent_numbering, _parent_numbering_index) do
    display_number =
      cond do
        is_binary(row.numbering) and row.numbering != "" ->
          row.numbering

        true ->
          row.title
      end

    Map.put(row, :display_number, display_number)
  end

  defp subobjective_count_label(1), do: "1 Sub-objective"
  defp subobjective_count_label(count), do: "#{count} Sub-objectives"

  defp objective_display_number(%{row_type: type, display_number: display_number})
       when type in [:objective, :standalone_subobjective],
       do: "LO #{display_number}"

  defp objective_display_number(%{display_number: display_number}), do: display_number

  defp objective_link_aria_label(title, :subobjective) do
    "Open sub-objective #{title} in Learning Objectives. Navigates to Learning Objectives."
  end

  defp objective_link_aria_label(title, _type) do
    "Open objective #{title} in Learning Objectives. Navigates to Learning Objectives."
  end
end
