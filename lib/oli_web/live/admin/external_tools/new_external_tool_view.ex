defmodule OliWeb.Admin.ExternalTools.NewExternalToolView do
  use OliWeb, :live_view

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti.PlatformExternalTools
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Admin.ExternalTools.Form
  alias OliWeb.Icons

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
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
      <Form.tool_form form={@form} action={:create} />
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
      {:ok, {platform_instance, _activity_registration, _deployment}} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "You have successfully added an LTI 1.3 External Tool at the system level."
         )
         |> redirect(to: ~p"/admin/external_tools/#{platform_instance.id}/details")}

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
