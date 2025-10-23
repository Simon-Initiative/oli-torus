defmodule OliWeb.Components.Project.AsyncExporter do
  use OliWeb, :html

  import OliWeb.Components.Common

  alias OliWeb.Common.SessionContext
  alias Oli.Publishing.Publications.Publication

  attr(:ctx, SessionContext, required: true)
  attr(:latest_publication, Publication, default: nil)

  attr(:analytics_export_status, :atom,
    values: [:not_available, :in_progress, :available, :error]
  )

  attr(:analytics_export_url, :string)
  attr(:analytics_export_timestamp, :string)
  attr(:on_generate_analytics_snapshot, :string, default: "generate_analytics_snapshot")

  def raw_analytics(assigns) do
    ~H"""
    <%= case @latest_publication do %>
      <% nil -> %>
        <.button variant={:link} disabled>Raw Analytics</.button>
        Project must be published to generate an analytics snapshot.
      <% _pub -> %>
        <%= case @analytics_export_status do %>
          <% status when status in [:not_available, :expired] -> %>
            <.button variant={:link} phx-click={@on_generate_analytics_snapshot}>
              Generate Raw Analytics
            </.button>
            <div>Create a raw analytics snapshot for download</div>
          <% :in_progress -> %>
            <.button variant={:link} disabled>Generate Raw Analytics</.button>
            <div class="flex flex-col">
              <div>Create a raw analytics snapshot for download</div>
              <div class="text-sm text-gray-500">
                <i class="fa-solid fa-circle-notch fa-spin text-primary"></i>
                Generating raw analytics snapshot... this might take a while.
              </div>
            </div>
          <% :available -> %>
            <.button variant={:link} href={@analytics_export_url} download>
              <i class="fa-solid fa-download mr-1"></i> Raw Analytics
            </.button>
            <div class="flex flex-col">
              <div>Download raw analytics snapshot.</div>
              <div class="text-sm text-gray-500">
                Created {date(@analytics_export_timestamp, @ctx)}.
                <.button variant={:link} phx-click={@on_generate_analytics_snapshot}>
                  <i class="fa-solid fa-rotate-right mr-1"></i>Regenerate
                </.button>
              </div>
            </div>
          <% :error -> %>
            <.button variant={:link} phx-click={@on_generate_analytics_snapshot}>
              Generate Raw Analytics
            </.button>
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

  attr(:ctx, SessionContext, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:datashop_export_status, :atom, values: [:not_available, :in_progress, :available, :error])
  attr(:datashop_export_url, :string)
  attr(:datashop_export_timestamp, :string)
  attr(:datashop_export_current_batch, :integer)
  attr(:datashop_export_batch_count, :integer)
  attr(:on_generate_datashop_snapshot, :string, default: "generate_datashop_snapshot")
  attr(:on_kill, :string, default: "kill_datashop_snapshot")

  def datashop(assigns) do
    ~H"""
    <%= case @datashop_export_status do %>
      <% status when status in [:not_available, :expired] -> %>
        <.datashop_button
          id="button-generate-datashop"
          on_datashop_action={@on_generate_datashop_snapshot}
          disabled={@disabled}
          color="blue"
        >
          <i class="fa-solid fa-file-export"></i> Generate Datashop Export
        </.datashop_button>
      <% :in_progress -> %>
        <div class="flex flex-col my-4 items-end">
          <.datashop_button id="button-kill-datashop" on_datashop_action={@on_kill} color="red">
            <i class="fa-solid fa-file-export"></i> Kill Datashop Export
          </.datashop_button>
          <div class="text-sm text-gray-500 mt-2">
            <i class="fa-solid fa-circle-notch fa-spin text-primary"></i>
            Generating datashop snapshot... this might take a while.
            <div :if={@datashop_export_current_batch && @datashop_export_batch_count}>
              Processing Batch {@datashop_export_current_batch} of {@datashop_export_batch_count}
            </div>
          </div>
        </div>
      <% :available -> %>
        <div class="flex flex-col mx-4 text-center">
          <.button variant={:primary} href={@datashop_export_url} download>
            <i class="fa-solid fa-download mr-1"></i> Datashop
          </.button>
          <div class="text-xs text-gray-500">
            Created {date(@datashop_export_timestamp, @ctx)}.
          </div>
        </div>
        <.datashop_button
          id="button-regenerate-datashop"
          on_datashop_action={@on_generate_datashop_snapshot}
          disabled={@disabled}
          color="blue"
        >
          <i class="fa-solid fa-rotate-right mr-1"></i> Regenerate
        </.datashop_button>
      <% :error -> %>
        <div class="flex flex-col my-4 items-end">
          <.datashop_button
            id="button-generate-datashop"
            on_datashop_action={@on_generate_datashop_snapshot}
            disabled={@disabled}
            color="blue"
          >
            <i class="fa-solid fa-file-export"></i> Generate Datashop Export
          </.datashop_button>
          <div class="text-sm text-gray-500 mt-2">
            <i class="fa-solid fa-exclamation-circle text-red-500"></i>
            Error generating datashop snapshot. Please try again later or contact support.
          </div>
        </div>
    <% end %>
    """
  end

  slot(:inner_block)

  defp datashop_link(assigns) do
    ~H"""
    <a class="text-primary external" href="https://pslcdatashop.web.cmu.edu/" target="_blank">
      datashop
    </a>
    """
  end

  attr(:id, :string, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:color, :string, default: "blue")
  attr(:on_datashop_action, :string, required: true)
  slot(:inner_block, required: true)

  defp datashop_button(assigns) do
    ~H"""
    <button
      id={@id}
      class={[
        "text-white py-2 px-4 w-auto rounded disabled:opacity-50 disabled:cursor-not-allowed",
        if(@color == "blue",
          do: "bg-blue-500 hover:bg-blue-600  disabled:hover:bg-blue-500",
          else: "bg-red-500 hover:bg-red-600  disabled:hover:bg-red-500"
        )
      ]}
      phx-click={@on_datashop_action}
      disabled={@disabled}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:ctx, SessionContext, required: true)
  attr(:project_export_status, :atom, values: [:not_available, :in_progress, :available, :error])
  attr(:project_export_url, :string)
  attr(:project_export_timestamp, :string)
  attr(:on_generate_project_export, :string, default: "generate_project_export")

  def project_export(assigns) do
    ~H"""
    <%= case @project_export_status do %>
      <% status when status in [:not_available, :expired] -> %>
        <.button
          variant={:link}
          class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pl-0 pr-3 py-2"
          phx-click={@on_generate_project_export}
        >
          Export
        </.button>
        <div>Download this project and its contents</div>
      <% :in_progress -> %>
        <.button
          variant={:link}
          class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pl-0 pr-3 py-2"
          disabled
        >
          Export in Progress
        </.button>
        <div class="flex flex-col">
          <div>Download this project and its contents</div>
          <div class="text-sm text-gray-500">
            <i class="fa-solid fa-circle-notch fa-spin text-primary"></i>
            Generating project export... this might take a while.
          </div>
        </div>
      <% :available -> %>
        <.button
          variant={:link}
          class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pl-0 pr-3 py-2"
          href={@project_export_url}
          download
        >
          <i class="fa-solid fa-download mr-1"></i> Download Latest Export
        </.button>
        <div class="flex flex-col">
          <div>Download this project and its contents.</div>
          <div class="text-sm text-gray-500">
            Created {date(@project_export_timestamp, @ctx)}.
            <.button
              variant={:link}
              class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pl-0 pr-3 py-2"
              phx-click={@on_generate_project_export}
            >
              <i class="fa-solid fa-rotate-right mr-1"></i>Regenerate
            </.button>
          </div>
        </div>
      <% :error -> %>
        <.button
          variant={:link}
          class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pl-0 pr-3 py-2"
          phx-click={@on_generate_project_export}
        >
          Export
        </.button>
        <div class="flex flex-col">
          <div>Download this project and its contents</div>
          <div class="text-sm text-gray-500">
            <i class="fa-solid fa-exclamation-circle text-red-500"></i>
            Error generating project export. Please try again later or contact support.
          </div>
        </div>
    <% end %>
    """
  end
end
