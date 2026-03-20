defmodule OliWeb.Products.Details.Content do
  use OliWeb, :html

  alias OliWeb.Router.Helpers, as: Routes

  attr(:product, :any, required: true)
  attr(:updates, :any, required: true)
  attr(:changeset, :any, default: nil)
  attr(:save, :any, required: true)
  attr(:schedule_url, :string, default: nil)

  def render(assigns) do
    ~H"""
    <% updates_count = Enum.count(@updates) %>
    <div>
      <div class="flex flex-col gap-3">
        <h5 class="font-semibold text-[18px] leading-[24px] m-0">Updates</h5>
        <div class="flex flex-col gap-[6px]">
          <p :if={updates_count == 0} class="text-[16px] leading-[24px] m-0">
            There are <b>no updates</b> available for this template.
          </p>
          <div :if={updates_count > 0} class="flex items-center gap-[6px]">
            <p class="text-[16px] leading-[24px] m-0">
              {ngettext(
                "There is <b>one available update</b> for this template",
                "There are <b>%{count} available updates</b> for this template",
                updates_count
              )
              |> raw()}
            </p>
            <span
              id="manage-source-materials-updates-badge"
              class="inline-flex items-center rounded-full bg-Fill-Buttons-fill-primary px-[6px] py-[4px] text-[12px] font-semibold leading-[12px] text-Text-text-white"
            >
              {ngettext("1 update", "%{count} updates", updates_count)}
            </span>
          </div>
          <.link
            :if={updates_count > 0}
            href={
              Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, @product.slug)
            }
            class="text-Text-text-button hover:text-Text-text-button-hover font-bold text-[14px] leading-[16px] py-1 whitespace-nowrap"
          >
            Manage source materials
          </.link>
          <.link
            href={Routes.product_remix_path(OliWeb.Endpoint, :product_remix, @product.slug)}
            class="text-Text-text-button hover:text-Text-text-button-hover font-bold text-[14px] leading-[16px] py-1 whitespace-nowrap"
          >
            Customize content
          </.link>
          <.link
            :if={@schedule_url}
            href={@schedule_url}
            class="text-Text-text-button hover:text-Text-text-button-hover font-bold text-[14px] leading-[16px] py-1 whitespace-nowrap"
          >
            Edit scheduling and assessment settings
          </.link>
        </div>
      </div>

      <.form for={@changeset} phx-change={@save}>
        <div class="flex flex-col gap-[6px] mt-3">
          <.input
            type="checkbox"
            field={@changeset[:apply_major_updates]}
            label="Apply major updates to course sections"
            aria-describedby="apply-major-updates-desc"
          />
          <p id="apply-major-updates-desc" class="text-[14px] leading-[24px] text-Text-text-low m-0">
            Allow major project publications to be applied to course sections created from this template
          </p>
        </div>

        <div class="flex flex-col gap-[6px] mt-4">
          <h5 class="font-semibold text-[18px] leading-[24px] m-0">Presentation</h5>
          <.input
            type="checkbox"
            field={@changeset[:display_curriculum_item_numbering]}
            label="Display curriculum item numbers"
            aria-describedby="display-curriculum-numbering-desc"
          />
          <p
            id="display-curriculum-numbering-desc"
            class="text-[14px] leading-[24px] text-Text-text-low m-0"
          >
            Enable students to see the curriculum's module and unit numbers
          </p>
        </div>
      </.form>
    </div>
    """
  end
end
