defmodule OliWeb.Products.Details.TemplateUpdatesBanner do
  use OliWeb, :html

  alias OliWeb.Components.DesignTokens.Primitives.Button

  attr :count, :integer, required: true
  attr :storage_key, :string, required: true

  def render(%{count: count} = assigns) when count > 0 do
    ~H"""
    <div
      id={"template-updates-banner-#{String.replace(@storage_key, ":", "-")}"}
      phx-hook="SessionBannerDismiss"
      data-storage-key={@storage_key}
      class="mb-5 hidden rounded-[6px] bg-[#CED9F2] px-6 py-4"
      role="status"
    >
      <div class="flex items-center gap-4">
        <p class="m-0 flex-1 text-[16px] font-medium leading-6 text-[#45464C]">
          <%= if @count == 1 do %>
            There is <span class="font-bold">1 available update</span> for this template.
          <% else %>
            There are <span class="font-bold">{@count} available updates</span> for this template.
          <% end %>
        </p>
        <Button.button
          variant={:close}
          aria-label="Dismiss template updates banner"
          data-banner-dismiss
        />
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    """
  end
end
