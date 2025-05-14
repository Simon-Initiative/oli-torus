defmodule OliWeb.Products.Payments.Discounts.Form do
  use OliWeb, :html

  alias OliWeb.Common.Properties.ReadOnly

  attr(:form, :map, required: true)
  attr(:discount, :any, required: true)
  attr(:save, :any, required: true)
  attr(:change, :any, required: true)
  attr(:clear, :any)
  attr(:institution_name, :string)
  attr(:live_action, :atom)
  attr(:institutions, :list)

  def render(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@save} phx-change={@change}>
      <%= if @live_action != :product_new do %>
        <ReadOnly.render label="Institution" value={@institution_name} />
      <% else %>
        <div class="form-group">
          <.input
            type="select"
            field={@form[:institution_id]}
            label="Institution"
            prompt="Select institution"
            class="form-control"
            options={Enum.map(@institutions, &{&1.name, &1.id})}
          />
        </div>
      <% end %>

      <% bypass_paywall? = @form[:bypass_paywall].value in [true, "true"] %>

      <div class="form-group">
        <.input
          type="select"
          field={@form[:type]}
          label="Type"
          class={"form-control #{if(bypass_paywall?, do: "cursor-not-allowed", else: "")}"}
          options={[Percentage: "percentage", "Fixed price": "fixed_amount"]}
        />
      </div>

      <div class="form-group">
        <% price_disabled? =
          @form[:type].value in [:percentage, "percentage"] or bypass_paywall? %>
        <.input
          field={@form[:amount]}
          label="Price"
          class={"form-control #{if(price_disabled?, do: "cursor-not-allowed", else: "")}"}
          disabled={price_disabled?}
        />
      </div>

      <div class="form-group">
        <% percentage_disabled? =
          @form[:type].value in [:fixed_amount, "fixed_amount"] or bypass_paywall? %>
        <.input
          type="number"
          field={@form[:percentage]}
          label="Percentage"
          class={"form-control #{if(percentage_disabled?, do: "cursor-not-allowed", else: "")}"}
          min={0.1}
          max={99.9}
          step={0.1}
          disabled={percentage_disabled?}
        />
      </div>

      <div class="form-group">
        <.input field={@form[:bypass_paywall]} type="checkbox" label="Turn Off Paywall Entirely" />
      </div>

      <button type="submit" class="form-button btn btn-md btn-primary btn-block mt-3">Save</button>
    </.form>

    <%= if @live_action == :institution do %>
      <button
        class="btn btn-md btn-outline-danger float-right mt-3"
        phx-click="clear"
        disabled={is_nil(@discount)}
      >
        Clear
      </button>
    <% end %>
    """
  end
end
