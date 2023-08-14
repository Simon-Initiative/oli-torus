defmodule OliWeb.Sections.PaywallSettings do
  use OliWeb, :html

  alias OliWeb.Common.Properties.Group
  import Ecto.Changeset

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

  attr :changeset, :any, required: true
  attr :disabled, :boolean, required: true

  def render(assigns) do
    ~H"""
    <Group.render
      label="Payment Settings"
      description="Settings related to requried student fee and optional grace periody"
    >
      <div class="form-check">
        <input
          id="requires_payment"
          type="checkbox"
          name="section[requires_payment]"
          class="form-check-input"
          checked={get_field(@changeset, :requires_payment)}
          disabled={@disabled}
        />
        <label for="requires_payment" class="form-check-label">Requires payment</label>
      </div>
      <div class="mt-2 form-label-group">
        <div class="flex justify-between">
          <label for="amount" class="form-check-label">Amount</label>
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :amount)}>
            <%= translate_error(error) %>
          </.error>
        </div>
        <.input
          id="amount"
          name="section[amount]"
          value={get_field(@changeset, :amount)}
          class="form-control"
          disabled={@disabled or !get_field(@changeset, :requires_payment)}
        />
      </div>
      <div class="form-label-group">
        <label for="payment_options">Payment options</label>
        <.input
          id="payment_options"
          type="select"
          class="form-control"
          name="section[payment_options]"
          value={get_field(@changeset, :payment_options)}
          options={payment_options_choices()}
          disabled={
            @disabled or !get_field(@changeset, :payment_options) or
              !get_field(@changeset, :payment_options)
          }
        />
      </div>
      <%= unless get_field(@changeset, :open_and_free) do %>
        <div class="form-check">
          <input
            id="pay_by_institution"
            type="checkbox"
            name="section[pay_by_institution]"
            class="form-check-input"
            checked={get_field(@changeset, :pay_by_institution)}
            disabled={@disabled or !get_field(@changeset, :requires_payment)}
          />
          <label for="pay_by_institution" class="form-check-label">Pay by institution</label>
        </div>
      <% end %>
      <div class="form-check">
        <input
          id="has_grace_period"
          type="checkbox"
          name="section[has_grace_period]"
          class="form-check-input"
          checked={get_field(@changeset, :has_grace_period)}
          disabled={@disabled or !get_field(@changeset, :requires_payment)}
        />
        <label for="has_grace_period" class="form-check-label">Has grace period</label>
      </div>
      <div class="form-label-group">
        <label for="grace_period_days">Grace period days</label>
        <.input
          id="grace_period_days"
          type="number"
          class="form-control"
          name="section[grace_period_days]"
          value={get_field(@changeset, :grace_period_days)}
          disabled={
            @disabled or !get_field(@changeset, :requires_payment) or
              !get_field(@changeset, :has_grace_period)
          }
        />
        <.error :for={error <- Keyword.get_values(@changeset.errors || [], :grace_period_days)}>
          <%= translate_error(error) %>
        </.error>
      </div>
      <div class="form-label-group">
        <label for="grace_period_strategy">Grace period strategy</label>
        <.input
          id="grace_period_strategy"
          type="select"
          class="form-control"
          name="section[grace_period_strategy]"
          value={get_field(@changeset, :grace_period_strategy)}
          options={strategies()}
          disabled={
            @disabled or !get_field(@changeset, :requires_payment) or
              !get_field(@changeset, :has_grace_period)
          }
        />
      </div>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group.render>
    """
  end
end
