defmodule OliWeb.Admin.ExternalTools.NewExternalToolView do
  use OliWeb, :live_view

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti.PlatformExternalTools
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Icons

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tool",
          link: ~p"/admin/external_tools"
        })
      ] ++ [Breadcrumb.new(%{full_title: "Add New LTI 1.3 External Tool"})]
  end

  def mount(_, _session, socket) do
    changeset = PlatformExternalTools.change_platform_instance(%PlatformInstance{})

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       form: to_form(changeset, as: :tool_form),
       custom_flash: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-end mx-12 mt-4">
      <%= render_custom_flash(@custom_flash) %>
      <div class="w-[1247px] inline-flex flex-col justify-start items-start gap-3">
        <div class="self-stretch flex flex-col justify-start items-start">
          <div class="justify-center text-color-blue-24 text-2xl font-normal leading-9">
            Add New LTI 1.3 External Tool
          </div>
        </div>
      </div>
      <.form
        :let={f}
        id="tool_form"
        for={@form}
        class="flex flex-col gap-y-8 mt-12"
        phx-submit="create_tool"
        phx-change="validate"
      >
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

        <div class="flex justify-end gap-2 my-8">
          <.button
            href={~p"/admin/external_tools"}
            class="px-6 py-2 bg-white text-[#006cd9] border border-blue-500 rounded-md"
          >
            Cancel
          </.button>
          <.button
            type="submit"
            class="px-6 py-2 bg-[#0062F2] hover:bg-[#0075EB] text-white rounded-md"
          >
            Add Tool
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("validate", %{"tool_form" => params}, socket) do
    changeset =
      %PlatformInstance{}
      |> PlatformExternalTools.change_platform_instance(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, as: :tool_form))
     |> assign(:custom_flash, nil)}
  end

  def handle_event("create_tool", %{"tool_form" => params}, socket) do
    case PlatformExternalTools.register_lti_external_tool_activity(params) do
      {:ok, _tool} ->
        new_changeset = PlatformExternalTools.change_platform_instance(%PlatformInstance{})

        {:noreply,
         socket
         |> assign(form: to_form(new_changeset, as: :tool_form))
         |> assign(:custom_flash, %{
           type: :success,
           message: "You have successfully added an LTI 1.3 External Tool at the system level."
         })}

      {:error, %Ecto.Changeset{} = changeset} ->
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
              <Icons.check stroke_class="stroke-[#1b67b2]" />
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
