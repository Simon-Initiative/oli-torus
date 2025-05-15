defmodule OliWeb.Admin.ExternalTools.Form do
  use Phoenix.Component
  use OliWeb, :verified_routes

  import OliWeb.Components.Common

  @doc """
  Renders a form for creating or editing an external tool.
  """
  attr :form, :any, required: true
  attr :action, :atom, required: true, doc: "The form submit action: :create or :update"
  attr :edit_mode, :boolean, default: true

  def tool_form(assigns) do
    ~H"""
    <.form
      :let={f}
      id="tool_form"
      for={@form}
      class="flex flex-col gap-y-8 mt-6"
      phx-submit={submit_event(@action)}
      phx-change="validate"
    >
      <fieldset class="m-0 p-0 border-0 space-y-4" disabled={@action == :update and not @edit_mode}>
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
          additional_text={~H'<span class="text-red-500">(*Required)</span>'}
          required
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
          label="Client ID"
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
        <%= case @action do %>
          <% :update -> %>
            <.button
              type="button"
              role="cancel_edit"
              phx-click="toggle_edit_mode"
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
          <% :create -> %>
            <.button
              href={~p"/admin/external_tools"}
              class="px-6 !py-2 bg-white text-[#006cd9] border border-blue-500 rounded-md hover:no-underline
                   hover:bg-[#006cd9] hover:text-white
                   dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                   dark:hover:bg-[#0056ad] dark:hover:text-white dark:hover:border-[#0056ad]"
            >
              Cancel
            </.button>
            <.button
              type="submit"
              class="px-6 py-2 bg-[#006cd9] hover:bg-[#0075EB] text-white rounded-md"
            >
              Add Tool
            </.button>
        <% end %>
      </div>
    </.form>
    """
  end

  defp submit_event(:create), do: "create_tool"
  defp submit_event(:update), do: "update_tool"
end
