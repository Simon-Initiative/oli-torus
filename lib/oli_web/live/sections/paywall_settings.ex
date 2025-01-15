defmodule OliWeb.Sections.PaywallSettings do
  use OliWeb, :html

  alias OliWeb.Common.Properties.Group
  import Phoenix.HTML.Form, only: [normalize_value: 2]

  defp strategies do
    [
      {"Relative to section start", "relative_to_section"},
      {"Relative to student first access", "relative_to_student"}
    ]
  end

  defp payment_options_choices do
    [
      {"Pay by credit card only", "direct"},
      {"Pay by payment code only", "deferred"},
      {"Pay by credit card or payment code", "direct_and_deferred"}
    ]
  end

  attr :form, :any, required: true
  attr :disabled, :boolean, required: true

  def render(assigns) do
    ~H"""
    <Group.render
      label="Payment Settings"
      description="Settings related to required student fee and optional grace period"
    >
      <div class="form-check">
        <.input
          type="checkbox"
          field={@form[:requires_payment]}
          label="Requires payment"
          class="form-check-input"
          disabled={@disabled}
        />
      </div>
      <div class="mt-2 form-label-group">
        <.input
          field={@form[:amount]}
          label="Amount"
          class="form-control"
          disabled={@disabled or !get_boolean_value(@form[:requires_payment])}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="select"
          field={@form[:payment_options]}
          label="Payment options"
          class="form-control"
          options={payment_options_choices()}
          disabled={@disabled or !@form[:payment_options].value}
        />
      </div>
      <%= unless get_boolean_value(@form[:open_and_free]) do %>
        <div class="form-check">
          <.input
            type="checkbox"
            field={@form[:pay_by_institution]}
            label="Pay by institution"
            class="form-check-input"
            disabled={@disabled or !get_boolean_value(@form[:requires_payment])}
          />
        </div>
      <% end %>
      <div class="form-check">
        <.input
          type="checkbox"
          field={@form[:has_grace_period]}
          label="Has grace period"
          class="form-check-input"
          disabled={@disabled or !get_boolean_value(@form[:requires_payment])}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="number"
          field={@form[:grace_period_days]}
          label="Grace period days"
          class="form-control"
          disabled={
            @disabled or !get_boolean_value(@form[:requires_payment]) or
              !get_boolean_value(@form[:has_grace_period])
          }
        />
      </div>
      <div class="form-label-group">
        <.input
          type="select"
          field={@form[:grace_period_strategy]}
          label="Grace period strategy"
          class="form-control"
          options={strategies()}
          disabled={
            @disabled or !get_boolean_value(@form[:requires_payment]) or
              !get_boolean_value(@form[:has_grace_period])
          }
        />
      </div>

      <button :if={!@disabled} class="btn btn-primary mt-3" type="submit">Save</button>
    </Group.render>
    """
  end

  defp get_boolean_value(field = %Phoenix.HTML.FormField{}) do
    normalize_value("checkbox", field.value)
  end
end
