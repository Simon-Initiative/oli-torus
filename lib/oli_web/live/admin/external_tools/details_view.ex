defmodule OliWeb.Admin.ExternalTools.DetailsView do
  use OliWeb, :live_view

  require Logger

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti.{PlatformInstances, PlatformExternalTools}
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Admin.ExternalTools.Form
  alias OliWeb.Icons
  alias OliWeb.Components.Modal

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
          link: ~p"/admin/external_tools"
        })
      ] ++ [Breadcrumb.new(%{full_title: "LTI 1.3 External Tool Details"})]
  end

  @impl Phoenix.LiveView
  def mount(%{"platform_instance_id" => platform_instance_id}, _session, socket) do
    case PlatformExternalTools.get_platform_instance_with_deployment(platform_instance_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "The LTI Tool you are trying to view does not exist.")
         |> redirect(to: ~p"/admin/external_tools")}

      {platform_instance, deployment} ->
        changeset = PlatformExternalTools.change_platform_instance(platform_instance)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(),
           form: to_form(changeset, as: :tool_form),
           platform_instance: platform_instance,
           custom_flash: nil,
           edit_mode: false,
           deployment: deployment
         )}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-end mx-12 mt-4">
      <.toggle_status_modal
        tool_name={@platform_instance.name}
        action={:disable}
        id="disable_tool_modal"
      />
      <.toggle_status_modal
        tool_name={@platform_instance.name}
        action={:delete}
        id="delete_tool_modal"
      />
      {render_custom_flash(@custom_flash)}
      <div class="w-full inline-flex flex-col justify-start items-start gap-3">
        <div class="w-full flex flex-row justify-between items-center">
          <div class="justify-center text-2xl font-normal leading-9">
            {@platform_instance.name}
          </div>
          <div :if={!@edit_mode and @deployment.status != :deleted} class="flex flex-row gap-2">
            <.button
              phx-click="toggle_edit_mode"
              class="px-3 !py-1 bg-white text-[#006cd9] border border-blue-500 rounded-md
                   hover:bg-[#006cd9] hover:text-white
                   dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                   dark:hover:bg-[#0056ad] dark:hover:text-white dark:hover:border-[#0056ad]"
            >
              Edit Details
            </.button>
            <.button
              role="delete tool"
              phx-click={Modal.show_modal("delete_tool_modal")}
              class="px-3 !py-1 bg-white text-red-600 border border-red-500 rounded-md
                     hover:bg-red-600 hover:text-white
                     dark:bg-gray-800 dark:text-red-400 dark:border-red-400
                     dark:hover:bg-red-700 dark:hover:text-white dark:hover:border-red-700"
            >
              Delete Tool
            </.button>
          </div>
        </div>
        <div
          :if={@deployment.status != :deleted}
          class="w-full flex-row flex justify-start text-lg font-normal"
        >
          <text>
            Enable tool for project and course section use
          </text>
          <.toggle_switch
            id="toggle_tool_switch"
            role="toggle_tool_switch"
            class="ml-4 flex items-center h-9"
            checked={@deployment.status == :enabled}
            with_confirmation={true}
            on_toggle={
              if(@deployment.status == :enabled,
                do: Modal.show_modal("disable_tool_modal"),
                else: "toggle_tool_status"
              )
            }
          />
        </div>

        <div class="w-full flex-row flex justify-start text-lg font-normal">
          <text>
            Enable deep linking for this tool
          </text>
          <.toggle_switch
            id="toggle_deep_linking_switch"
            role="toggle_deep_linking_switch"
            class="ml-4 flex items-center h-9"
            checked={@deployment.deep_linking_enabled}
            on_toggle="toggle_deep_linking_enabled"
          />
        </div>
      </div>
      <Form.tool_form form={@form} action={:update} edit_mode={@edit_mode} />
    </div>
    """
  end

  attr :tool_name, :string, required: true
  attr :action, :atom, required: true
  attr :id, :string, required: true

  defp toggle_status_modal(assigns) do
    ~H"""
    <Modal.modal
      id={@id}
      class="!w-1/2"
      header_class="flex items-start justify-between p-6 border-b border-gray-300"
      confirm_class="h-8 w-fit px-5 py-3 text-white hover:no-underline rounded-md justify-center items-center gap-2 inline-flex bg-[#0062F2] hover:bg-[#0075EB] dark:bg-[#0062F2] dark:hover:bg-[#0D70FF]"
      cancel_class="h-8 px-3 !py-1 bg-white text-[#006cd9] border border-blue-500 rounded-md
                     hover:bg-[#0062F2] hover:text-white
                     dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                     dark:hover:bg-[#0062F2] dark:hover:text-white dark:hover:border-[#0062F2]"
      on_confirm={
        JS.push(push_action(@action))
        |> Modal.hide_modal(@id)
      }
    >
      <:title>{stringify_action(@action)} {@tool_name}?</:title>
      <.modal_message action={@action} />
      <:cancel>Cancel</:cancel>
      <:confirm>{stringify_action(@action)} Tool</:confirm>
    </Modal.modal>
    """
  end

  defp stringify_action(:disable), do: "Disable"
  defp stringify_action(:delete), do: "Delete"

  defp push_action(:delete), do: "delete_tool"
  defp push_action(:disable), do: "toggle_tool_status"

  attr :action, :atom, required: true

  defp modal_message(%{action: :disable} = assigns) do
    ~H"""
    <div class="text-base font-medium">
      Disabling this tool will disable its functionality across projects, products, active course sections. Course authors and instructors will be notified of this change on the affected pages. Functionality will be fully restored if the tool is re-enabled.
    </div>
    """
  end

  defp modal_message(%{action: :delete} = assigns) do
    ~H"""
    <div class="text-base font-medium">
      Deleting this tool will disable its functionality across projects, products, and course sections and
      <span class="font-bold">permanently delete the tool from the system.</span>
      Course authors and instructors will be notified of this change on the affected pages.
    </div>
    """
  end

  def handle_event("validate", %{"tool_form" => params}, socket) do
    changeset =
      %PlatformInstance{}
      |> PlatformInstances.change_platform_instance(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, as: :tool_form))
     |> assign(:custom_flash, nil)}
  end

  def handle_event("update_tool", %{"tool_form" => params}, socket) do
    case PlatformExternalTools.update_lti_external_tool_activity(
           socket.assigns.platform_instance.id,
           params
         ) do
      {:ok, %{updated_platform_instance: platform_instance}} ->
        new_changeset = PlatformExternalTools.change_platform_instance(platform_instance)

        {:noreply,
         socket
         |> assign(form: to_form(new_changeset, as: :tool_form))
         |> assign(edit_mode: false)
         |> assign(:custom_flash, %{
           type: :success,
           message: "You have successfully updated the LTI 1.3 External Tool."
         })}

      {:error, _, %Ecto.Changeset{} = changeset, _} ->
        {flash_type, flash_message} =
          if Enum.any?(changeset.errors, fn
               {:client_id, {"has already been taken", _}} -> true
               _ -> false
             end) do
            {:duplicate, "The client ID already exists and must be unique."}
          else
            {:error, "One or more of the required fields is missing; please check your input."}
          end

        {:noreply,
         socket
         |> assign(form: to_form(changeset, as: :tool_form))
         |> assign(:custom_flash, %{
           type: flash_type,
           message: flash_message
         })}

      {:error, _, {:not_found}, _} ->
        {:noreply,
         socket
         |> assign(:custom_flash, %{
           type: :not_found,
           message: "This platform instance no longer exists or couldn’t be found."
         })}
    end
  end

  def handle_event("clear-custom-flash", _params, socket) do
    {:noreply, assign(socket, custom_flash: nil)}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_mode, !socket.assigns.edit_mode)}
  end

  def handle_event("toggle_tool_status", _params, socket) do
    new_status =
      case socket.assigns.deployment.status do
        :enabled -> :disabled
        :disabled -> :enabled
      end

    case PlatformExternalTools.update_lti_external_tool_activity_deployment(
           socket.assigns.deployment,
           %{"status" => new_status}
         ) do
      {:ok, deployment} ->
        {:noreply,
         socket
         |> assign(deployment: deployment)
         |> assign(:custom_flash, %{
           type: :success,
           message:
             "You have successfully #{Atom.to_string(new_status)} the LTI 1.3 External Tool."
         })}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:custom_flash, %{
           type: :error,
           message: "There was an error updating the status of the LTI 1.3 External Tool."
         })}
    end
  end

  def handle_event("toggle_deep_linking_enabled", _params, socket) do
    new_value = !socket.assigns.deployment.deep_linking_enabled

    case PlatformExternalTools.update_lti_external_tool_activity_deployment(
           socket.assigns.deployment,
           %{"deep_linking_enabled" => new_value}
         ) do
      {:ok, deployment} ->
        {:noreply,
         socket
         |> assign(deployment: deployment)
         |> assign(:custom_flash, %{
           type: :success,
           message:
             "You have successfully #{if new_value, do: "enabled", else: "disabled"} deep linking for the LTI 1.3 External Tool."
         })}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:custom_flash, %{
           type: :error,
           message:
             "There was an error updating the deep linking setting of the LTI 1.3 External Tool."
         })}
    end
  end

  def handle_event("delete_tool", _params, socket) do
    case PlatformExternalTools.soft_delete_activity_deployment_and_platform_instance(
           socket.assigns.deployment
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "LTI 1.3 External tool deleted successfully.")
         |> push_navigate(to: ~p"/admin/external_tools")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error deleting external tool.")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket) do
    # Catch-all for UI-only events from functional components
    # that don't need handling (like dropdown toggles)
    Logger.warning("Unhandled event in DetailsView: #{inspect(event)}, #{inspect(params)}")
    {:noreply, socket}
  end

  defp render_custom_flash(nil), do: nil

  defp render_custom_flash(%{type: type, message: message}) do
    {bg_class, text_color, label} =
      case type do
        :success -> {"bg-[#F2F9FF]", "#1b67b2", "Success!"}
        :error -> {"bg-[#FEEBED]", "#ce2c31", "Missing Fields"}
        :duplicate -> {"bg-[#FEEBED]", "#ce2c31", "ID Already Exists"}
        :not_found -> {"bg-[#FEEBED]", "#ce2c31", "Record Not Found"}
      end

    assigns = %{
      bg_class: bg_class,
      text_color: text_color,
      label: label,
      type: type,
      message: message
    }

    ~H"""
    <div id="flash" class={"#{@bg_class} px-6 py-4 rounded-md relative mb-8"}>
      <div class="flex items-start justify-between gap-4">
        <div class="flex items-center gap-2 font-semibold">
          <%= case @type do %>
            <% :success -> %>
              <Icons.check stroke_class="stroke-blue-600" />
            <% t when t in [:error, :duplicate, :not_found] -> %>
              <Icons.alert />
          <% end %>
          <span class={"text-[#{@text_color}] text-base font-semibold"}>
            {@label}
          </span>
        </div>
        <button
          phx-click="clear-custom-flash"
          class={"text-sm hover:opacity-70 text-[#{@text_color}]"}
        >
          ✕
        </button>
      </div>
      <p class="mt-1 text-[#353740] text-sm font-normal">{@message}</p>
    </div>
    """
  end
end
