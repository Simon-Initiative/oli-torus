defmodule OliWeb.Components.Delivery.ScheduleGatingAssessment do
  use OliWeb, :html

  attr :section_slug, :string
  attr :uri, :string

  def tabs(assigns) do
    assigns =
      assign(assigns,
        active_tab: determine_tab(assigns[:uri])
      )

    IO.inspect(assigns, label: "ScheduleGatingAssessment")

    ~H"""
    <div class="w-full px-6 py-4">
      <div class="flex">
        <ul
          class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4"
          id="tabs-tab"
          role="tablist"
        >
          <%= for {label, name, path} <- [
              {"Schedule", "schedule", ~p"/sections/#{@section_slug}/schedule"},
              {"Assessment Settings", "assessment_settings", ~p"/sections/#{@section_slug}/assessment_settings/settings/all"},
              {"Student Exceptions", "student_exceptions", ~p"/sections/#{@section_slug}/assessment_settings/student_exceptions/all"},
              {"Advanced Gating", "advanced_gating", ~p"/sections/#{@section_slug}/gating_and_scheduling"}
              ] do %>
            <li>
              <%= if name == "schedule" do %>
                <.link href={path} class={tab_class(@active_tab, name)}>
                  <%= label %>
                </.link>
              <% else %>
                <.link navigate={path} class={tab_class(@active_tab, name)}>
                  <%= label %>
                </.link>
              <% end %>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  defp determine_tab(uri) do
    cond do
      String.contains?(uri, "/settings") -> "assessment_settings"
      String.contains?(uri, "/student_exceptions") -> "student_exceptions"
      String.contains?(uri, "/gating_and_scheduling") -> "advanced_gating"
      true -> "schedule"
    end
  end

  defp tab_class(active_tab, name) do
    base = "block
                    border-x-0 border-t-0 border-b-2
                    px-1
                    py-3
                    m-2
                    bg-transparent
                    hover:no-underline
                    hover:border-delivery-primary-200
                    focus:border-delivery-primary-200"
    active = "border-delivery-primary text-body-delivery-primary hover:text-body-delivery-primary"

    inactive =
      "border-transparent text-body-color dark:text-body-color-dark hover:text-body-color"

    if active_tab == name, do: "#{base} #{active}", else: "#{base} #{inactive}"
  end
end
