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

      <div class="form-group">
        <label for="gradingPolicySelect">Graded Resource Policy</label>
        <select class="form-control" id="gradingPolicySelect" phx-hook="SelectListener" phx-value-change="select-grading-policy">
          {#for policy <- Oli.Delivery.Gating.GatingCondition.graded_resource_policies()}
            <option value={policy} {...policy_selected(assigns, policy)}>{policy_desc(policy)}</option>
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
        <input type="text" id="user" readonly class="form-control" placeholder="Select a student..." aria-label="resource-title" aria-describedby="basic-addon2" phx-click="show-user-picker" {...maybe_user_value(assigns)}>
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
        %{type: type, resource_id: _, section_id: _}
        when type in [:started, :finished] ->
          case Map.get(gating_condition.data, :resource_id) do
            nil -> true
            _ -> false
          end

        %{type: _, resource_id: _, section_id: _, data: _} ->
          false

        _ ->
          true
      end
    else
      case gating_condition do
        %{type: type, resource_id: _, section_id: _}
        when type in [:started, :finished] ->
          case Map.get(gating_condition.data, :resource_id) do
            nil -> true
            _ -> false
          end

        %{type: _, resource_id: _, section_id: _, data: _, user_id: _} ->
          false

        _ ->
          true
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

  def maybe_source_value(%{gating_condition: %{source_title: resource_title}}),
    do: [value: resource_title]

  def maybe_source_value(_assigns), do: []

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

  def policy_selected(%{gating_condition: %{graded_resource_policy: policy}}, p) when policy == p,
    do: [selected: true]

  def policy_selected(_, _), do: []

  def policy_desc(:allows_nothing), do: "Allow no access at all to graded pages"
  def policy_desc(:allows_review), do: "Allow the review of previously completed attempts"

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

  def render_condition_options(%{gating_condition: %{type: :started}} = assigns) do
    ~F"""
    <div class="form-group">
      <label for="source">Resource That Must Be Started</label>
      <div class="input-group mb-3">
        <input type="text" id="source" readonly class="form-control" placeholder="Select a source resource..." aria-label="resource-title" aria-describedby="basic-addon2" phx-click="show-all-picker" {...maybe_source_value(assigns)}>
        <div class="input-group-append">
          <button class="btn btn-outline-primary" type="button" phx-click="show-all-picker">Select</button>
        </div>
      </div>
    </div>
    """
  end

  def render_condition_options(%{gating_condition: %{type: :finished, data: data}} = assigns) do
    ~F"""
    <div class="form-group">
      <label for="source">Resource That Must Be Finished</label>
      <div class="input-group mb-3">
        <input type="text" id="source" readonly class="form-control" placeholder="Select a source resource..." aria-label="resource-title" aria-describedby="basic-addon2" phx-click="show-graded-picker" {...maybe_source_value(assigns)}>
        <div class="input-group-append">
          <button class="btn btn-outline-primary" type="button" phx-click="show-graded-picker">Select</button>
        </div>
      </div>
    </div>

    <div class="form-check">
      <input class="form-check-input" type="checkbox" value="" id="min-score" checked={checked_from_min_score(data)} phx-click="toggle_min_score">
      <label class="form-check-label" for="min-score">
        Require a minimum score (as a percentage)
      </label>
    </div>
    <div class="mb-4 row mt-2 ml-3">
      <div class="col-sm-2">
        <input type="number" class="form-control" id="min-score-value"
          disabled={!checked_from_min_score(data)}
          min="0" max="100" value={value_from_min_score(data)} phx-hook="TextInputListener" phx-value-change="change_min_score">
      </div>
      <label for="min-score-value" class="col-sm-1 col-form-label">%</label>
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

  defp value_from_min_score(%{minimum_percentage: nil}), do: ""

  defp value_from_min_score(%{minimum_percentage: percentage}) do
    Float.to_string(percentage * 100)
  end

  defp value_from_min_score(_), do: ""

  defp checked_from_min_score(%{minimum_percentage: nil}), do: false

  defp checked_from_min_score(%{minimum_percentage: _}), do: true

  defp checked_from_min_score(_), do: false
end
