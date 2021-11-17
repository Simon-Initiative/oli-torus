defmodule OliWeb.Sections.CreateGatingCondition do
  use Surface.LiveComponent

  alias Surface.Components.Form.DateTimeLocalInput
  alias Oli.Delivery.Gating.ConditionTypes

  prop gating_condition, :map, required: true
 
  def render(%{gating_condition: gating_condition} = assigns) do
    ~F"""
    <div class="container">
      <h3>Create a Gate</h3>
      <div class="form-group">
        <label for="resource">Resource</label>
        <div class="input-group mb-3">
          <input type="text" id="resource" readonly class="form-control" placeholder="Select a target resource..." aria-label="resource-title" aria-describedby="basic-addon2" phx-click="show-resource-picker" {...maybe_resource_value(assigns)}>
          <div class="input-group-append">
            <button class="btn btn-outline-primary" type="button" phx-click="show-resource-picker">Select</button>
          </div>
        </div>
      </div>
      <div class="form-group">
        <label for="conditionTypeSelect">Type</label>
        <select class="form-control" id="conditionTypeSelect" phx-hook="SelectListener" phx-value-change="select-condition">
          <option value="" selected disabled hidden>Choose a condition...</option>
          {#for {name, c} <- ConditionTypes.types()}
            <option value={c.type()}>{name}</option>
          {/for}
        </select>
      </div>

      {render_condition_options(assigns)}

      <div class="d-flex">
        <div class="flex-grow-1"></div>
        <button class="btn btn-outline-primary" phx-click="cancel-create-gate">Cancel</button>
        <button class="btn btn-primary ml-2" disabled={create_disabled(gating_condition)} phx-click="create_gate">Create</button>
      </div>
    </div>
    """
  end

  defp create_disabled(gating_condition) do
    case gating_condition do
      %{type: _, resource_id: _, section_id: _, data: _} -> false
      _ -> true
    end
  end

  def maybe_resource_value(%{gating_condition: %{resource_title: resource_title}}),
    do: [value: resource_title]

  def maybe_resource_value(_assigns), do: []

  def render_condition_options(%{gating_condition: %{type: :schedule}} = assigns) do
    ~F"""
    <div class="form-group">
      <label for="conditionTypeSelect">Start Date</label>
      <div phx-hook="DateTimeLocalInputListener" phx-value-change="schedule_start_date_changed" phx-update="ignore">
        <DateTimeLocalInput class="form-control" />
      </div>
    </div>
    <div class="form-group">
      <label for="conditionTypeSelect">End Date</label>
      <div phx-hook="DateTimeLocalInputListener" phx-value-change="schedule_end_date_changed" phx-update="ignore">
        <DateTimeLocalInput class="form-control" />
      </div>
    </div>
    """
  end

  def render_condition_options(_assigns), do: nil
end
