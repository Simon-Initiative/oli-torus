defmodule OliWeb.Sections.GatingAndScheduling.Form do
  use Surface.LiveComponent
  use OliWeb.Common.Modal

  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Form.DateTimeLocalInput
  alias Oli.Delivery.Gating.ConditionTypes
  alias Surface.Components.{Link}

  prop section, :struct, required: true
  prop gating_condition, :map, required: true
  prop create_or_update, :atom, default: :create

  def render(assigns) do
    ~F"""
    <div>
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
          <option {...maybe_type_selected(assigns, :default)} disabled hidden>Choose a condition...</option>
          {#for {name, c} <- ConditionTypes.types()}
            <option value={c.type()} {...maybe_type_selected(assigns, c.type())}>{name}</option>
          {/for}
        </select>
      </div>

      {render_condition_options(assigns)}

      <div class="d-flex">
        <div :if={@create_or_update == :update}>
          <button class="btn btn-danger ml-2" phx-click="delete-gating-condition" phx-value-id={@gating_condition.id}>Delete</button>
        </div>
        <div class="flex-grow-1"></div>
        <Link class="btn btn-outline-primary" to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, @section.slug)}>
          Cancel
        </Link>
        <button class="btn btn-primary ml-2" disabled={create_disabled(@gating_condition)} phx-click={create_or_update_action(@create_or_update)}>{create_or_update_name(@create_or_update)}</button>
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

  defp create_or_update_action(:create), do: "create_gate"
  defp create_or_update_action(:update), do: "update_gate"

  defp create_or_update_name(:create), do: "Create"
  defp create_or_update_name(:update), do: "Update"

  def maybe_resource_value(%{gating_condition: %{resource_title: resource_title}}),
    do: [value: resource_title]

  def maybe_resource_value(_assigns), do: []

  def maybe_type_selected(%{gating_condition: %{type: type}}, t) when type == t,
    do: [selected: true]

  def maybe_type_selected(%{gating_condition: %{type: _type}}, _), do: []

  def maybe_type_selected(_assigns, :default), do: [selected: true]
  def maybe_type_selected(_assigns, _), do: []

  def render_condition_options(%{gating_condition: %{type: :schedule, data: data}} = assigns) do
    initial_start_date = Map.get(data, :start_datetime)
    initial_end_date = Map.get(data, :end_datetime)

    ~F"""
    <div class="form-group">
      <label for="conditionTypeSelect">Start Date</label>
      <div id="start_date" phx-hook="DateTimeLocalInputListener" phx-value-change="schedule_start_date_changed" phx-update="ignore">
        <DateTimeLocalInput class="form-control" value={initial_start_date}/>
      </div>
    </div>
    <div class="form-group">
      <label for="conditionTypeSelect">End Date</label>
      <div id="end_date" phx-hook="DateTimeLocalInputListener" phx-value-change="schedule_end_date_changed" phx-update="ignore">
        <DateTimeLocalInput class="form-control" value={initial_end_date} />
      </div>
    </div>
    """
  end

  def render_condition_options(_assigns), do: nil
end
