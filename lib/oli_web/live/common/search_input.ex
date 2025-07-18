defmodule OliWeb.Common.SearchInput do
  use Phoenix.Component

  attr :class, :string, default: nil
  attr :placeholder, :string, default: ""
  attr :text, :string, default: ""
  attr :id, :string, required: true
  attr :name, :string, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "w-56 h-[35px] inline-flex items-center gap-2 px-2 py-1 rounded-md outline outline-1 outline-[#ced1d9] bg-[#ffffff] dark:bg-[#2A282E] dark:outline-[#2A282E]",
      @class
    ]}>
      <i class="fa-solid fa-magnifying-glass text-[#757682] w-4 h-4 dark:text-[#BAB8BF]"></i>
      <input
        id={"#{@id}-input"}
        phx-debounce="300"
        type="text"
        class="w-full p-0 bg-transparent border-none outline-none ring-0 focus:outline-none focus:ring-0 text-[#353740] text-base font-normal placeholder:text-[#757682]"
        placeholder={@placeholder}
        value={@text}
        name={@name}
      />
    </div>
    """
  end
end
