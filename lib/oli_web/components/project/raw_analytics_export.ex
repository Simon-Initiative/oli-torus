defmodule OliWeb.Components.Project.RawAnalyticsExport do
  use OliWeb, :html

  import OliWeb.Components.Common

  alias OliWeb.Common.SessionContext
  alias Oli.Publishing.Publications.Publication

  attr(:ctx, SessionContext, required: true)
  attr(:latest_publication, Publication, default: nil)
  attr(:analytics_export_status, :atom, values: [:not_available, :in_progress, :available])
  attr(:analytics_export_url, :string)
  attr(:analytics_export_timestamp, :string)
  attr(:on_generate_analytics_snapshot, :string, default: "generate_analytics_snapshot")

  def export_button(assigns) do
    ~H"""
      <%= case @latest_publication do %>
        <% nil -> %>
          <.button_link disabled>Raw Analytics</.button_link> Project must be published to generate an analytics snapshot.
        <% _pub -> %>
          <%= case @analytics_export_status do %>
            <% status when status in [:not_available, :expired] -> %>
              <.button_link variant={:primary} phx-click={@on_generate_analytics_snapshot}>Generate Raw Analytics</.button_link>
              <div>Create a raw analytics snapshot for download</div>
            <% :in_progress -> %>
              <.button_link disabled>Generate Raw Analytics</.button_link>
              <div class="flex flex-col">
                <div>Create a raw analytics snapshot for download</div>
                <div class="text-sm text-gray-500">
                  <i class="fa-solid fa-circle-notch fa-spin text-primary"></i>
                  Generating raw analytics snapshot... this might take a while.
                </div>
              </div>
            <% :available -> %>
              <.button_link variant={:primary} href={@analytics_export_url} download><i class="fa-solid fa-download mr-1"></i> Raw Analytics</.button_link>
              <div class="flex flex-col">
                <div>Download raw analytics snapshot.</div>
                <div class="text-sm text-gray-500">
                  Created <%= date(@analytics_export_timestamp, @ctx) %>.
                  <.button_link phx-click={@on_generate_analytics_snapshot}><i class="fa-solid fa-rotate-right mr-1"></i>Regenerate</.button_link>
                </div>
              </div>
            <% :error -> %>
              <.button_link variant={:primary} phx-click={@on_generate_analytics_snapshot}>Generate Raw Analytics</.button_link>
              <div class="flex flex-col">
                <div>Create a raw analytics snapshot for download</div>
                <div class="text-sm text-gray-500">
                  <i class="fa-solid fa-exclamation-circle text-red-500"></i>
                  Error generating raw analytics snapshot. Please try again later or contact support.
                </div>
              </div>
          <% end %>
      <% end %>
    """
  end
end
