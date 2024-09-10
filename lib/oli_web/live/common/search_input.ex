defmodule OliWeb.Common.SearchInput do
  use Phoenix.Component

  attr :class, :string, default: nil
  attr :placeholder, :string, default: ""
  attr :text, :string, default: ""
  attr :id, :string, required: true
  attr :name, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <i id={"#{@id}-icon"} class="absolute fa-solid fa-magnifying-glass pl-3 pt-3 h-4 w-4 "></i>
      <input
        id={"#{@id}-input"}
        phx-debounce="300"
        type="text"
        class="h-9 w-full rounded border pl-9 focus:ring-1 focus:ring-delivery-primary animate-none focus:outline-2 dark:bg-[#0F0D0F] dark:text-violet-100 text-base font-normal font-['Roboto']"
        placeholder={@placeholder}
        value={@text}
        name={@name}
      />
    </div>
    """
  end
end
