defmodule OliWeb.Components.Delivery.Students do
  use Surface.LiveComponent

  alias OliWeb.Common.{PagedTable, SearchInput}

  prop limit, :number, default: 10
  prop filter, :string, required: true
  prop offset, :number, required: true
  prop count, :number, required: true
  prop students_table_model, :struct, required: true

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
        <div class="p-10">
      <div class="bg-white w-full">
        <div class="flex items-center border-b border-b-gray-200 pr-6">
          <h4 class="px-10 py-6 torus-h4 mr-auto">Students</h4>
          <form for="search" phx-target={@myself} phx-change="search_student" phx-debounce="5000">
            <SearchInput.render
                    id="students_search_input"
                    name="student_name"
                  />
          </form>
        </div>

          <PagedTable
            table_model={@students_table_model}
            total_count={@count}
            offset={@offset}
            limit={@limit}
            additional_table_class="border-0"
            />
            </div>
            </div>
    """
  end

  def handle_event("search_student", %{"student_name" => student_name}, socket) do
    IO.inspect(student_name)
    {:noreply, socket}
  end
end
