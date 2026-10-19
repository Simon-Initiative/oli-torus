defmodule OliWeb.Common.TextSearch do
  @moduledoc """
  Hook-driven text search built on the shared design-system Search Bar.
  """

  use OliWeb, :live_component

  alias OliWeb.Components.DesignTokens.Primitives.SearchBar

  attr(:id, :string, required: true)
  attr(:reset, :string, default: "text_search_reset")
  attr(:change, :string, default: "text_search_change")
  attr(:placeholder, :string, default: "Search...")
  attr(:text, :string, default: "")
  attr(:event_target, :any, required: false, default: :live_view)
  attr(:tooltip, :string, required: false, default: nil)
  attr(:class, :string, default: "")
  attr(:aria_label, :string, default: "Search")

  @doc """
  Renders a hook-driven text search and optional explanatory tooltip.
  """
  def render(assigns) do
    assigns = assign(assigns, :phx_target, normalize_target(assigns.event_target))

    ~H"""
    <div class={"flex items-center max-w-[350px] #{@class}"}>
      <SearchBar.search_bar
        id={@id <> "-input"}
        type="text"
        value={@text}
        placeholder={@placeholder}
        aria_label={@aria_label}
        class="min-w-0 flex-1"
        on_clear={@reset}
        clear_target={@phx_target}
        clear_value_id={@id}
        phx-hook="TextInputListener"
        phx-hook-target={@event_target}
        phx-target={@phx_target}
        phx-value-change={@change}
      />
      <div :if={@tooltip} class="m-2 opacity-50 hover:cursor-help">
        <span
          id={@id <> "_tooltip"}
          title={@tooltip}
          class="fas fa-info-circle"
          phx-hook="TooltipInit"
        />
      </div>
    </div>
    """
  end

  def handle_delegated(event, params, socket, patch_fn) do
    delegate_handle_event(event, params, socket, patch_fn)
  end

  def delegate_handle_event("text_search_reset", %{"id" => _id}, socket, patch_fn) do
    patch_fn.(socket, %{text_search: "", offset: 0})
  end

  def delegate_handle_event("text_search_change", %{"value" => value}, socket, patch_fn) do
    patch_fn.(socket, %{text_search: value, offset: 0})
  end

  def delegate_handle_event(_, _, _, _) do
    :not_handled
  end

  defp normalize_target(target) when target in [:live_view, "live_view", nil], do: nil
  defp normalize_target(target), do: target
end
