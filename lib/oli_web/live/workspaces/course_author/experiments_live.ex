defmodule OliWeb.Workspaces.CourseAuthor.ExperimentsLive do
  use OliWeb, :live_view
  use Phoenix.HTML
  use OliWeb.Common.Modal

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.Components.Common
  import OliWeb.ErrorHelpers
  import OliWeb.Resources.AlternativesEditor.GroupOption

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Experiments, as: LegacyExperiments
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Experiments, as: ABExperiments
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Institutions
  alias OliWeb.Common.Modal.{DeleteModal, FormModal}

  @default_error_message "Something went wrong. Please refresh the page and try again."

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project
    experiment = LegacyExperiments.get_latest_experiment(project.slug)
    socket = assign_authoring_experiments(socket)

    {:ok,
     assign(socket,
       ab_testing_enabled: project.has_experiments,
       experiment: experiment,
       resource_slug: project.slug,
       resource_title: project.title
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Experiments</h2>
    {render_modal(assigns)}

    <h3>A/B Testing</h3>
    <p>
      A/B testing is a Torus feature for creating and managing experiments in this project.
    </p>
    <.input
      type="checkbox"
      class="form-check-input"
      name="experiments"
      value={@ab_testing_enabled}
      label="Enable A/B testing"
      phx-click="toggle_ab_testing"
      checked={@ab_testing_enabled}
    />

    <%= if @experiment do %>
      <OliWeb.Resources.AlternativesEditor.group
        group={@experiment}
        editing_enabled={false}
        source={:experiments}
      />
    <% end %>

    <section class="mt-4">
      <h4>A/B Testing experiments</h4>

      <%= if @experiment_error do %>
        <div class="alert alert-danger" role="alert">{@experiment_error}</div>
      <% end %>

      <%= if @experiment_success do %>
        <div class="alert alert-success" role="status">{@experiment_success}</div>
      <% end %>

      <%= if Enum.empty?(@ab_experiments) do %>
        <div>No A/B Testing experiments have been created yet.</div>
      <% else %>
        <table class="table table-sm" id="ab-experiments-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Slug</th>
              <th>Algorithm</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={experiment <- @ab_experiments} id={"ab-experiment-#{experiment.id}"}>
              <td>{experiment.name}</td>
              <td>{experiment.slug}</td>
              <td>{format_algorithm(experiment.algorithm)}</td>
              <td>{format_state(experiment.state)}</td>
              <td>
                <button
                  :if={experiment.state in [:draft, :paused]}
                  type="button"
                  class="btn btn-sm btn-primary"
                  phx-click="start_experiment"
                  phx-value-id={experiment.id}
                >
                  Start
                </button>
                <button
                  :if={experiment.state == :active}
                  type="button"
                  class="btn btn-sm btn-secondary"
                  phx-click="pause_experiment"
                  phx-value-id={experiment.id}
                >
                  Pause
                </button>
                <button
                  :if={experiment.state in [:active, :paused]}
                  type="button"
                  class="btn btn-sm btn-secondary"
                  phx-click="complete_experiment"
                  phx-value-id={experiment.id}
                >
                  Complete
                </button>
                <button
                  :if={experiment.state != :archived}
                  type="button"
                  class="btn btn-sm btn-outline-danger"
                  phx-click="archive_experiment"
                  phx-value-id={experiment.id}
                >
                  Archive
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      <% end %>

      <div class="mt-3">
        <h5>Create A/B Testing experiment</h5>
        <%= if Enum.empty?(@decision_point_candidates) do %>
          <div>Create an A/B decision point before adding an A/B Testing experiment.</div>
        <% else %>
          <.form
            for={@experiment_form}
            id="create-ab-experiment-form"
            phx-change="change_experiment_form"
            phx-submit="create_experiment"
          >
            <div class="form-group">
              <label for="experiment_name">Name</label>
              <input id="experiment_name" class="form-control" name="experiment[name]" required />
            </div>
            <div class="form-group">
              <label for="experiment_slug">Slug</label>
              <input id="experiment_slug" class="form-control" name="experiment[slug]" required />
            </div>
            <div class="form-group">
              <label for="experiment_decision_point">A/B decision point</label>
              <select
                id="experiment_decision_point"
                class="form-control"
                name="experiment[decision_point]"
                required
              >
                <option
                  :for={candidate <- @decision_point_candidates}
                  value={candidate.alternatives_revision_id}
                >
                  {candidate.title}
                </option>
              </select>
            </div>
            <div class="form-group">
              <label for="experiment_algorithm">Assignment policy</label>
              <select
                id="experiment_algorithm"
                class="form-control"
                name="experiment[algorithm]"
              >
                <option value="weighted_random" selected={@experiment_algorithm == "weighted_random"}>
                  Weighted random
                </option>
                <option
                  value="thompson_sampling"
                  selected={@experiment_algorithm == "thompson_sampling"}
                >
                  Thompson Sampling
                </option>
              </select>
            </div>
            <div class="form-group">
              <label for="experiment_weight_a">First condition weight</label>
              <input
                id="experiment_weight_a"
                class="form-control"
                type="number"
                min="0"
                step="0.01"
                name="experiment[weight_a]"
                value="1"
                required
              />
            </div>
            <div class="form-group">
              <label for="experiment_weight_b">Second condition weight</label>
              <input
                id="experiment_weight_b"
                class="form-control"
                type="number"
                min="0"
                step="0.01"
                name="experiment[weight_b]"
                value="1"
                required
              />
            </div>
            <%= if @experiment_algorithm == "thompson_sampling" do %>
              <div class="border rounded p-3 mb-3" id="thompson-sampling-config">
                <h6>Thompson Sampling configuration</h6>
                <div class="form-row">
                  <div class="form-group col-md-6">
                    <label for="experiment_prior_alpha">Default prior successes</label>
                    <input
                      id="experiment_prior_alpha"
                      class={"form-control #{field_error_class(@experiment_field_errors, :prior_alpha)}"}
                      type="number"
                      min="0.0001"
                      max="1000"
                      step="0.0001"
                      name="experiment[prior_alpha]"
                      value="1"
                      aria-invalid={field_invalid?(@experiment_field_errors, :prior_alpha)}
                      aria-describedby="experiment_prior_alpha_help experiment_prior_alpha_error"
                    />
                    <small id="experiment_prior_alpha_help" class="form-text text-muted">
                      Initial success evidence for each condition, from 0.0001 to 1000.
                    </small>
                    <%= if error = field_error(@experiment_field_errors, :prior_alpha) do %>
                      <div id="experiment_prior_alpha_error" class="invalid-feedback d-block">
                        {error}
                      </div>
                    <% end %>
                  </div>
                  <div class="form-group col-md-6">
                    <label for="experiment_prior_beta">Default prior failures</label>
                    <input
                      id="experiment_prior_beta"
                      class={"form-control #{field_error_class(@experiment_field_errors, :prior_beta)}"}
                      type="number"
                      min="0.0001"
                      max="1000"
                      step="0.0001"
                      name="experiment[prior_beta]"
                      value="1"
                      aria-invalid={field_invalid?(@experiment_field_errors, :prior_beta)}
                      aria-describedby="experiment_prior_beta_help experiment_prior_beta_error"
                    />
                    <small id="experiment_prior_beta_help" class="form-text text-muted">
                      Initial failure evidence for each condition, from 0.0001 to 1000.
                    </small>
                    <%= if error = field_error(@experiment_field_errors, :prior_beta) do %>
                      <div id="experiment_prior_beta_error" class="invalid-feedback d-block">
                        {error}
                      </div>
                    <% end %>
                  </div>
                </div>
                <div class="form-row">
                  <div class="form-group col-md-6">
                    <label for="experiment_warm_up_assignments">Warm-up assignments</label>
                    <input
                      id="experiment_warm_up_assignments"
                      class={"form-control #{field_error_class(@experiment_field_errors, :warm_up_assignments)}"}
                      type="number"
                      min="0"
                      step="1"
                      name="experiment[warm_up_assignments]"
                      value="0"
                      aria-invalid={field_invalid?(@experiment_field_errors, :warm_up_assignments)}
                      aria-describedby="experiment_warm_up_assignments_help experiment_warm_up_assignments_error"
                    />
                    <small id="experiment_warm_up_assignments_help" class="form-text text-muted">
                      Number of initial assignments served evenly before adaptive sampling.
                    </small>
                    <%= if error = field_error(@experiment_field_errors, :warm_up_assignments) do %>
                      <div id="experiment_warm_up_assignments_error" class="invalid-feedback d-block">
                        {error}
                      </div>
                    <% end %>
                  </div>
                  <div class="form-group col-md-6">
                    <label for="experiment_max_condition_share">
                      Maximum traffic share per condition
                    </label>
                    <input
                      id="experiment_max_condition_share"
                      class={"form-control #{field_error_class(@experiment_field_errors, :max_condition_share)}"}
                      type="number"
                      min="0.01"
                      max="1"
                      step="0.01"
                      name="experiment[max_condition_share]"
                      value="1"
                      aria-invalid={field_invalid?(@experiment_field_errors, :max_condition_share)}
                      aria-describedby="experiment_max_condition_share_help experiment_max_condition_share_error"
                    />
                    <small id="experiment_max_condition_share_help" class="form-text text-muted">
                      Highest allowed assignment share for one condition, from 0.01 to 1.0.
                    </small>
                    <%= if error = field_error(@experiment_field_errors, :max_condition_share) do %>
                      <div id="experiment_max_condition_share_error" class="invalid-feedback d-block">
                        {error}
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
            <button type="submit" class="btn btn-primary">Create experiment</button>
          </.form>
        <% end %>
      </div>
    </section>
    """
  end

  def handle_event("toggle_ab_testing", _params, socket) do
    {:ok, updated_project = %Project{}} =
      Course.update_project(socket.assigns.project, %{
        has_experiments: !socket.assigns.project.has_experiments
      })

    {:noreply,
     assign(socket,
       ab_testing_enabled: updated_project.has_experiments,
       project: updated_project
     )}
  end

  def handle_event("create_experiment", %{"experiment" => params}, socket) do
    scope = authoring_scope(socket)

    with {:ok, candidate} <- selected_candidate(socket.assigns.decision_point_candidates, params),
         {:ok, request} <- create_request(scope, candidate, params),
         {:ok, _definition} <- ABExperiments.create_experiment(request) do
      {:noreply,
       socket
       |> assign(experiment_success: "Experiment created.")
       |> assign(experiment_error: nil)
       |> assign_authoring_experiments()}
    else
      {:error, message} when is_binary(message) ->
        {:noreply,
         assign(socket,
           experiment_error: message,
           experiment_success: nil,
           experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
           experiment_field_errors: field_errors_for_message(message)
         )}

      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply,
         assign(socket,
           experiment_error: error.message,
           experiment_success: nil,
           experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
           experiment_field_errors: field_errors_for_message(error.message)
         )}
    end
  end

  def handle_event("change_experiment_form", %{"experiment" => params}, socket) do
    {:noreply,
     assign(socket,
       experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
       experiment_field_errors: %{}
     )}
  end

  def handle_event("start_experiment", %{"id" => experiment_id}, socket) do
    transition_experiment(socket, experiment_id, :start)
  end

  def handle_event("pause_experiment", %{"id" => experiment_id}, socket) do
    transition_experiment(socket, experiment_id, :pause)
  end

  def handle_event("complete_experiment", %{"id" => experiment_id}, socket) do
    transition_experiment(socket, experiment_id, :complete)
  end

  def handle_event("archive_experiment", %{"id" => experiment_id}, socket) do
    transition_experiment(socket, experiment_id, :archive)
  end

  def handle_event("show_create_option_modal", %{"resource_id" => resource_id}, socket) do
    changeset =
      {%{id: uuid(), resource_id: resource_id}, %{id: :string, resource_id: :int, name: :string}}
      |> Ecto.Changeset.cast(%{}, [:id, :resource_id, :name])

    form_body_fn = fn assigns ->
      ~H"""
      <div class="form-group">
        {hidden_input(@form, :id)}
        {hidden_input(@form, :resource_id)}

        {text_input(
          @form,
          :name,
          class: "form-control my-2" <> error_class(@form, :name, "is-invalid"),
          placeholder: "Enter a name",
          phx_hook: "InputAutoSelect",
          required: true
        )}
      </div>
      """
    end

    modal_assigns = %{
      id: "create_modal",
      title: "Create Option",
      submit_label: "Create",
      changeset: changeset,
      form_body_fn: form_body_fn,
      on_validate: "validate_option",
      on_submit: "create_option"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "create_option",
        %{"params" => %{"id" => option_id, "name" => name, "resource_id" => resource_id}},
        socket
      ) do
    %{project: project, ctx: ctx, experiment: experiment} = socket.assigns
    %{content: %{"options" => options} = content} = experiment
    new_options = [%{"id" => option_id, "name" => name} | options]

    case edit_group_options(
           project.slug,
           ctx.author,
           [socket.assigns.experiment],
           ensure_integer(resource_id),
           content,
           new_options
         ) do
      {:ok, [experiment], _group} ->
        {:noreply, hide_modal(socket) |> assign(experiment: experiment)}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_edit_group_modal",
        %{"resource-id" => _resource_id},
        socket
      ) do
    changeset = Oli.Resources.Revision.changeset(socket.assigns.experiment)

    form_body_fn = fn assigns ->
      ~H"""
      <div class="form-group">
        {hidden_input(@form, :id)}
        {hidden_input(@form, :resource_id)}

        {text_input(
          @form,
          :title,
          class: "form-control my-2" <> error_class(@form, :name, "is-invalid"),
          placeholder: "Enter a title",
          phx_hook: "InputAutoSelect",
          required: true
        )}
      </div>
      """
    end

    modal_assigns = %{
      id: "edit_modal",
      title: "Edit",
      submit_label: "Save",
      changeset: changeset,
      form_body_fn: form_body_fn,
      on_validate: "validate_group",
      on_submit: "edit_group"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "delete_option",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    %{project: project, ctx: ctx, experiment: experiment} = socket.assigns
    %{content: %{"options" => options} = content} = experiment

    new_options = Enum.filter(options, fn o -> o["id"] != option_id end)

    case edit_group_options(
           project.slug,
           ctx.author,
           [experiment],
           ensure_integer(resource_id),
           content,
           new_options
         ) do
      {:ok, [experiment], _group} ->
        {:noreply, hide_modal(socket) |> assign(experiment: experiment)}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_delete_option_modal",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    experiment = socket.assigns.experiment
    option = Enum.find(experiment.content["options"], fn o -> o["id"] === option_id end)

    preview_fn = fn assigns ->
      ~H"""
      <ul class="list-group">
        <.group_option group={@group} option={@option} show_actions={false} />
      </ul>
      """
    end

    modal_assigns = %{
      id: "delete_modal",
      title: "Delete Option",
      message: "Are you sure you want to delete this option?",
      preview_fn: preview_fn,
      group: experiment,
      option: option,
      on_delete: "delete_option",
      phx_values: [
        "phx-value-resource-id": ensure_integer(resource_id),
        "phx-value-option-id": option_id
      ]
    }

    modal = fn assigns ->
      ~H"""
      <DeleteModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "edit_group",
        %{"params" => %{"resource_id" => resource_id, "title" => title}},
        socket
      ) do
    %{project: project, ctx: ctx, experiment: experiment} = socket.assigns

    case edit_group_title(
           project.slug,
           ctx.author,
           [experiment],
           ensure_integer(resource_id),
           title
         ) do
      {:ok, [experiment], _group} ->
        {:noreply, hide_modal(socket) |> assign(experiment: experiment)}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event("validate_group", %{"params" => %{"title" => _}}, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "show_edit_option_modal",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    experiment = socket.assigns.experiment

    option = Enum.find(experiment.content["options"], fn o -> o["id"] === option_id end)

    changeset =
      {%{resource_id: resource_id}, %{id: :string, resource_id: :int, name: :string}}
      |> Ecto.Changeset.cast(option, [:id, :resource_id, :name])

    form_body_fn = fn assigns ->
      ~H"""
      <div class="form-group">
        {hidden_input(@form, :id)}
        {hidden_input(@form, :resource_id)}

        {text_input(
          @form,
          :name,
          class: "form-control my-2" <> error_class(@form, :name, "is-invalid"),
          placeholder: "Enter a name",
          phx_hook: "InputAutoSelect",
          required: true
        )}
      </div>
      """
    end

    modal_assigns = %{
      id: "edit_modal",
      title: "Edit Option",
      submit_label: "Save",
      changeset: changeset,
      form_body_fn: form_body_fn,
      on_validate: "validate_option",
      on_submit: "edit_option"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("validate_option", %{"params" => %{"name" => _}}, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "edit_option",
        %{"params" => %{"resource_id" => resource_id, "id" => option_id, "name" => name}},
        socket
      ) do
    resource_id = ensure_integer(resource_id)

    %{content: %{"options" => options} = content} = socket.assigns.experiment

    updated_options =
      Enum.map(options, fn o ->
        if o["id"] == option_id do
          %{o | "name" => name}
        else
          o
        end
      end)

    %{project: project, ctx: ctx} = socket.assigns

    case edit_group_options(
           project.slug,
           ctx.author,
           [socket.assigns.experiment],
           resource_id,
           content,
           updated_options
         ) do
      {:ok, [experiment], _group} ->
        {:noreply, hide_modal(socket) |> assign(experiment: experiment)}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  defp assign_authoring_experiments(socket) do
    scope = authoring_scope(socket)

    {experiments, candidates, error} =
      if is_nil(scope.institution_id) do
        {[], [], nil}
      else
        experiments =
          case ABExperiments.list_project_experiments(scope) do
            {:ok, experiments} -> experiments
            {:error, error} -> {:error, error}
          end

        candidates =
          case ABExperiments.list_available_decision_points(scope) do
            {:ok, candidates} -> candidates
            {:error, _error} -> []
          end

        case experiments do
          {:error, error} -> {[], candidates, error.message}
          experiments -> {experiments, candidates, nil}
        end
      end

    assign(socket,
      ab_experiments: experiments,
      decision_point_candidates: candidates,
      experiment_error: error,
      experiment_success: nil,
      experiment_algorithm: "weighted_random",
      experiment_field_errors: %{},
      experiment_form: to_form(%{}, as: :experiment)
    )
  end

  defp transition_experiment(socket, experiment_id, action) do
    experiment_id = ensure_integer(experiment_id)
    request = %LifecycleRequest{scope: authoring_scope(socket)}

    result =
      case action do
        :start -> ABExperiments.activate_experiment(experiment_id, request)
        :pause -> ABExperiments.pause_experiment(experiment_id, request)
        :complete -> ABExperiments.complete_experiment(experiment_id, request)
        :archive -> ABExperiments.archive_experiment(experiment_id, request)
      end

    case result do
      {:ok, _definition} ->
        {:noreply,
         socket
         |> assign(experiment_success: "Experiment updated.")
         |> assign(experiment_error: nil)
         |> assign_authoring_experiments()}

      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply, assign(socket, experiment_error: error.message, experiment_success: nil)}
    end
  end

  defp authoring_scope(socket) do
    %Scope{
      institution_id: institution_id(socket),
      project_id: socket.assigns.project.id
    }
  end

  defp institution_id(socket) do
    cond do
      section = socket.assigns[:section] ->
        section.institution_id

      institutions = Institutions.list_institutions() ->
        institutions |> List.first() |> then(&(&1 && &1.id))
    end
  end

  defp selected_candidate(candidates, %{"decision_point" => revision_id}) do
    revision_id = ensure_integer(revision_id)

    case Enum.find(candidates, &(&1.alternatives_revision_id == revision_id)) do
      nil -> {:error, "Select an alternatives group."}
      candidate -> {:ok, candidate}
    end
  end

  defp selected_candidate(_candidates, _params), do: {:error, "Select an alternatives group."}

  defp create_request(scope, candidate, params) do
    with {:ok, algorithm} <- parse_algorithm(params["algorithm"]),
         {:ok, weight_a} <- parse_weight(params["weight_a"]),
         {:ok, weight_b} <- parse_weight(params["weight_b"]),
         {:ok, policy_config} <- policy_config(algorithm, params),
         [option_a, option_b | _rest] <- candidate.options do
      {:ok,
       %CreateExperimentRequest{
         scope: scope,
         slug: params["slug"],
         name: params["name"],
         algorithm: algorithm,
         policy_config: policy_config,
         decision_point: %{
           alternatives_resource_id: candidate.alternatives_resource_id,
           alternatives_revision_id: candidate.alternatives_revision_id,
           decision_point_key: candidate.decision_point_key,
           title: candidate.title
         },
         conditions: [
           %{
             condition_code: option_a,
             option_id: option_a,
             label: option_a,
             weight: weight_a,
             active: true,
             position: 0
           },
           %{
             condition_code: option_b,
             option_id: option_b,
             label: option_b,
             weight: weight_b,
             active: true,
             position: 1
           }
         ]
       }}
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "The selected alternatives group needs at least two options."}
    end
  end

  defp parse_algorithm("thompson_sampling"), do: {:ok, :thompson_sampling}
  defp parse_algorithm("weighted_random"), do: {:ok, :weighted_random}
  defp parse_algorithm(nil), do: {:ok, :weighted_random}
  defp parse_algorithm(_algorithm), do: {:error, "Select a supported assignment policy."}

  defp policy_config(:weighted_random, _params), do: {:ok, %{}}

  defp policy_config(:thompson_sampling, params) do
    with {:ok, prior_alpha} <- parse_positive_number(params["prior_alpha"], "Prior alpha"),
         {:ok, prior_beta} <- parse_positive_number(params["prior_beta"], "Prior beta"),
         {:ok, warm_up_assignments} <- parse_non_negative_integer(params["warm_up_assignments"]),
         {:ok, max_condition_share} <-
           parse_share(params["max_condition_share"], "Max condition share") do
      {:ok,
       %{
         "reward_source" => "activity_attempt:full_credit",
         "priors" => %{
           "default" => %{"alpha" => prior_alpha, "beta" => prior_beta},
           "conditions" => %{}
         },
         "guardrails" => %{
           "manual_pause_enabled" => true,
           "warm_up_assignments" => warm_up_assignments,
           "max_condition_share" => max_condition_share,
           "fixed_control_allocation" => nil,
           "imbalance_threshold" => 1.0
         }
       }}
    end
  end

  defp parse_weight(value) when is_binary(value) do
    case parse_exact_float(value) do
      {:ok, weight} when weight >= 0.0 -> {:ok, weight}
      _ -> {:error, "Weights must be non-negative numbers."}
    end
  end

  defp parse_weight(_value), do: {:error, "Weights must be non-negative numbers."}

  defp parse_positive_number(value, label) when is_binary(value) do
    case parse_exact_float(value) do
      {:ok, number} when number >= 0.0001 and number <= 1000.0 -> {:ok, number}
      _ -> {:error, "#{label} must be between 0.0001 and 1000."}
    end
  end

  defp parse_positive_number(_value, label),
    do: {:error, "#{label} must be between 0.0001 and 1000."}

  defp parse_non_negative_integer(value) when is_binary(value) do
    case parse_exact_integer(value) do
      {:ok, number} when number >= 0 -> {:ok, number}
      _ -> {:error, "Warm-up assignments must be a non-negative integer."}
    end
  end

  defp parse_non_negative_integer(_value),
    do: {:error, "Warm-up assignments must be a non-negative integer."}

  defp parse_share(value, label) when is_binary(value) do
    case parse_exact_float(value) do
      {:ok, number} when number > 0.0 and number <= 1.0 -> {:ok, number}
      _ -> {:error, "#{label} must be greater than 0 and at most 1."}
    end
  end

  defp parse_share(_value, label), do: {:error, "#{label} must be greater than 0 and at most 1."}

  defp parse_exact_float(value) do
    value = String.trim(value)

    case Float.parse(value) do
      {number, ""} -> {:ok, number}
      {_number, rest} when is_binary(rest) -> :error
      :error -> :error
    end
  end

  defp parse_exact_integer(value) do
    value = String.trim(value)

    case Integer.parse(value) do
      {number, ""} -> {:ok, number}
      {_number, rest} when is_binary(rest) -> :error
      :error -> :error
    end
  end

  defp field_errors_for_message("Prior alpha" <> _ = message), do: %{prior_alpha: message}
  defp field_errors_for_message("Prior beta" <> _ = message), do: %{prior_beta: message}

  defp field_errors_for_message("Warm-up assignments" <> _ = message),
    do: %{warm_up_assignments: message}

  defp field_errors_for_message("Max condition share" <> _ = message),
    do: %{max_condition_share: message}

  defp field_errors_for_message(_message), do: %{}

  defp field_error(errors, field), do: Map.get(errors, field)
  defp field_invalid?(errors, field), do: Map.has_key?(errors, field)

  defp field_error_class(errors, field),
    do: if(field_invalid?(errors, field), do: "is-invalid", else: "")

  defp format_state(state) do
    state
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_algorithm(:weighted_random), do: "Weighted random"
  defp format_algorithm(:thompson_sampling), do: "Thompson Sampling"

  defp edit_group_title(
         project_slug,
         author,
         alternatives,
         resource_id,
         title
       ) do
    case ResourceEditor.edit(project_slug, resource_id, author, %{
           title: title
         }) do
      {:ok, updated_group} ->
        # update groups list to reflect latest update
        alternatives =
          Enum.map(alternatives, fn g ->
            if g.resource_id == updated_group.resource_id do
              updated_group
            else
              g
            end
          end)

        {:ok, alternatives, updated_group}

      error ->
        error
    end
  end

  defp edit_group_options(
         project_slug,
         author,
         alternatives,
         resource_id,
         content,
         updated_options
       ) do
    with :ok <- check_duplicated_options(updated_options),
         {:ok, updated_group} <-
           ResourceEditor.edit(project_slug, resource_id, author, %{
             content: %{content | "options" => updated_options}
           }) do
      # update groups list to reflect latest update
      alternatives =
        Enum.map(alternatives, fn g ->
          if g.resource_id == updated_group.resource_id do
            updated_group
          else
            g
          end
        end)

      {:ok, alternatives, updated_group}
    end
  end

  defp check_duplicated_options(options) do
    option_names = Enum.map(options, & &1["name"])

    case option_names -- Enum.uniq(option_names) do
      [] ->
        :ok

      dups ->
        {:error,
         message:
           "The option could not be created because duplicate options have been found (#{Enum.join(dups, ", ")}). Please choose a unique name and try again."}
    end
  end

  defp ensure_integer(i) when is_integer(i), do: i

  defp ensure_integer(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _rem} -> i
      _ -> throw("Invalid integer")
    end
  end

  defp show_error(socket, message \\ @default_error_message) do
    {:noreply, socket |> hide_modal() |> put_flash(:error, message)}
  end
end
