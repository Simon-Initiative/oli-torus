defmodule OliWeb.Admin.ExternalTools.DetailsView do
  use OliWeb, :live_view

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti.{PlatformInstances, PlatformExternalTools}
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Icons

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
          link: ~p"/admin/external_tools"
        })
      ] ++ [Breadcrumb.new(%{full_title: "LTI 1.3 External Tool Details"})]
  end

  def mount(%{"platform_instance_id" => platform_instance_id}, _session, socket) do
    platform_instance = PlatformExternalTools.get_platform_instance(platform_instance_id)
    changeset = PlatformExternalTools.change_platform_instance(platform_instance)

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       form: to_form(changeset, as: :tool_form),
       platform_instance: platform_instance,
       custom_flash: nil,
       edit_mode: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-end mx-12 mt-4">
      <%= render_custom_flash(@custom_flash) %>
      <div class="w-full inline-flex flex-col justify-start items-start gap-3">
        <div class="w-full flex flex-row justify-between items-center">
          <div class="justify-center text-color-blue-24 text-2xl font-normal leading-9">
            <%= @platform_instance.name %>
          </div>
          <.button
            :if={!@edit_mode}
            phx-click="toggle_edit_mode"
            class="px-3 !py-1 bg-white text-[#006cd9] border border-blue-500 rounded-md
                   hover:bg-[#006cd9] hover:text-white
                   dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                   dark:hover:bg-[#0056ad] dark:hover:text-white dark:hover:border-[#0056ad]"
          >
            Edit Details
          </.button>
        </div>
      </div>
      <.form
        :let={f}
        id="tool_form"
        for={@form}
        class="flex flex-col gap-y-8 mt-6"
        phx-submit="update_tool"
        phx-change="validate"
      >
        <fieldset class="m-0 p-0 border-0 space-y-4" disabled={!@edit_mode}>
          <.input
            class="form-control h-11 placeholder:pl-6"
            field={f[:name]}
            type="text"
            label="Tool Name"
            label_class="mb-2"
            placeholder="Type here..."
            additional_text={~H'<span class="text-red-500">(*Required)</span>'}
            required
          />
          <.input
            class="form-control mt-2 placeholder:pl-6"
            group_class=""
            field={f[:description]}
            type="textarea"
            data-grow="true"
            autocomplete="off"
            rows="3"
            label="Tool Description"
            placeholder="Type here..."
          />
          <.input
            class="form-control h-11 placeholder:pl-6"
            field={f[:target_link_uri]}
            type="text"
            label="Target Link URI"
            label_class="mb-2"
            placeholder="Type here..."
            additional_text={~H'<span class="text-red-500">(*Required)</span>'}
            required
          />
          <.input
            class="form-control h-11 placeholder:pl-6"
            field={f[:client_id]}
            type="text"
            label="Tool Client ID"
            label_class="mb-2"
            placeholder="Type here..."
            additional_text={~H'<span class="text-red-500">(*Required)</span>'}
            required
          />
          <.input
            class="form-control h-11 placeholder:pl-6"
            field={f[:login_url]}
            type="text"
            label="Login URL"
            label_class="mb-2"
            placeholder="Type here..."
            additional_text={~H'<span class="text-red-500">(*Required)</span>'}
            required
          />
          <.input
            class="form-control h-11 placeholder:pl-6"
            field={f[:keyset_url]}
            type="text"
            label="Keyset URL"
            label_class="mb-2"
            placeholder="Type here..."
            additional_text={~H'<span class="text-red-500">(*Required)</span>'}
            required
          />
          <.input
            class="form-control mt-2 placeholder:pl-6"
            group_class=""
            field={f[:redirect_uris]}
            type="textarea"
            data-grow="true"
            autocomplete="off"
            rows="3"
            label="Redirect URIs"
            label_class="mb-2"
            placeholder="Type here..."
            additional_text={~H'<span class="text-red-500">(*Required)</span>'}
            required
          />
          <.input
            class="form-control mt-2 placeholder:pl-6"
            group_class=""
            field={f[:custom_params]}
            type="textarea"
            data-grow="true"
            autocomplete="off"
            rows="3"
            label="Custom Params"
            label_class="mb-2"
            placeholder="Type here..."
          />
        </fieldset>

        <div :if={@edit_mode} class="flex justify-end gap-2 my-8">
          <.button
            phx-click="toggle_edit_mode"
            type="button"
            class="px-6 !py-2 bg-white text-[#006cd9] border border-blue-500 rounded-md
                   hover:bg-[#006cd9] hover:text-white
                   dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                   dark:hover:bg-[#0056ad] dark:hover:text-white dark:hover:border-[#0056ad]"
          >
            Cancel
          </.button>
          <.button
            type="submit"
            disabled={@form.source.changes == %{}}
            class="px-6 py-2 bg-[#006cd9] hover:bg-[#0075EB] text-white rounded-md
                   disabled:cursor-not-allowed disabled:bg-gray-300
                   dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
          >
            Save
          </.button>
        </div>
      </.form>
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
      {:ok, %{platform_instance: platform_instance}} ->
        new_changeset = PlatformExternalTools.change_platform_instance(platform_instance)

        {:noreply,
         socket
         |> assign(form: to_form(new_changeset, as: :tool_form))
         |> assign(:custom_flash, %{
           type: :success,
           message: "You have successfully updated the LTI 1.3 External Tool."
         })}

      {:error, _, changeset, _} ->
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

  defp render_custom_flash(nil), do: nil

  defp render_custom_flash(%{type: type, message: message}) do
    {bg_class, text_color, label} =
      case type do
        :success -> {"bg-[#F2F9FF]", "#1b67b2", "Success!"}
        :error -> {"bg-[#FEEBED]", "#ce2c31", "Missing Fields"}
        :duplicate -> {"bg-[#FEEBED]", "#ce2c31", "ID Already Exists"}
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
            <% t when t in [:error, :duplicate] -> %>
              <Icons.alert />
          <% end %>
          <span class={"text-[#{@text_color}] text-base font-semibold"}>
            <%= @label %>
          </span>
        </div>
        <button
          phx-click="clear-custom-flash"
          class={"text-sm hover:opacity-70 text-[#{@text_color}]"}
        >
          ✕
        </button>
      </div>
      <p class="mt-1 text-[#353740] text-sm font-normal"><%= @message %></p>
    </div>
    """
  end
end
