defmodule OliWeb.Components.Project.DatashopExport do
  use OliWeb, :html

  import OliWeb.Components.Common

  alias OliWeb.Common.SessionContext
  alias Oli.Publishing.Publications.Publication

  attr :ctx, SessionContext, required: true
  attr :latest_publication, Publication, required: true
  attr :datashop_export_status, :atom, values: [:not_available, :in_progress, :available]
  attr :datashop_export_url, :string
  attr :datashop_export_timestamp, :string
  attr :on_generate_datashop_snapshot, :string, default: "generate_datashop_snapshot"

  def export_button(assigns) do
    ~H"""
      <%= case @latest_publication do %>
        <% nil -> %>
          <.button_link disabled>Analytics</.button_link> Project must be published to generate a datashop export file.
        <% _pub -> %>
          <%= case @datashop_export_status do %>
            <% status when status in [:not_available, :expired] -> %>
              <.button_link variant={:primary} phx-click="generate_datashop_snapshot">Analytics</.button_link>
              <div>Generate an analytics snapshot for <a class="text-primary external" href="https://pslcdatashop.web.cmu.edu/" target="_blank">Datashop</a></div>
            <% :in_progress -> %>
              <.button_link disabled>Analytics</.button_link>
              <span class="text-sm text-gray-500">
                <i class="fa-solid fa-circle-notch fa-spin text-primary"></i>
                Generating <a class="text-primary external" href="https://pslcdatashop.web.cmu.edu/" target="_blank">Datashop</a> analytics snapshot... this might take a while.
              </span>
            <% :available -> %>
              <.button_link variant={:primary} href={@datashop_export_url} download><i class="fa-solid fa-download mr-1"></i> Analytics</.button_link>
              <span>Download <a class="text-primary external" href="https://pslcdatashop.web.cmu.edu/" target="_blank">Datashop</a> analytics snapshot.</span>
              <span class="text-sm text-gray-500 ml-3">
                Created <%= date(@datashop_export_timestamp, @ctx) %>.
                <.button_link phx-click={@on_generate_datashop_snapshot}><i class="fa-solid fa-rotate-right mr-1"></i>Regenerate</.button_link>
              </span>
          <% end %>
      <% end %>
    """
  end
end
