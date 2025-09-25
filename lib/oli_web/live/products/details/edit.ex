defmodule OliWeb.Products.Details.Edit do
  use OliWeb, :html

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import Ecto.Changeset

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Common

  defp statuses do
    [{"Active", "active"}, {"Archived", "archived"}]
  end

  defp strategies do
    [
      {"Relative to section start", "relative_to_section"},
      {"Relative to student first access", "relative_to_student"}
    ]
  end

  attr(:product, :any, default: nil)
  attr(:changeset, :any, default: nil)
  attr(:available_brands, :any, default: nil)
  attr(:publishers, :list, required: true)
  attr(:is_admin, :boolean)
  attr(:project_slug, :string, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" action="#">
        <div class="form-group mb-2">
          {label(f, :title)}
          {text_input(f, :title, class: "form-control")}
          <div>{error_tag(f, :title)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :status)}
          {select(f, :status, statuses(),
            class: "form-control " <> error_class(f, :status, "is-invalid"),
            autofocus: focusHelper(f, :status)
          )}
          <div>{error_tag(f, :status)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :description)}
          {text_input(f, :description, class: "form-control")}
          <div>{error_tag(f, :description)}</div>
        </div>

        <% welcome_title =
          (Common.fetch_field(f.source, :welcome_title) &&
             Common.fetch_field(f.source, :welcome_title)["children"]) || [] %>
        <Common.rich_text_editor_field
          id="welcome_title_field"
          form={f}
          value={welcome_title}
          field_name={:welcome_title}
          field_label="Welcome Message Title"
          on_edit="welcome_title_change"
          project_slug={@project_slug}
          ctx={@ctx}
        />

        <div class="form-group mb-2">
          {label(f, :encouraging_subtitle, "Encouraging Subtitle", class: "control-label")}

          {textarea(f, :encouraging_subtitle,
            class: "form-control",
            placeholder: "Enter a subtitle to encourage students to begin the course...",
            required: false
          )}
          <div>{error_tag(f, :encouraging_subtitle)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :publisher_id, "Product Publisher")}
          {select(f, :publisher_id, Enum.map(@publishers, &{&1.name, &1.id}),
            class: "form-control " <> error_class(f, :publisher_id, "is-invalid"),
            autofocus: focusHelper(f, :publisher_id),
            required: true
          )}
          <div>{error_tag(f, :publisher_id)}</div>
        </div>

        <h5 class="mt-5 mb-3">Paywall Settings</h5>

        <div class="form-row">
          <div class="custom-control custom-switch fixed-width">
            {checkbox(f, :requires_payment,
              disabled: !@is_admin,
              class: "custom-control-input" <> error_class(f, :requires_payment, "is-invalid"),
              autofocus: focusHelper(f, :requires_payment)
            )}
            {label(f, :requires_payment, "Requires Payment", class: "custom-control-label")}
            {error_tag(f, :requires_payment)}
          </div>

          <div class="form-group mb-2">
            {label(f, :amount)}
            {text_input(f, :amount,
              class: "form-control",
              disabled: !@is_admin or !get_field(@changeset, :requires_payment)
            )}
            <div>{error_tag(f, :amount)}</div>
          </div>

          <div class="custom-control custom-switch fixed-width">
            {checkbox(f, :pay_by_institution,
              disabled: !@is_admin or !get_field(@changeset, :requires_payment),
              class: "custom-control-input" <> error_class(f, :pay_by_institution, "is-invalid"),
              autofocus: focusHelper(f, :pay_by_institution)
            )}
            {label(f, :pay_by_institution, "Pay by institution", class: "custom-control-label")}
            {error_tag(f, :pay_by_institution)}
          </div>
        </div>

        <div class="form-row mb-2">
          <div class="custom-control custom-switch fixed-width">
            {checkbox(f, :has_grace_period,
              disabled: !@is_admin or !get_field(@changeset, :requires_payment),
              class: "custom-control-input" <> error_class(f, :has_grace_period, "is-invalid"),
              autofocus: focusHelper(f, :requires_payment)
            )}
            {label(f, :has_grace_period, "Has Grace Period", class: "custom-control-label")}
            {error_tag(f, :has_grace_period)}
          </div>
        </div>

        <div class="form-group mb-2 max-w-sm">
          {label(f, :grace_period_days)}
          {text_input(f, :grace_period_days,
            type: :number,
            class: "form-control",
            disabled:
              !@is_admin or !get_field(@changeset, :requires_payment) or
                !get_field(@changeset, :has_grace_period)
          )}
          <div>{error_tag(f, :grace_period_days)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :grace_period_strategy)}
          {select(f, :grace_period_strategy, strategies(),
            disabled:
              !@is_admin or !get_field(@changeset, :requires_payment) or
                !get_field(@changeset, :has_grace_period),
            class: "form-control " <> error_class(f, :grace_period_strategy, "is-invalid"),
            autofocus: focusHelper(f, :grace_period_strategy)
          )}
          <div>{error_tag(f, :grace_period_strategy)}</div>
        </div>

        <div class="form-row float-right">
          <%= if @is_admin and get_field(@changeset, :requires_payment) do %>
            <a
              class="btn btn-link action-button"
              href={
                Routes.live_path(
                  OliWeb.Endpoint,
                  OliWeb.Products.Payments.Discounts.ProductsIndexView,
                  @product.slug
                )
              }
            >
              Manage Discounts
            </a>
          <% end %>
        </div>

        {submit("Save", class: "btn btn-primary")}
      </.form>
    </div>
    """
  end
end
