defmodule OliWeb.Workspaces.CourseAuthor.Qa.WarningFilter do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="m-2">
      <div class="flex flex-row items-center">
        <input
          class="warning-filter w-[20px] h-[20px]"
          id={"filter-#{@type}"}
          phx-click="filter"
          phx-value-type={"#{@type}"}
          {if @active do [checked: true] else [] end}
          type="checkbox"
          aria-label={"Checkbox for #{@type}"}
        />
        <label for={"filter-#{@type}"} class="flex flex-row align-items-center ml-2">
          <%= String.capitalize(@type) %>
          <span class="badge badge-info ml-2"><%= length(@warnings) %></span>
        </label>
      </div>
    </div>
    """
  end
end
