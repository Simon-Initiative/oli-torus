defmodule OliWeb.Products.Details.Edit do
  use Surface.Component

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import Ecto.Changeset

  prop product, :any, default: nil
  prop changeset, :any, default: nil
  prop available_brands, :any, default: nil
  prop is_admin, :boolean

  defp statuses do
    [{"Active", "active"}, {"Disabled", "deleted"}]
  end

  defp strategies do
    [
      {"Relative to section start", "relative_to_section"},
      {"Relative to student first access", "relative_to_student"}
    ]
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" action="#">

          <div class="form-row">

            <div class="form-group" style="width: 80%;">
              <%= label f, :title %>
              <%= text_input f, :title, class: "form-control" %>
              <div><%= error_tag f, :title %></div>
            </div>

            <div class="form-group ml-3">
              <%= label f, :status %>
              <%= select f, :status, statuses(), class: "form-control " <> error_class(f, :status, "is-invalid"),
                autofocus: focusHelper(f, :status) %>
              <div><%= error_tag f, :status %></div>
            </div>

          </div>

          <div class="form-group">
            <%= label f, :description %>
            <%= text_input f, :description, class: "form-control" %>
            <div><%= error_tag f, :description %></div>
          </div>

          <h5 class="mt-5 mb-3">Paywall Settings</h5>

          <div class="form-row">

            <div class="custom-control custom-switch" style="width: 200px;">
              <%= checkbox f, :requires_payment, disabled: !@is_admin, class: "custom-control-input" <> error_class(f, :requires_payment, "is-invalid"), autofocus: focusHelper(f, :requires_payment) %>
              <%= label f, :requires_payment, "Requires Payment", class: "custom-control-label" %>
              <%= error_tag f, :requires_payment %>
            </div>

            <div class="form-group">
              <%= label f, :amount %>
              <%= text_input f, :amount, class: "form-control", disabled: !@is_admin or !get_field(@changeset, :requires_payment)%>
              <div><%= error_tag f, :amount %></div>
            </div>

          </div>

          <div class="form-row">

            <div class="custom-control custom-switch" style="width: 200px;">
              <%= checkbox f, :has_grace_period,
                disabled: !@is_admin or !get_field(@changeset, :requires_payment),
                class: "custom-control-input" <> error_class(f, :has_grace_period, "is-invalid"), autofocus: focusHelper(f, :requires_payment) %>
              <%= label f, :has_grace_period, "Has Grace Period", class: "custom-control-label" %>
              <%= error_tag f, :has_grace_period %>
            </div>

            <div class="form-group" style="max-width: 200px;">
              <%= label f, :grace_period_days %>
              <%= text_input f, :grace_period_days, type: :number, class: "form-control", disabled: !@is_admin or !get_field(@changeset, :requires_payment) or !get_field(@changeset, :has_grace_period) %>
              <div><%= error_tag f, :grace_period_days %></div>
            </div>

            <div class="form-group ml-3" style="max-width: 230px;">
              <%= label f, :grace_period_strategy %>
              <%= select f, :grace_period_strategy, strategies(), disabled: !@is_admin or !get_field(@changeset, :requires_payment) or !get_field(@changeset, :has_grace_period),
                class: "form-control " <> error_class(f, :grace_period_strategy, "is-invalid"),
                autofocus: focusHelper(f, :grace_period_strategy) %>
              <div><%= error_tag f, :grace_period_strategy %></div>
            </div>

          </div>

          <%= submit "Save", class: "btn btn-primary" %>
        </.form>
      </div>
    """
  end
end
