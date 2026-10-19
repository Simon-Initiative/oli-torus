defmodule OliWeb.Common.SearchInput do
  @moduledoc """
  Compatibility wrapper for design-system search fields driven by parent forms.
  """

  use Phoenix.Component

  alias OliWeb.Components.DesignTokens.Primitives.SearchBar

  attr :class, :string, default: nil
  attr :placeholder, :string, default: ""
  attr :text, :string, default: ""
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :aria_label, :string, required: true

  @doc """
  Renders a debounced search input using the shared Search Bar primitive.
  """
  def render(assigns) do
    ~H"""
    <SearchBar.search_bar
      id={"#{@id}-input"}
      name={@name}
      type="text"
      value={@text}
      placeholder={@placeholder}
      aria_label={@aria_label}
      class={@class}
      phx-debounce="300"
    />
    """
  end
end
