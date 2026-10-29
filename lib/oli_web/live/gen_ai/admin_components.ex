defmodule OliWeb.GenAI.AdminComponents do
  @moduledoc "Shared presentation patterns for the GenAI administration screens."
  use OliWeb, :html

  @doc "Returns the form-control styling established by Service Config administration."
  def form_control_classes do
    "block w-full p-2.5 text-sm text-gray-900 bg-gray-50 " <>
      "rounded-lg border border-gray-300 focus:ring-blue-500 focus:border-blue-500 " <>
      "dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
  end

  @doc "Returns consistent selection, hover and focus styling for administration list rows."
  def list_item_classes(selected?) do
    [
      "flex w-full text-left justify-between gap-x-6 py-1 px-2 rounded-md cursor-pointer transition-colors dark:text-gray-100",
      case selected? do
        true -> "bg-indigo-50 dark:bg-gray-700"
        false -> "bg-white dark:bg-gray-900"
      end,
      "hover:bg-indigo-100 dark:hover:bg-gray-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
    ]
  end

  attr :editing, :boolean, required: true

  @doc "Renders the shared Enable Editing switch above the administration columns."
  def editing_toggle(assigns) do
    ~H"""
    <div class="flex justify-end">
      <div class="flex py-2 mb-2">
        <label for="toggle_editing_checkbox">Enable Editing</label>
        <.toggle_switch
          id="toggle_editing"
          class="ml-4"
          checked={@editing}
          on_toggle="toggle_editing"
          name="toggle_editing"
        />
      </div>
    </div>
    """
  end
end
