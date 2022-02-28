defmodule OliWeb.Sections.GatingAndScheduling.Form do
  use Surface.LiveComponent
  use OliWeb.Common.Modal
  import OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Form.DateTimeLocalInput
  alias Oli.Delivery.Gating.ConditionTypes
  alias Surface.Components.{Link}

  prop section, :struct, required: true
  prop gating_condition, :map, required: true
  prop parent_gate, :struct, required: true
  prop count_exceptions, :integer, required: true
  prop create_or_update, :atom, default: :create

  def render(assigns) do
    ~F"""
    <div>
      {render_user_selection(assigns)}
      {render_resource_selection(assigns)}

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

      <div class="d-flex mb-5">
        <div :if={@create_or_update == :update}>
          <button class="btn btn-danger ml-2" phx-click="show-delete-gating-condition" phx-value-id={@gating_condition.id}>Delete</button>
        </div>
        <div class="flex-grow-1"></div>
        <Link class="btn btn-outline-primary" to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, @section.slug)}>
          Cancel
        </Link>
        <button class="btn btn-primary ml-2" disabled={create_disabled(@gating_condition, @parent_gate)} phx-click={create_or_update_action(@create_or_update)}>{create_or_update_name(@create_or_update)}</button>
      </div>

      {render_exceptions(assigns)}
    </div>
    """
  end

  defp render_user_selection(%{parent_gate: nil} = _assigns), do: nil

  defp render_user_selection(assigns) do
    ~F"""
    <div class="form-group">
      <label for="resource">Student</label>
      <div class="input-group mb-3">
        <input type="text" id="user" readonly class="form-control" placeholder="Select a student..." aria-label="resource-title" aria-describedby="basic-addon2" phx-click="show-resource-picker" {...maybe_user_value(assigns)}>
        <div class="input-group-append">
          <button class="btn btn-outline-primary" type="button" phx-click="show-user-picker">Select</button>
        </div>
      </div>
    </div>
    """
  end

  defp render_resource_selection(%{parent_gate: nil} = assigns) do
    ~F"""
    <div class="form-group">
      <label for="resource">Resource</label>
      <div class="input-group mb-3">
        <input type="text" id="resource" readonly class="form-control" placeholder="Select a target resource..." aria-label="resource-title" aria-describedby="basic-addon2" phx-click="show-resource-picker" {...maybe_resource_value(assigns)}>
        <div class="input-group-append">
          <button class="btn btn-outline-primary" type="button" phx-click="show-resource-picker">Select</button>
        </div>
      </div>
    </div>
    """
  end

  defp render_resource_selection(_assigns), do: nil

  defp render_exceptions(%{parent_gate: nil, gating_condition: gating_condition} = assigns) do
    if Map.has_key?(gating_condition, :id) do
      ~F"""
      <hr class="mt-5"/>
      <div class="alert alert-primary" role="alert">
        <div class="d-flex w-100 justify-content-between">
          This gate has {render_count(assigns.count_exceptions)}.
          <a class="btn btn-primary" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, assigns.section.slug, assigns.gating_condition.id)}>
            Manage Student Exceptions
          </a>
        </div>
      </div>
      """
    else
      nil
    end
  end

  defp render_exceptions(_), do: nil

  defp render_count(nil), do: ""
  defp render_count(1), do: "1 student-specific exception"
  defp render_count(n), do: "#{n} student-specific exceptions"

  defp create_disabled(gating_condition, parent_gate) do
    if is_nil(parent_gate) do
      case gating_condition do
        %{type: _, resource_id: _, section_id: _, data: _} -> false
        _ -> true
      end
    else
      case gating_condition do
        %{type: _, resource_id: _, section_id: _, data: _, user_id: _} -> false
        _ -> true
      end
    end
  end

  defp create_or_update_action(:create), do: "create_gate"
  defp create_or_update_action(:update), do: "update_gate"

  defp create_or_update_name(:create), do: "Create"
  defp create_or_update_name(:update), do: "Update"

  def maybe_resource_value(%{gating_condition: %{resource_title: resource_title}}),
    do: [value: resource_title]

  def maybe_resource_value(_assigns), do: []

  def maybe_user_value(%{gating_condition: %{user_id: nil}}), do: []

  def maybe_user_value(%{gating_condition: %{user: user}}),
    do: [value: name(user)]

  def maybe_user_value(_),
    do: []

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

  def render_condition_options(%{gating_condition: %{type: :always_open}} = assigns) do
    ~F"""
    <div class="alert alert-secondary" role="alert">
      This will always be open to this student.
    </div>
    """
  end

  def render_condition_options(_assigns), do: nil
end
