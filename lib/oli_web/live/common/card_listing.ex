defmodule OliWeb.Common.CardListing do
  use Phoenix.Component

  import OliWeb.Common.SourceImage

  alias OliWeb.Common.Utils
  alias OliWeb.Components.DesignTokens.Primitives.Badge
  alias OliWeb.Delivery.NewCourse.TableModel

  attr :model, :map, required: true
  attr :selected, :any, required: true
  attr :ctx, :map, required: true
  attr :preview_mode, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class="select-sources card-deck flex flex-wrap justify-center gap-4">
      <%= for item <- @model.rows do %>
        <%= if @preview_mode do %>
          <article class="course-card-link group mb-2" data-preview-mode="true">
            <.card_listing_card item={item} ctx={@ctx} preview_mode={true} />
          </article>
        <% else %>
          <a
            phx-click={@selected}
            class="course-card-link group mb-2 no-underline hover:no-underline"
            phx-value-id={action_id(item)}
            aria-label={card_aria_label(item)}
          >
            <.card_listing_card item={item} ctx={@ctx} />
          </a>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :ctx, :map, required: true
  attr :preview_mode, :boolean, default: false

  defp card_listing_card(assigns) do
    assigns =
      assigns
      |> assign(:tag_variant, TableModel.tag_variant(assigns.item))
      |> assign(:show_cost_badge?, TableModel.is_product?(assigns.item))

    ~H"""
    <div class={[
      "relative flex h-[296px] w-full max-w-[310px] flex-col overflow-hidden rounded-2xl border",
      "shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]",
      if(Map.get(@item, :selected),
        do: "!border-none !bg-delivery-primary-100 shadow-inner",
        else: "border-Border-border-default bg-Surface-surface-primary"
      ),
      if(@preview_mode, do: "!h-[23em] !w-[16.8em] select-none")
    ]}>
      <div class="relative h-[166px] w-full shrink-0 overflow-hidden">
        <img src={cover_image(@item)} class="h-full w-full object-cover" alt="course image" />
        <div class="pointer-events-none absolute inset-0 bg-[rgba(54,59,89,0.4)]" />
        <div class="pointer-events-none absolute inset-0 bg-gradient-to-b from-[rgba(0,0,0,0.1)] to-[rgba(0,50,99,0.4)] mix-blend-hard-light" />
      </div>

      <div class="flex flex-1 flex-col gap-2 overflow-hidden px-2 pt-3">
        <div :if={@tag_variant || @show_cost_badge?} class="flex items-center gap-2">
          <Badge.badge variant={@tag_variant} />
          <span
            :if={@show_cost_badge?}
            class="inline-flex w-fit items-center rounded bg-Fill-Chip-Green px-2 py-1 text-sm font-bold leading-none text-Text-text-accent-green"
          >
            {TableModel.render_payment_column(%{}, @item, nil)}
          </span>
        </div>

        <h5
          class="card-title-clamp text-lg font-semibold leading-6 text-Text-text-button"
          title={render_title_column(@item)}
        >
          {render_title_column(@item)}
        </h5>

        <p class="card-text text-sm leading-5 text-Text-text-high">
          {render_description(@item)}
        </p>
      </div>

      <div class="px-2 pb-3 text-xs leading-[19.2px] text-Text-text-low">
        {render_date(@item, @ctx)}
      </div>

      <div
        :if={@tag_variant == :my_section}
        class={[
          "pointer-events-none absolute inset-0 flex items-center justify-center px-8",
          "bg-[rgba(0,0,0,0.71)] text-center text-sm font-bold uppercase leading-4",
          "text-Text-text-white opacity-0 transition-opacity",
          "group-hover:opacity-100 group-focus-visible:opacity-100"
        ]}
      >
        Select to Copy Course Section
      </div>
    </div>
    """
  end

  defp card_aria_label(item) do
    title = TableModel.source_title(item)

    case TableModel.tag_variant(item) do
      :my_section -> "Select #{title} to copy this course section"
      _ -> "Select #{title}"
    end
  end

  defp render_title_column(item) do
    TableModel.source_title(item)
  end

  defp render_description(item) do
    TableModel.source_description(item)
  end

  defp render_date(item, ctx) do
    Utils.render_date(item, :inserted_at, ctx)
  end

  defp action_id(item) do
    TableModel.source_identifier(item)
  end
end
