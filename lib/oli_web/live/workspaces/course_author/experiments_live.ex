defmodule OliWeb.Workspaces.CourseAuthor.ExperimentsLive do
  use OliWeb, :live_view
  use Phoenix.HTML
  use OliWeb.Common.Modal

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.ErrorHelpers
  import OliWeb.Resources.AlternativesEditor.GroupOption

  alias Oli.Authoring.Experiments, as: LegacyExperiments
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Experiments, as: ABExperiments
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Utils.Slug
  alias OliWeb.Common.Modal.{DeleteModal, FormModal}

  @default_error_message "Something went wrong. Please refresh the page and try again."

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project
    experiment = LegacyExperiments.get_latest_experiment(project.slug)
    scope = authoring_scope(socket)

    socket =
      socket
      |> assign_authoring_experiments()
      |> start_async(:load_eligible_sections, fn ->
        ABExperiments.list_eligible_sections(scope)
      end)

    {:ok,
     assign(socket,
       experiment: experiment,
       resource_slug: project.slug,
       resource_title: project.title
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :visible_ab_experiments,
        visible_experiments(assigns.ab_experiments, assigns.show_archived_experiments)
      )

    ~H"""
    <h2 id="header_id" class="pb-2">Experiments</h2>
    {render_modal(assigns)}

    <p>Create and manage A/B experiments in this project.</p>
    <section class="mt-4">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <div class="form-check">
          <input
            id="show-archived-experiments"
            type="checkbox"
            class="form-check-input"
            checked={@show_archived_experiments}
            phx-click="toggle_archived_experiments"
          />
          <label class="form-check-label" for="show-archived-experiments">
            Show archived experiments
          </label>
        </div>
        <button
          type="button"
          class="btn btn-primary"
          phx-click="open_create_experiment"
          disabled={Enum.empty?(@decision_point_candidates)}
        >
          Create Experiment
        </button>
      </div>

      <div :if={Enum.empty?(@decision_point_candidates)} class="alert alert-info">
        Create an A/B decision point before adding an A/B Testing experiment.
      </div>

      <%= if @experiment_error do %>
        <div class="alert alert-danger" role="alert">{@experiment_error}</div>
      <% end %>

      <%= if @experiment_success do %>
        <div class="alert alert-success" role="status">{@experiment_success}</div>
      <% end %>

      <%= if Enum.empty?(@visible_ab_experiments) do %>
        <div>
          <%= if Enum.empty?(@ab_experiments) do %>
            No A/B Testing experiments have been created yet.
          <% else %>
            No non-archived experiments to display.
          <% end %>
        </div>
      <% else %>
        <table class="table table-sm" id="ab-experiments-table">
          <caption class="sr-only">A/B Testing experiments</caption>
          <thead>
            <tr>
              <th scope="col">Name</th>
              <th scope="col">Slug</th>
              <th scope="col">Algorithm</th>
              <th scope="col">Status</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={experiment <- @visible_ab_experiments}
              id={"ab-experiment-#{experiment.id}"}
            >
              <td>
                <.link navigate={
                  ~p"/workspaces/course_author/#{@project.slug}/experiments/#{experiment.id}"
                }>
                  {experiment.name}
                </.link>
              </td>
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
                  phx-click="request_experiment_transition"
                  phx-value-action="complete"
                  phx-value-id={experiment.id}
                >
                  Complete
                </button>
                <button
                  :if={experiment.state == :completed}
                  type="button"
                  class="btn btn-sm btn-outline-danger"
                  phx-click="request_experiment_transition"
                  phx-value-action="archive"
                  phx-value-id={experiment.id}
                >
                  Archive
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      <% end %>

      <section class="mt-5" aria-labelledby="decision-points-heading">
        <h3 id="decision-points-heading" class="h4">Decision Points</h3>
        <ul :if={not Enum.empty?(@decision_point_candidates)} class="list-group mb-3">
          <li :for={candidate <- @decision_point_candidates} class="list-group-item">
            {candidate.title}
          </li>
        </ul>
        <%= if @experiment do %>
          <OliWeb.Resources.AlternativesEditor.group
            group={@experiment}
            editing_enabled={false}
            source={:experiments}
          />
        <% else %>
          <div :if={Enum.empty?(@decision_point_candidates)}>
            No decision points have been created yet.
          </div>
        <% end %>
      </section>

      <OliWeb.Components.Modal.modal
        :if={@section_participation}
        id="experiment-section-participation"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-2xl p-4"
        on_cancel={Phoenix.LiveView.JS.push("close_section_participation")}
      >
        <:title>Participating sections</:title>
        <:subtitle>
          Select sections to participate in this experiment.
        </:subtitle>
        <.form
          for={to_form(%{}, as: :participation)}
          id="section-participation-form"
          phx-submit="save_section_participation"
        >
          <input
            type="hidden"
            name="participation[experiment_id]"
            value={@section_participation.experiment_id}
          />
          <fieldset disabled={@section_participation_read_only}>
            <legend class="sr-only">Select participating sections</legend>
            <div :if={Enum.empty?(@section_participation.eligible_sections)} role="status">
              No active eligible sections are available.
            </div>
            <div :for={section <- @section_participation.eligible_sections} class="form-check">
              <input
                class="form-check-input"
                type="checkbox"
                id={"participation-section-#{section.id}"}
                name="participation[section_ids][]"
                value={section.id}
                checked={section.id in @section_participation.selected_ids}
              />
              <label class="form-check-label" for={"participation-section-#{section.id}"}>
                {section.title} ({section.slug})
              </label>
            </div>
          </fieldset>
          <div
            :if={not Enum.empty?(@section_participation.stale_sections)}
            class="alert alert-warning"
          >
            <h6>Previously selected sections no longer participating</h6>
            <ul>
              <li :for={section <- @section_participation.stale_sections}>
                {section.title} ({section.slug})
              </li>
            </ul>
            <p>Saving removes these stale selections.</p>
          </div>
          <button :if={not @section_participation_read_only} type="submit" class="btn btn-primary">
            Save participating sections
          </button>
          <button
            type="button"
            class="btn btn-link"
            phx-click="close_section_participation"
          >
            Cancel
          </button>
        </.form>
      </OliWeb.Components.Modal.modal>

      <OliWeb.Components.Modal.modal
        :if={@pending_experiment_transition}
        id="confirm-experiment-transition-modal"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-lg p-4"
        on_cancel={Phoenix.LiveView.JS.push("cancel_experiment_transition")}
      >
        <:title>{transition_title(@pending_experiment_transition.action)}</:title>
        <p>{transition_confirmation(@pending_experiment_transition)}</p>
        <:custom_footer>
          <div class="d-flex justify-content-end gap-2 p-4 pt-0">
            <button type="button" class="btn btn-link" phx-click="cancel_experiment_transition">
              Cancel
            </button>
            <button
              type="button"
              class={[
                "btn",
                if(@pending_experiment_transition.action == :archive,
                  do: "btn-danger",
                  else: "btn-primary"
                )
              ]}
              phx-click="confirm_experiment_transition"
            >
              {transition_button_label(@pending_experiment_transition.action)}
            </button>
          </div>
        </:custom_footer>
      </OliWeb.Components.Modal.modal>

      <OliWeb.Components.Modal.modal
        :if={@show_create_experiment}
        id="create-experiment-modal"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-3xl p-4"
        on_cancel={Phoenix.LiveView.JS.push("close_create_experiment")}
      >
        <:title>Create Experiment</:title>
        <%= unless Enum.empty?(@decision_point_candidates) do %>
          <.form
            for={@experiment_form}
            id="create-ab-experiment-form"
            phx-change="change_experiment_form"
            phx-submit="create_experiment"
          >
            <div class="form-group">
              <label for="experiment_algorithm">Assignment Policy</label>
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
              <label for="experiment_name">Name</label>
              <input
                id="experiment_name"
                class="form-control"
                name="experiment[name]"
                value={@experiment_params["name"]}
                phx-debounce="300"
                required
              />
            </div>
            <div class="form-group">
              <label for="experiment_slug">Slug</label>
              <input
                id="experiment_slug"
                class="form-control"
                name="experiment[slug]"
                value={@experiment_params["slug"]}
                required
              />
              <div :if={@experiment_slug_suggestion} class="form-text">
                Suggested slug:
                <a
                  href="#"
                  id="use-suggested-experiment-slug"
                  phx-click="use_suggested_experiment_slug"
                >
                  {@experiment_slug_suggestion}
                </a>
              </div>
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
                  value={candidate.alternatives_resource_id}
                >
                  {candidate.title}
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
              <h6 id="thompson-sampling-options" class="font-weight-bold">
                Thompson Sampling Options
              </h6>
              <div class="form-group">
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
              <div class="form-group">
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
              <div class="form-group">
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
              <div class="form-group">
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
            <% end %>
            <div class="d-flex justify-content-end gap-2">
              <button type="button" class="btn btn-link" phx-click="close_create_experiment">
                Cancel
              </button>
              <button type="submit" class="btn btn-primary">Create</button>
            </div>
          </.form>
        <% end %>
      </OliWeb.Components.Modal.modal>
    </section>
    """
  end

  def handle_event("open_create_experiment", _params, socket) do
    {:noreply,
     assign(socket,
       show_create_experiment: true,
       experiment_error: nil,
       experiment_success: nil,
       experiment_params: %{},
       experiment_slug_suggestion: nil
     )}
  end

  def handle_event("close_create_experiment", _params, socket) do
    {:noreply,
     assign(socket,
       show_create_experiment: false,
       experiment_error: nil,
       experiment_field_errors: %{},
       experiment_params: %{},
       experiment_slug_suggestion: nil
     )}
  end

  def handle_event("toggle_archived_experiments", _params, socket) do
    {:noreply,
     assign(socket, show_archived_experiments: not socket.assigns.show_archived_experiments)}
  end

  def handle_event(
        "request_experiment_transition",
        %{"id" => experiment_id, "action" => action},
        socket
      ) do
    with {:ok, experiment_id} <- parse_positive_integer(experiment_id),
         {:ok, action} <- parse_confirmation_action(action),
         experiment when not is_nil(experiment) <-
           Enum.find(socket.assigns.ab_experiments, &(&1.id == experiment_id)),
         true <- transition_available?(experiment.state, action) do
      {:noreply,
       assign(socket,
         pending_experiment_transition: %{
           experiment_id: experiment.id,
           experiment_name: experiment.name,
           action: action
         },
         experiment_error: nil
       )}
    else
      _ ->
        {:noreply, assign(socket, experiment_error: "The requested action is not available.")}
    end
  end

  def handle_event("cancel_experiment_transition", _params, socket) do
    {:noreply, assign(socket, pending_experiment_transition: nil)}
  end

  def handle_event("confirm_experiment_transition", _params, socket) do
    case socket.assigns.pending_experiment_transition do
      %{experiment_id: experiment_id, action: action} ->
        socket
        |> assign(pending_experiment_transition: nil)
        |> transition_experiment(experiment_id, action)

      nil ->
        {:noreply, assign(socket, experiment_error: "No experiment action is pending.")}
    end
  end

  def handle_event("create_experiment", %{"experiment" => params}, socket) do
    scope = authoring_scope(socket)

    with {:ok, candidate} <- selected_candidate(socket.assigns.decision_point_candidates, params),
         {:ok, request} <- create_request(scope, candidate, params),
         {:ok, _definition} <- ABExperiments.create_experiment(request) do
      {:noreply,
       socket
       |> assign(show_create_experiment: false)
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
           experiment_field_errors: field_errors_for_message(message),
           experiment_params: params,
           experiment_slug_suggestion: suggested_experiment_slug(params["name"])
         )}

      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply,
         assign(socket,
           experiment_error: error.message,
           experiment_success: nil,
           experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
           experiment_field_errors: field_errors_for_message(error.message),
           experiment_params: params,
           experiment_slug_suggestion: suggested_experiment_slug(params["name"])
         )}
    end
  end

  def handle_event("change_experiment_form", %{"experiment" => params}, socket) do
    slug_suggestion =
      case params["name"] == socket.assigns.experiment_params["name"] do
        true -> socket.assigns.experiment_slug_suggestion
        false -> suggested_experiment_slug(params["name"])
      end

    {:noreply,
     assign(socket,
       experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
       experiment_field_errors: %{},
       experiment_params: params,
       experiment_slug_suggestion: slug_suggestion
     )}
  end

  def handle_event("use_suggested_experiment_slug", _params, socket) do
    case socket.assigns.experiment_slug_suggestion do
      nil ->
        {:noreply, socket}

      suggestion ->
        {:noreply,
         assign(socket,
           experiment_params: Map.put(socket.assigns.experiment_params, "slug", suggestion)
         )}
    end
  end

  def handle_event("configure_sections", %{"id" => experiment_id}, socket) do
    with {:ok, experiment_id} <- parse_positive_integer(experiment_id),
         {:ok, participation} <-
           ABExperiments.get_section_participation(experiment_id, authoring_scope(socket)),
         experiment when not is_nil(experiment) <-
           Enum.find(socket.assigns.ab_experiments, &(&1.id == experiment_id)) do
      {:noreply,
       assign(socket,
         section_participation: participation,
         section_participation_read_only: experiment.state in [:completed, :archived],
         experiment_error: nil
       )}
    else
      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply, assign(socket, experiment_error: error.message)}

      _ ->
        {:noreply, assign(socket, experiment_error: "Invalid experiment selection.")}
    end
  end

  def handle_event("save_section_participation", %{"participation" => params}, socket) do
    with {:ok, experiment_id} <- parse_positive_integer(params["experiment_id"]),
         {:ok, section_ids} <- parse_section_ids(params["section_ids"]),
         {:ok, _participation} <-
           ABExperiments.update_section_participation(
             experiment_id,
             authoring_scope(socket),
             section_ids
           ) do
      {:noreply,
       assign(socket,
         section_participation: nil,
         experiment_success: "Participating sections updated.",
         experiment_error: nil
       )}
    else
      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply, assign(socket, experiment_error: error.message, experiment_success: nil)}

      {:error, message} ->
        {:noreply, assign(socket, experiment_error: message, experiment_success: nil)}
    end
  end

  def handle_event("close_section_participation", _params, socket) do
    {:noreply, assign(socket, section_participation: nil)}
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

  @impl Phoenix.LiveView
  def handle_async(:load_eligible_sections, {:ok, {:ok, sections}}, socket) do
    {:noreply, assign(socket, eligible_sections: sections, eligible_sections_status: :loaded)}
  end

  def handle_async(:load_eligible_sections, _result, socket) do
    {:noreply, assign(socket, eligible_sections: [], eligible_sections_status: :error)}
  end

  defp assign_authoring_experiments(socket) do
    scope = authoring_scope(socket)

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

    {experiments, candidates, error} =
      case experiments do
        {:error, error} -> {[], candidates, error.message}
        experiments -> {experiments, candidates, nil}
      end

    assign(socket,
      ab_experiments: experiments,
      decision_point_candidates: candidates,
      experiment_error: error,
      experiment_success: nil,
      experiment_algorithm: "weighted_random",
      experiment_field_errors: %{},
      experiment_form: to_form(%{}, as: :experiment),
      show_create_experiment: Map.get(socket.assigns, :show_create_experiment, false),
      experiment_params: Map.get(socket.assigns, :experiment_params, %{}),
      experiment_slug_suggestion: Map.get(socket.assigns, :experiment_slug_suggestion),
      show_archived_experiments: Map.get(socket.assigns, :show_archived_experiments, false),
      pending_experiment_transition: Map.get(socket.assigns, :pending_experiment_transition),
      eligible_sections: Map.get(socket.assigns, :eligible_sections, []),
      eligible_sections_status: Map.get(socket.assigns, :eligible_sections_status, :loading),
      section_participation: nil,
      section_participation_read_only: false
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
      author_id: socket.assigns.ctx.author.id,
      project_id: socket.assigns.project.id
    }
  end

  defp selected_candidate(candidates, %{"decision_point" => resource_id}) do
    resource_id = ensure_integer(resource_id)

    case Enum.find(candidates, &(&1.alternatives_resource_id == resource_id)) do
      nil -> {:error, "Select an alternatives group."}
      candidate -> {:ok, candidate}
    end
  end

  defp selected_candidate(_candidates, _params), do: {:error, "Select an alternatives group."}

  defp create_request(scope, candidate, params) do
    with {:ok, algorithm} <- parse_algorithm(params["algorithm"]),
         {:ok, weight_a} <- parse_weight(params["weight_a"]),
         {:ok, weight_b} <- parse_weight(params["weight_b"]),
         {:ok, section_ids} <- parse_section_ids(params["section_ids"]),
         {:ok, policy_config} <- policy_config(algorithm, params),
         [option_a, option_b | _rest] <- candidate.options do
      {:ok,
       %CreateExperimentRequest{
         scope: scope,
         slug: params["slug"],
         name: params["name"],
         algorithm: algorithm,
         section_ids: section_ids,
         policy_config: policy_config,
         decision_point: %{
           alternatives_resource_id: candidate.alternatives_resource_id,
           decision_point_key: candidate.decision_point_key,
           title: candidate.title
         },
         conditions: [
           %{
             condition_code: option_a,
             option_id: option_a,
             label: Map.get(candidate.option_labels, option_a, option_a),
             weight: weight_a,
             active: true,
             position: 0
           },
           %{
             condition_code: option_b,
             option_id: option_b,
             label: Map.get(candidate.option_labels, option_b, option_b),
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

  defp parse_section_ids(nil), do: {:ok, []}

  defp parse_section_ids(section_ids) when is_list(section_ids) do
    Enum.reduce_while(section_ids, {:ok, []}, fn section_id, {:ok, ids} ->
      case parse_positive_integer(section_id) do
        {:ok, id} -> {:cont, {:ok, [id | ids]}}
        {:error, _message} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, ids |> Enum.uniq() |> Enum.sort()}
      error -> error
    end
  end

  defp parse_section_ids(section_id) do
    with {:ok, id} <- parse_positive_integer(section_id), do: {:ok, [id]}
  end

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, "Invalid section or experiment selection."}
    end
  end

  defp parse_positive_integer(_value), do: {:error, "Invalid section or experiment selection."}

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

  defp parse_confirmation_action("complete"), do: {:ok, :complete}
  defp parse_confirmation_action("archive"), do: {:ok, :archive}
  defp parse_confirmation_action(_action), do: {:error, :invalid_action}

  defp transition_available?(state, :complete), do: state in [:active, :paused]
  defp transition_available?(:completed, :archive), do: true
  defp transition_available?(_state, _action), do: false

  defp transition_title(:complete), do: "Complete Experiment"
  defp transition_title(:archive), do: "Archive Experiment"

  defp transition_button_label(:complete), do: "Complete"
  defp transition_button_label(:archive), do: "Archive"

  defp transition_confirmation(%{action: :complete, experiment_name: name}) do
    "Complete “#{name}”? Participation can no longer be changed after completion."
  end

  defp transition_confirmation(%{action: :archive, experiment_name: name}) do
    "Archive “#{name}”? The experiment will be removed from active use."
  end

  defp suggested_experiment_slug(name) when is_binary(name) do
    case String.trim(name) do
      "" -> nil
      name -> Slug.generate("experiment_definitions", name)
    end
  end

  defp suggested_experiment_slug(_name), do: nil

  defp visible_experiments(experiments, true), do: experiments

  defp visible_experiments(experiments, false),
    do: Enum.reject(experiments, &(&1.state == :archived))

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
