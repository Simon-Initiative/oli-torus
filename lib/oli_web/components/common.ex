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
  Badge component
  """
  attr(:variant, :atom, default: nil, values: [:primary, :info, :success, :warning, :danger, nil])
  attr :class, :string, default: nil
  slot(:inner_block, required: true)

  def badge(assigns) do
    ~H"""
      <span
        class={[
          "text-xs font-medium mr-2 px-2.5 py-0.5 rounded border uppercase",
          badge_variant_classes(@variant),
          @class
        ]}>
        <%= render_slot(@inner_block) %>
      </span>
    """
  end

  defp badge_variant_classes(variant) do
    case variant do
      :primary -> "text-white bg-blue-500 border-blue-500"
      :info -> "text-white bg-gray-500 border-gray-500"
      :success -> "text-white bg-green-500 border-green-500"
      :warning -> "text-white bg-yellow-500 border-yellow-500"
      :danger -> "text-white bg-red-500 border-red-500"
      _ -> ""
    end
  end

  @doc """
  Button component

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr(:variant, :atom, default: nil, values: [:primary, :info, :success, :warning, :danger, nil])
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded text-sm px-3.5 py-2",
        button_variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_variant_classes(variant) do
    case variant do
      :primary -> "text-white bg-blue-500 hover:bg-blue-600 active:bg-blue-700 focus:ring-2 focus:ring-blue-400 dark:bg-blue-600 dark:hover:bg-blue-500 dark:active:bg-blue-400 focus:outline-none dark:focus:ring-blue-700"
      :info -> "text-white bg-gray-500 hover:bg-gray-600 active:bg-gray-700 focus:ring-2 focus:ring-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 dark:active:bg-gray-400 focus:outline-none dark:focus:ring-gray-700"
      :success -> "text-white bg-green-500 hover:bg-green-600 active:bg-green-700 focus:ring-2 focus:ring-green-400 dark:bg-green-600 dark:hover:bg-green-500 dark:active:bg-green-400 focus:outline-none dark:focus:ring-green-700"
      :warning -> "text-white bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700 focus:ring-2 focus:ring-yellow-400 dark:bg-yellow-600 dark:hover:bg-yellow-500 dark:active:bg-yellow-400 focus:outline-none dark:focus:ring-yellow-700"
      :danger -> "text-white bg-red-500 hover:bg-red-600 active:bg-red-700 focus:ring-2 focus:ring-red-400 dark:bg-red-600 dark:hover:bg-red-500 dark:active:bg-red-400 focus:outline-none dark:focus:ring-red-700"
      _ -> ""
    end
  end

end
