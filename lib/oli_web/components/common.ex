defmodule OliWeb.Components.Common do
  use Phoenix.Component

  def not_found(assigns) do
    ~H"""
    <main role="main" class="container mx-auto">
      <div class="alert alert-danger mt-3" role="alert">
        <h4 class="alert-heading">Not Found</h4>
        <p>The page you are trying to access does not exist. If you think this is an error, please contact support.</p>
        <hr>
        <p class="mb-0"><b>Tip:</b> Check the URL or link and try again.</p>
      </div>
    </main>
    """
  end

  @doc """
  Badge component for displaying a badge with a color
  """
  attr(:color, :atom, default: :red, values: [:red, :yellow, :green, :blue, :purple, :gray])
  slot(:inner_block, required: true)

  def badge(assigns) do
    assigns =
      assigns
      |> assign(
        :class,
        "text-xs font-medium mr-2 px-2.5 py-0.5 rounded border uppercase #{badge_color_classes(assigns[:color])}"
      )

    ~H"""
      <span class={@class}>
        <%= render_slot(@inner_block) %>
      </span>
    """
  end

  defp badge_color_classes(color) do
    case color do
      :red -> "bg-red-500 border-red-500 text-white"
      :yellow -> "bg-yellow-500 border-yellow-500 text-white"
      :green -> "bg-green-500 border-green-500 text-white"
      :blue -> "bg-blue-500 border-blue-500 text-white"
      :purple -> "bg-purple-500 border-purple-500 text-white"
      :gray -> "bg-gray-500 border-gray-500 text-white"
    end
  end
end
