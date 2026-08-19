defmodule OliWeb.Workspaces.CourseAuthor.ExperimentDetailsLive do
  use OliWeb, :live_view

  alias Oli.Experiments, as: ABExperiments
  alias Oli.Experiments.{LifecycleRequest, Scope, UpdateExperimentRequest}
  alias OliWeb.Workspaces.CourseAuthor.ExperimentConfigurationForm

  @page_size 10

  @impl Phoenix.LiveView
  def mount(%{"experiment_id" => experiment_id}, _session, socket) do
    project = socket.assigns.project

    socket =
      assign(socket,
        active_view: :experiments,
        resource_slug: project.slug,
        resource_title: project.title
      )

    scope = authoring_scope(socket)

    with {:ok, experiment_id} <- parse_positive_integer(experiment_id),
         {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(
             experiment_id,
             scope
           ),
         {:ok, participation} <-
           ABExperiments.get_section_participation(experiment_id, scope),
         {:ok, policy_snapshot} <- ABExperiments.policy_snapshot(authoring_view, scope),
         {:ok, alternatives_candidates} <- alternatives_candidates(authoring_view, scope),
         {:ok, page_options} <- ABExperiments.list_available_pages(scope) do
      experiment = authoring_view.definition
      configuration = experiment_configuration(authoring_view)
      candidate = selected_alternatives_candidate(experiment, alternatives_candidates)

      {:ok,
       assign(socket,
         experiment: experiment,
         authoring_view: authoring_view,
         participation: participation,
         policy_snapshot: policy_snapshot,
         alternatives_candidates: alternatives_candidates,
         page_options: page_options,
         picker: nil,
         configuration_changeset: configuration_changeset(configuration, configuration),
         decision_point_title: candidate && candidate.title,
         condition_options: candidate_options(candidate),
         configuration_error: nil,
         configuration_field_errors: %{},
         configuration_success: nil,
         read_only: experiment.state in [:completed, :archived],
         page: 1,
         page_size: @page_size,
         participation_error: nil,
         participation_success: nil,
         experiment_action_error: nil,
         experiment_action_success: nil,
         pending_experiment_transition: nil
       )}
    else
      _error ->
        {:ok,
         socket
         |> put_flash(:error, "Experiment not found.")
         |> push_navigate(
           to: ~p"/workspaces/course_author/#{socket.assigns.project.slug}/experiments"
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    page = parse_page(params["page"])
    {:noreply, assign(socket, page: clamp_page(page, socket.assigns.participation))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns =
      assigns
      |> assign(:page_sections, page_sections(assigns.participation, assigns.page))
      |> assign(:page_count, page_count(assigns.participation))
      |> assign(:configuration, Ecto.Changeset.apply_changes(assigns.configuration_changeset))
      |> assign(
        :configuration_form,
        to_form(assigns.configuration_changeset, as: :configuration)
      )

    ~H"""
    <div id="experiment-configuration" class="dark:text-gray-100">
      <.link
        navigate={~p"/workspaces/course_author/#{@project.slug}/experiments"}
        class="text-primary"
      >
        ← Back to experiments
      </.link>

      <div class="d-flex justify-content-between align-items-center mt-3">
        <div>
          <h2 class="mb-1">{@experiment.name}</h2>
          <p class="text-muted mb-0 dark:text-gray-400">
            Configure this experiment and section participation.
          </p>
        </div>
        <div class="d-flex align-items-center gap-2">
          <button
            :if={@experiment.state in [:draft, :paused]}
            type="button"
            class="btn btn-primary"
            phx-click="start_experiment"
          >
            {if @experiment.state == :paused, do: "Resume", else: "Start"}
          </button>
          <button
            :if={@experiment.state == :active}
            type="button"
            class="btn btn-secondary"
            phx-click="pause_experiment"
          >
            Pause
          </button>
          <button
            :if={@experiment.state in [:active, :paused]}
            type="button"
            class="btn btn-primary"
            phx-click="request_experiment_transition"
            phx-value-action="complete"
          >
            Complete
          </button>
          <button
            :if={@experiment.state in [:draft, :completed]}
            type="button"
            class="btn btn-outline-danger"
            phx-click="request_experiment_transition"
            phx-value-action="archive"
          >
            Archive
          </button>
        </div>
      </div>

      <div :if={@experiment_action_error} class="alert alert-danger mt-3" role="alert">
        {@experiment_action_error}
      </div>
      <div :if={@experiment_action_success} class="alert alert-success mt-3" role="status">
        {@experiment_action_success}
      </div>

      <section
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="experiment-details-heading"
      >
        <div class="card-header bg-white px-4 py-3 dark:border-gray-700 dark:bg-neutral-800">
          <h3 id="experiment-details-heading" class="h5 mb-0 !font-semibold">
            Experiment details
          </h3>
        </div>
        <div class="card-body px-4 pt-4">
          <div
            id="experiment-details-grid"
            class="mb-6 grid grid-cols-1 gap-x-8 gap-y-6 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-5"
          >
            <.detail_item label="Slug" value={@experiment.slug} monospace />
            <.detail_item
              label="Assignment policy"
              value={format_algorithm(@experiment.algorithm)}
            />
            <.detail_item
              label="Assignment unit"
              value={display_value(@experiment.assignment_unit)}
            />
            <.detail_item
              label="Assignment scope"
              value={format_assignment_scope(@experiment.assignment_scope)}
            />
            <.detail_item
              label="Status"
              value={format_state(@experiment.state)}
              badge
              badge_class={status_badge_class(@experiment.state)}
            />
            <.detail_item label="Decision Point" value={@decision_point_title || "Not selected"} />
            <.detail_item
              :if={@experiment.description}
              label="Description"
              value={@experiment.description}
            />
          </div>
        </div>
      </section>

      <section
        id="experiment-configuration-card"
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="experiment-configuration-heading"
      >
        <div class="card-header flex flex-col gap-1 bg-white px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4 dark:border-gray-700 dark:bg-neutral-800">
          <h3 id="experiment-configuration-heading" class="h5 mb-0 !font-semibold">
            Experiment configuration
          </h3>
        </div>
        <div class="card-body px-4 pt-4">
          <div :if={@configuration_error} class="alert alert-danger" role="alert">
            {@configuration_error}
          </div>
          <div :if={@configuration_success} class="alert alert-success" role="status">
            {@configuration_success}
          </div>
          <.form
            for={@configuration_form}
            id="experiment-configuration-form"
            phx-change="change_configuration"
            phx-submit="save_configuration"
          >
            <div>
              <input
                type="hidden"
                name="configuration[algorithm]"
                value={@experiment.algorithm}
              />
              <div
                id="experiment-policy-configuration"
                class="mb-4"
              >
                <input
                  type="hidden"
                  name="configuration[alternatives_resource_id]"
                  value={@configuration.alternatives_resource_id}
                />
                <fieldset
                  :if={@configuration.algorithm == :weighted_random}
                  id="experiment-assignment-scope"
                  class="mb-6"
                  aria-describedby={
                    if configuration_field_error(
                         @configuration_field_errors,
                         :assignment_scope
                       ),
                       do: "experiment-assignment-scope-help experiment-assignment-scope-error",
                       else: "experiment-assignment-scope-help"
                  }
                  aria-invalid={
                    to_string(
                      not is_nil(
                        configuration_field_error(
                          @configuration_field_errors,
                          :assignment_scope
                        )
                      )
                    )
                  }
                >
                  <legend class="h6 mb-0 !font-medium">
                    <.technical_term
                      id="experiment-assignment-scope-help"
                      label="Condition Assignment Scope"
                      help="Choose whether each learner keeps the same condition across all interventions in a participating course section or is assigned separately at each intervention."
                    />
                  </legend>
                  <div>
                    <label class={[
                      "flex min-h-11 items-start gap-2 py-2",
                      @experiment.state != :draft &&
                        "cursor-not-allowed text-gray-500 dark:text-gray-400"
                    ]}>
                      <input
                        id="configuration_assignment_scope_section_enrollment"
                        type="radio"
                        name="configuration[assignment_scope]"
                        value="section_enrollment"
                        checked={@configuration.assignment_scope == :section_enrollment}
                        disabled={@experiment.state != :draft}
                        class="mt-1 focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
                      />
                      <span>Keep the same condition throughout the course section</span>
                    </label>
                    <label class={[
                      "flex min-h-11 items-start gap-2 py-2",
                      @experiment.state != :draft &&
                        "cursor-not-allowed text-gray-500 dark:text-gray-400"
                    ]}>
                      <input
                        id="configuration_assignment_scope_intervention"
                        type="radio"
                        name="configuration[assignment_scope]"
                        value="intervention"
                        checked={@configuration.assignment_scope == :intervention}
                        disabled={@experiment.state != :draft}
                        class="mt-1 focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
                      />
                      <span>Assign independently at each intervention</span>
                    </label>
                  </div>
                  <p
                    :if={
                      error =
                        configuration_field_error(
                          @configuration_field_errors,
                          :assignment_scope
                        )
                    }
                    id="experiment-assignment-scope-error"
                    class="mt-2 text-sm text-red-600 dark:text-red-400"
                  >
                    {error}
                  </p>
                </fieldset>
                <input
                  :if={@configuration.algorithm == :thompson_sampling}
                  type="hidden"
                  name="configuration[assignment_scope]"
                  value="intervention"
                />
                <div :if={@configuration.algorithm == :weighted_random}>
                  <input
                    :for={
                      {key, value} <- [
                        {"prior_alpha", @configuration.prior_alpha},
                        {"prior_beta", @configuration.prior_beta},
                        {"warm_up_assignments", @configuration.warm_up_assignments},
                        {"max_condition_share", @configuration.max_condition_share},
                        {"fixed_control_allocation", @configuration.fixed_control_allocation},
                        {"imbalance_threshold", @configuration.imbalance_threshold}
                      ]
                    }
                    type="hidden"
                    name={"configuration[#{key}]"}
                    value={value}
                  />
                </div>
                <h4 class="h6 mb-0 !font-medium">Conditions</h4>
                <div class="mt-3 space-y-3">
                  <div
                    :for={{condition, condition_index} <- Enum.with_index(@configuration.conditions)}
                    id={"condition-row-#{condition_index}"}
                    class="grid grid-cols-1 gap-3 rounded border p-3 md:grid-cols-2 xl:grid-cols-5 dark:border-gray-700"
                  >
                    <input
                      type="hidden"
                      name={"configuration[conditions][#{condition_index}][id]"}
                      value={condition.id}
                    />
                    <div>
                      <label for={"condition-#{condition_index}-label"}>Condition label</label>
                      <input
                        id={"condition-#{condition_index}-label"}
                        class="form-control"
                        name={"configuration[conditions][#{condition_index}][label]"}
                        value={condition.label}
                        disabled={@experiment.state != :draft}
                        required
                      />
                    </div>
                    <div>
                      <label for={"condition-#{condition_index}-code"}>Stable code</label>
                      <input
                        id={"condition-#{condition_index}-code"}
                        class="form-control disabled:cursor-not-allowed disabled:opacity-60"
                        value={condition.condition_code}
                        disabled
                      />
                    </div>
                    <div>
                      <label for={"condition-#{condition_index}-option"}>Alternative</label>
                      <select
                        id={"condition-#{condition_index}-option"}
                        class="form-control"
                        name={"configuration[conditions][#{condition_index}][option_id]"}
                        disabled={@experiment.state != :draft}
                      >
                        <option
                          :for={{label, option_id} <- @condition_options}
                          value={option_id}
                          selected={condition.option_id == option_id}
                        >
                          {label}
                        </option>
                      </select>
                    </div>
                    <div>
                      <label for={"condition-#{condition_index}-active"}>Availability</label>
                      <select
                        id={"condition-#{condition_index}-active"}
                        class="form-control"
                        name={"configuration[conditions][#{condition_index}][active]"}
                        disabled={@experiment.state in [:completed, :archived]}
                        phx-change="change_condition_availability"
                      >
                        <option value="true" selected={condition.active}>Active</option>
                        <option value="false" selected={not condition.active}>Inactive</option>
                      </select>
                    </div>
                    <div>
                      <label for={"condition-#{condition_index}-weight"}>
                        <.technical_term
                          id={"condition-#{condition_index}-weight-help"}
                          label={condition_weight_label(@experiment.algorithm)}
                          help="Weights are relative and do not need to sum to 1. For example, 1 / 1 is an even split and 2 / 1 is approximately a 2:1 split."
                          element="span"
                        />
                      </label>
                      <input
                        id={"condition-#{condition_index}-weight"}
                        type="number"
                        min="0.0001"
                        step="any"
                        class="form-control disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
                        name={"configuration[conditions][#{condition_index}][weight]"}
                        value={condition.weight}
                        disabled={not condition_weight_editable?(@experiment)}
                        required
                      />
                    </div>
                  </div>
                </div>
                <div :if={@configuration.algorithm == :thompson_sampling} class="mt-3">
                  <h5 class="h6 mb-3 mt-4 !font-medium">
                    Assignment policy and guardrails
                  </h5>
                  <p class="mb-3 text-sm text-gray-500 dark:text-gray-400">
                    These settings apply to every intervention in this experiment.
                  </p>
                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
                    <div>
                      <label for="experiment-reward-source">Reward source</label>
                      <input
                        id="experiment-reward-source"
                        class="form-control disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
                        value="Assessment page normalized score"
                        disabled
                      />
                    </div>
                    <.number_field
                      key="prior_alpha"
                      label="Prior alpha"
                      help="Alpha represents prior and observed successful outcomes. Higher values increase the estimated success probability."
                      value={@configuration.prior_alpha}
                      min="0.0001"
                      max="1000"
                      disabled={@experiment.state != :draft}
                    />
                    <.number_field
                      key="prior_beta"
                      label="Prior beta"
                      help="Beta represents prior and observed unsuccessful outcomes. Higher values decrease the estimated success probability."
                      value={@configuration.prior_beta}
                      min="0.0001"
                      max="1000"
                      disabled={@experiment.state != :draft}
                    />
                    <.number_field
                      key="warm_up_assignments"
                      label="Warm-up assignments"
                      help="Assignments use each condition's Warm-up weight as weighted random allocation until this total assignment threshold is met. Afterward, Thompson Sampling uses the collected evidence for adaptive allocation."
                      value={@configuration.warm_up_assignments}
                      min="0"
                      step="1"
                      disabled={@experiment.state != :draft}
                    />
                    <.number_field
                      key="max_condition_share"
                      label="Max condition share"
                      help="The traffic cap limits the largest share of assignments any one condition may receive."
                      value={@configuration.max_condition_share}
                      min="0.0001"
                      max="1"
                      disabled={@experiment.state != :draft}
                    />
                    <.number_field
                      key="fixed_control_allocation"
                      label="Fixed-control allocation"
                      help="The target share reserved for the control condition while the fixed-control guardrail is active."
                      value={@configuration.fixed_control_allocation}
                      min="0"
                      max="1"
                      required={false}
                      disabled={@experiment.state != :draft}
                    />
                    <.number_field
                      key="imbalance_threshold"
                      label="Imbalance warning threshold"
                      help="Shows a warning when a condition's observed assignment share differs from an even allocation by more than this amount."
                      value={@configuration.imbalance_threshold}
                      min="0"
                      max="1"
                      disabled={@experiment.state != :draft}
                    />
                  </div>
                </div>
                <div :if={@configuration.algorithm == :thompson_sampling} class="mt-3">
                  <h5 class="h6 mb-3 mt-4 !font-medium">Interventions</h5>
                  <div
                    :for={
                      {intervention, intervention_index} <-
                        Enum.with_index(@configuration.interventions)
                    }
                    class="mb-3 grid grid-cols-1 gap-3 rounded border p-3 md:grid-cols-[repeat(4,minmax(0,1fr))_auto] dark:border-gray-700"
                  >
                    <.selector_field
                      intervention_index={intervention_index}
                      key="page_resource_id"
                      label="Intervention page"
                      value={intervention.page_resource_id}
                      display_value={page_option_label(@page_options, intervention.page_resource_id)}
                      picker_kind="intervention_page"
                      disabled={@experiment.state != :draft}
                    />
                    <.selector_field
                      intervention_index={intervention_index}
                      key="content_element_id"
                      label="Placement element ID"
                      value={intervention.content_element_id}
                      display_value={intervention.content_element_id}
                      picker_kind="placement_element"
                      disabled={@experiment.state != :draft or is_nil(intervention.page_resource_id)}
                    />
                    <.selector_field
                      intervention_index={intervention_index}
                      key="assessment_page_resource_id"
                      label="Scored page"
                      value={intervention.assessment_page_resource_id}
                      display_value={
                        page_option_label(@page_options, intervention.assessment_page_resource_id)
                      }
                      picker_kind="assessment_page"
                      required={false}
                      disabled={@experiment.state != :draft}
                    />
                    <.text_field
                      intervention_index={intervention_index}
                      key="reward_threshold"
                      label="Success threshold"
                      value={intervention.reward_threshold}
                      required={false}
                      disabled={@experiment.state != :draft}
                    />
                    <button
                      :if={@experiment.state == :draft}
                      id={"remove-intervention-#{intervention_index}"}
                      type="button"
                      class="mt-6 inline-flex h-[42px] w-[42px] self-start items-center justify-center rounded-md text-red-600 hover:bg-red-50 hover:text-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 dark:text-red-400 dark:hover:bg-red-950/30"
                      phx-click="remove_draft_intervention"
                      phx-value-intervention-index={intervention_index}
                      phx-hook="GlobalTooltip"
                      data-tooltip="Remove intervention"
                      data-tooltip-style="body"
                      aria-label="Remove intervention"
                    >
                      <i class="fa-solid fa-trash" aria-hidden="true"></i>
                    </button>
                  </div>
                  <button
                    :if={@experiment.state == :draft}
                    type="button"
                    class="btn btn-link px-0"
                    phx-click="add_draft_intervention"
                  >
                    Add intervention
                  </button>
                </div>
              </div>

              <div
                :if={@experiment.state in [:draft, :active, :paused]}
                class="mt-4 flex justify-end"
              >
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={not configuration_dirty?(@configuration_changeset)}
                >
                  Save configuration
                </button>
              </div>
            </div>
          </.form>
        </div>
      </section>

      <section
        :if={show_policy_report?(@experiment, @policy_snapshot)}
        id="experiment-policy-report"
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="experiment-policy-report-heading"
      >
        <div class="card-header bg-white px-4 py-3 dark:border-gray-700 dark:bg-neutral-800">
          <div class="d-flex justify-content-between align-items-center gap-3">
            <div>
              <h3 id="experiment-policy-report-heading" class="h5 mb-1 !font-semibold">
                Thompson Sampling policy
              </h3>
              <p class="text-muted mb-0 dark:text-gray-400">
                Current bounded policy state. Allocation is observed traffic, not a prediction.
              </p>
            </div>
            <button
              type="button"
              class="btn btn-link d-inline-flex align-items-center gap-2 px-0"
              phx-click="refresh_policy_snapshot"
              phx-disable-with="Refreshing…"
            >
              <.icon name="fa-solid fa-rotate-right" class="h-4 w-4" /> Refresh
            </button>
          </div>
        </div>
        <div class="card-body px-4 pt-4">
          <div :if={@experiment.state in [:paused, :completed, :archived]} class="alert alert-info">
            {lifecycle_policy_message(@experiment.state)}
          </div>
          <div id="policy-snapshot-table-scroll" class="overflow-x-auto">
            <table id="policy-snapshot-table" class="table table-sm dark:text-gray-100">
              <caption class="sr-only">Current Thompson Sampling condition policy state</caption>
              <thead>
                <tr>
                  <th scope="col">Condition</th>
                  <th scope="col">
                    <.technical_term
                      id="estimated-success-probability-help"
                      label="Estimated success probability"
                      help="The posterior mean: alpha divided by alpha plus beta. It summarizes observed evidence and configured priors; it is not the probability of the next assignment."
                    />
                  </th>
                  <th scope="col">Accepted successes</th>
                  <th scope="col">Accepted failures</th>
                  <th scope="col">Observed assignments</th>
                  <th scope="col">
                    <.technical_term
                      id="observed-share-help"
                      label="Observed share"
                      help="The percentage of recorded assignments in this experiment that went to this condition."
                    />
                  </th>
                  <th scope="col">
                    <.technical_term
                      id="policy-status-help"
                      label="Policy status"
                      help="The guardrail currently governing allocation. Traffic cap prevents a condition from exceeding its configured maximum share."
                    />
                  </th>
                  <th scope="col">Last updated</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={row <- @policy_snapshot}
                  id={"policy-condition-#{row.condition_id}"}
                >
                  <td>{row.condition_label}</td>
                  <td>{format_percent(row.estimated_success_probability)}</td>
                  <td>{row.accepted_success_count}</td>
                  <td>{row.accepted_failure_count}</td>
                  <td>{row.assignment_count}</td>
                  <td>{format_percent(row.assignment_share)}</td>
                  <td>
                    <.technical_term
                      id={"policy-mode-help-#{row.condition_id}"}
                      label={format_policy_mode(row.effective_mode)}
                      help={policy_mode_help(row.effective_mode)}
                    />
                  </td>
                  <td>{format_snapshot_datetime(row.updated_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div :for={row <- @policy_snapshot} class="mt-3">
            <div class="text-muted small dark:text-gray-400">
              {guardrail_progress(row)}
            </div>
            <div :if={row.imbalance_warning?} class="alert alert-warning" role="status">
              Assignment imbalance monitoring threshold exceeded for {row.condition_label}.
            </div>
            <details id={"policy-technical-details-#{row.condition_id}"}>
              <summary>Technical details for {row.condition_label}</summary>
              <dl class="mt-2 grid grid-cols-2 gap-2 sm:max-w-sm">
                <dt>
                  <.technical_term
                    id={"posterior-alpha-help-#{row.condition_id}"}
                    label="Posterior α"
                    help="Alpha is the accumulated successful evidence plus the configured prior alpha."
                  />
                </dt>
                <dd>{row.posterior_alpha}</dd>
                <dt>
                  <.technical_term
                    id={"posterior-beta-help-#{row.condition_id}"}
                    label="Posterior β"
                    help="Beta is the accumulated unsuccessful evidence plus the configured prior beta."
                  />
                </dt>
                <dd>{row.posterior_beta}</dd>
              </dl>
            </details>
          </div>
        </div>
      </section>

      <section
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="participating-sections-heading"
      >
        <div class="card-header bg-white px-4 py-3 dark:border-gray-700 dark:bg-neutral-800">
          <h3 id="participating-sections-heading" class="h5 mb-0 !font-semibold">
            Participating Sections
          </h3>
        </div>
        <div class="card-body px-4 pt-4">
          <p>Select sections to participate in this experiment.</p>

          <div :if={@participation_error} class="alert alert-danger" role="alert">
            {@participation_error}
          </div>
          <div :if={@participation_success} class="alert alert-success" role="status">
            {@participation_success}
          </div>

          <div :if={Enum.empty?(@participation.eligible_sections)} role="status">
            No active eligible sections are available.
          </div>

          <div
            :if={not Enum.empty?(@participation.eligible_sections)}
            id="participating-sections-table-scroll"
            class="overflow-x-auto"
          >
            <table id="participating-sections-table" class="table table-sm dark:text-gray-100">
              <caption class="sr-only">Sections eligible to participate in this experiment</caption>
              <thead class="dark:border-gray-700 dark:bg-neutral-700 dark:text-gray-100">
                <tr>
                  <th scope="col"><span class="sr-only">Participation selection</span></th>
                  <th scope="col">Section</th>
                  <th scope="col">Slug</th>
                  <th scope="col">Start date</th>
                  <th scope="col">End date</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={section <- @page_sections}
                  id={"participating-section-#{section.id}"}
                  class="dark:border-gray-700"
                >
                  <td>
                    <input
                      type="checkbox"
                      class="form-check-input disabled:cursor-not-allowed disabled:opacity-50"
                      aria-label={"Set participation for #{section.title}"}
                      aria-disabled={to_string(@read_only)}
                      checked={section.id in @participation.selected_ids}
                      disabled={@read_only}
                      phx-click="toggle_section"
                      phx-value-id={section.id}
                    />
                  </td>
                  <td>
                    <a
                      class="text-primary dark:text-blue-300"
                      href={~p"/sections/#{section.slug}/manage"}
                    >
                      {section.title}
                    </a>
                  </td>
                  <td>{section.slug}</td>
                  <td>{format_date(section.start_date)}</td>
                  <td>{format_date(section.end_date)}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <nav :if={@page_count > 1} aria-label="Participating sections pages">
            <ul class="pagination justify-content-end mb-0">
              <li class={["page-item", @page == 1 && "disabled"]}>
                <span
                  :if={@page == 1}
                  id="participating-sections-previous"
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                  aria-disabled="true"
                >
                  Previous
                </span>
                <.link
                  :if={@page > 1}
                  id="participating-sections-previous"
                  patch={page_path(@project.slug, @experiment.id, @page - 1)}
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                >
                  Previous
                </.link>
              </li>
              <li :for={page <- 1..@page_count} class={["page-item", page == @page && "active"]}>
                <.link
                  patch={page_path(@project.slug, @experiment.id, page)}
                  class={[
                    "page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300",
                    page == @page && "dark:!bg-primary dark:!text-white"
                  ]}
                  aria-current={page == @page && "page"}
                >
                  {page}
                </.link>
              </li>
              <li class={["page-item", @page == @page_count && "disabled"]}>
                <span
                  :if={@page == @page_count}
                  id="participating-sections-next"
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                  aria-disabled="true"
                >
                  Next
                </span>
                <.link
                  :if={@page < @page_count}
                  id="participating-sections-next"
                  patch={page_path(@project.slug, @experiment.id, @page + 1)}
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                >
                  Next
                </.link>
              </li>
            </ul>
          </nav>

          <div :if={not Enum.empty?(@participation.stale_sections)} class="alert alert-warning mt-3">
            <strong>Previously selected sections are no longer eligible:</strong>
            {Enum.map_join(@participation.stale_sections, ", ", & &1.title)}
          </div>
        </div>
      </section>

      <OliWeb.Live.Common.FilteredOptionPicker.filtered_option_picker
        :if={@picker}
        id="experiment-option-picker"
        title={@picker.title}
        label={@picker.label}
        description={Map.get(@picker, :description)}
        options={@picker.options}
        filter={@picker.filter}
        description_key={Map.get(@picker, :description_key)}
        position_key={Map.get(@picker, :position_key)}
        selection_mode={@picker.selection_mode}
        selected_values={@picker.selected_values}
        page={@picker.page}
        page_size={@picker.page_size}
        on_toggle="toggle_picker_option"
        on_page="change_picker_page"
        on_select="select_picker_option"
        on_cancel="close_picker"
      />

      <OliWeb.Components.Modal.modal
        :if={@pending_experiment_transition}
        id="confirm-experiment-transition-modal"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-lg p-4"
        on_cancel={Phoenix.LiveView.JS.push("cancel_experiment_transition")}
      >
        <:title>{transition_title(@pending_experiment_transition)}</:title>
        <p>{transition_confirmation(@experiment, @pending_experiment_transition)}</p>
        <:custom_footer>
          <div class="d-flex justify-content-end gap-2 p-4 pt-0">
            <button type="button" class="btn btn-link" phx-click="cancel_experiment_transition">
              Cancel
            </button>
            <button
              type="button"
              class={[
                "btn",
                if(@pending_experiment_transition == :archive,
                  do: "btn-danger",
                  else: "btn-primary"
                )
              ]}
              phx-click="confirm_experiment_transition"
            >
              {transition_button_label(@pending_experiment_transition)}
            </button>
          </div>
        </:custom_footer>
      </OliWeb.Components.Modal.modal>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("start_experiment", _params, socket) do
    transition_experiment(socket, :start)
  end

  def handle_event("pause_experiment", _params, socket) do
    transition_experiment(socket, :pause)
  end

  def handle_event("request_experiment_transition", %{"action" => action}, socket) do
    with {:ok, action} <- parse_confirmation_action(action),
         true <- transition_available?(socket.assigns.experiment.state, action) do
      {:noreply,
       assign(socket,
         pending_experiment_transition: action,
         experiment_action_error: nil
       )}
    else
      _ ->
        {:noreply,
         assign(socket, experiment_action_error: "The requested action is not available.")}
    end
  end

  def handle_event("cancel_experiment_transition", _params, socket) do
    {:noreply, assign(socket, pending_experiment_transition: nil)}
  end

  def handle_event("confirm_experiment_transition", _params, socket) do
    case socket.assigns.pending_experiment_transition do
      action when action in [:complete, :archive] ->
        socket
        |> assign(pending_experiment_transition: nil)
        |> transition_experiment(action)

      nil ->
        {:noreply, assign(socket, experiment_action_error: "No experiment action is pending.")}
    end
  end

  def handle_event("toggle_section", %{"id" => section_id}, socket) do
    with false <- socket.assigns.read_only,
         {:ok, section_id} <- parse_positive_integer(section_id),
         true <- Enum.any?(socket.assigns.participation.eligible_sections, &(&1.id == section_id)),
         selected_ids <- toggle_id(socket.assigns.participation.selected_ids, section_id),
         {:ok, participation} <-
           ABExperiments.update_section_participation(
             socket.assigns.experiment.id,
             authoring_scope(socket),
             selected_ids
           ) do
      {:noreply,
       assign(socket,
         participation: participation,
         participation_success: "Participating sections updated.",
         participation_error: nil
       )}
    else
      {:error, error} when is_struct(error) ->
        {:noreply, assign(socket, participation_error: error.message, participation_success: nil)}

      _ ->
        {:noreply,
         assign(socket,
           participation_error: "The section selection could not be updated.",
           participation_success: nil
         )}
    end
  end

  def handle_event("refresh_policy_snapshot", _params, socket) do
    scope = authoring_scope(socket)

    with {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(socket.assigns.experiment.id, scope),
         {:ok, snapshot} <- ABExperiments.policy_snapshot(authoring_view, scope) do
      {:noreply, assign(socket, authoring_view: authoring_view, policy_snapshot: snapshot)}
    else
      {:error, error} -> {:noreply, assign(socket, experiment_action_error: error.message)}
    end
  end

  def handle_event(
        "open_option_picker",
        %{
          "kind" => kind,
          "intervention-index" => intervention_index
        },
        socket
      ) do
    with :draft <- socket.assigns.experiment.state,
         {:ok, intervention_index} <- parse_index(intervention_index),
         {:ok, picker} <- build_picker(socket, kind, intervention_index) do
      {:noreply, assign(socket, picker: picker)}
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("close_picker", _params, socket), do: {:noreply, assign(socket, picker: nil)}

  def handle_event("toggle_picker_option", %{"id" => value}, socket) do
    with picker when not is_nil(picker) <- socket.assigns.picker do
      selected_values =
        case picker.selection_mode do
          :single -> [value]
          :multiple -> toggle_picker_value(picker.selected_values, value)
        end

      {:noreply, assign(socket, picker: %{picker | selected_values: selected_values})}
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("change_picker_page", %{"offset" => offset}, socket) do
    with picker when not is_nil(picker) <- socket.assigns.picker,
         {:ok, offset} <- parse_non_negative_integer(offset) do
      page = div(offset, picker.page_size) + 1
      {:noreply, assign(socket, picker: %{picker | page: page})}
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("select_picker_option", _params, socket) do
    with %{intervention_index: intervention_index, key: key} <-
           socket.assigns.picker,
         [value] <- socket.assigns.picker.selected_values,
         {:ok, parsed_value} <- parse_picker_value(key, value) do
      socket = assign(socket, picker: nil, configuration_error: nil)

      update_configuration(socket, fn configuration ->
        interventions =
          List.update_at(configuration.interventions, intervention_index, fn intervention ->
            intervention
            |> Map.put(key, parsed_value)
            |> maybe_clear_element_selection(key)
          end)

        %{configuration | interventions: interventions}
      end)
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("add_draft_intervention", _params, socket) do
    update_configuration(socket, fn configuration ->
      %{configuration | interventions: configuration.interventions ++ [empty_intervention()]}
    end)
  end

  def handle_event(
        "remove_draft_intervention",
        %{"intervention-index" => intervention_index},
        socket
      ) do
    with {:ok, intervention_index} <- parse_index(intervention_index) do
      update_configuration(socket, fn configuration ->
        %{
          configuration
          | interventions: List.delete_at(configuration.interventions, intervention_index)
        }
      end)
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event(
        "change_condition_availability",
        %{
          "_target" => ["configuration", "conditions", condition_index, "active"],
          "configuration" => %{"conditions" => conditions}
        },
        socket
      ) do
    with {:ok, condition_index} <- parse_index(condition_index),
         %{"active" => active_value} <- Map.get(conditions, Integer.to_string(condition_index)),
         {:ok, active} <- parse_boolean(active_value),
         condition when not is_nil(condition) <-
           Enum.at(current_configuration(socket).conditions, condition_index) do
      case socket.assigns.experiment.state do
        state when state in [:draft, :active, :paused] ->
          {:noreply,
           update_configuration_socket(socket, fn configuration ->
             Map.update!(configuration, :conditions, fn current_conditions ->
               List.update_at(current_conditions, condition_index, &Map.put(&1, :active, active))
             end)
           end)}

        _state ->
          {:noreply, socket}
      end
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event(
        "change_condition_availability",
        %{"configuration" => %{"conditions" => conditions}} = params,
        socket
      )
      when not is_map_key(params, "_target") do
    case Map.keys(conditions) do
      [condition_index] ->
        handle_event(
          "change_condition_availability",
          Map.put(params, "_target", ["configuration", "conditions", condition_index, "active"]),
          socket
        )

      _ ->
        invalid_configuration_event(socket)
    end
  end

  def handle_event("save_configuration", %{"configuration" => params}, socket) do
    case socket.assigns.experiment.state do
      :draft -> save_draft_configuration(socket, params)
      state when state in [:active, :paused] -> save_condition_availabilities(socket, params)
      _state -> configuration_read_only(socket)
    end
  end

  def handle_event("change_configuration", %{"configuration" => params}, socket) do
    algorithm = socket.assigns.experiment.algorithm

    case {socket.assigns.experiment.state, algorithm} do
      {:draft, _algorithm} ->
        condition_changes = submitted_condition_changes(params["conditions"])
        configuration_changes = submitted_configuration_changes(params, algorithm)

        {:noreply,
         update_configuration_socket(socket, fn configuration ->
           configuration
           |> Map.put(:algorithm, algorithm)
           |> Map.update!(:conditions, &merge_indexed_changes(&1, condition_changes))
           |> Map.merge(configuration_changes)
         end)}

      {state, :weighted_random} when state in [:active, :paused] ->
        condition_changes =
          params["conditions"]
          |> submitted_condition_changes()
          |> normalize_submitted_weights()

        {:noreply,
         update_configuration_socket(socket, fn configuration ->
           Map.update!(configuration, :conditions, &merge_indexed_changes(&1, condition_changes))
         end)}

      _ ->
        {:noreply, socket}
    end
  end

  defp transition_experiment(socket, action) do
    request = %LifecycleRequest{scope: authoring_scope(socket)}

    result =
      case action do
        :start -> ABExperiments.activate_experiment(socket.assigns.experiment.id, request)
        :pause -> ABExperiments.pause_experiment(socket.assigns.experiment.id, request)
        :complete -> ABExperiments.complete_experiment(socket.assigns.experiment.id, request)
        :archive -> ABExperiments.archive_experiment(socket.assigns.experiment.id, request)
      end

    case result do
      {:ok, experiment} ->
        authoring_view = %{socket.assigns.authoring_view | definition: experiment}

        socket =
          assign(socket,
            experiment: experiment,
            authoring_view: authoring_view,
            read_only: experiment.state in [:completed, :archived],
            experiment_action_success: "Experiment updated.",
            experiment_action_error: nil
          )

        case ABExperiments.policy_snapshot(authoring_view, authoring_scope(socket)) do
          {:ok, policy_snapshot} -> {:noreply, assign(socket, policy_snapshot: policy_snapshot)}
          {:error, error} -> {:noreply, assign(socket, experiment_action_error: error.message)}
        end

      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply,
         assign(socket,
           experiment_action_error: error.message,
           experiment_action_success: nil
         )}
    end
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :monospace, :boolean, default: false
  attr :badge, :boolean, default: false
  attr :badge_class, :string, default: "badge-secondary"

  defp detail_item(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="text-muted small text-uppercase font-weight-bold mb-1 dark:text-gray-400">
        {@label}
      </div>
      <div :if={@monospace} class="font-monospace">{@value}</div>
      <span :if={@badge} class={["badge", @badge_class]}>{@value}</span>
      <div :if={not @monospace and not @badge}>{@value}</div>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :min, :string, required: true
  attr :max, :string, default: nil
  attr :step, :string, default: "any"
  attr :required, :boolean, default: true
  attr :help, :string, default: nil
  attr :disabled, :boolean, default: false

  defp number_field(assigns) do
    ~H"""
    <div>
      <label for={"experiment-#{@key}"}>
        <.technical_term
          :if={@help}
          id={"experiment-#{@key}-help"}
          label={@label}
          help={@help}
          element="span"
        />
        <span :if={is_nil(@help)}>{@label}</span>
      </label>
      <input
        id={"experiment-#{@key}"}
        type="number"
        class="form-control disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        name={"configuration[#{@key}]"}
        value={@value}
        min={@min}
        max={@max}
        step={@step}
        required={@required}
        disabled={@disabled}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :help, :string, required: true
  attr :element, :string, values: ["button", "span"], default: "button"

  defp technical_term(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1">
      <span>{@label}</span>
      <.dynamic_tag
        tag_name={@element}
        type={if @element == "button", do: "button"}
        id={@id}
        class={[
          "inline-flex cursor-help text-gray-500 dark:text-gray-400",
          @element == "button" &&
            "rounded-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-900"
        ]}
        phx-hook="GlobalTooltip"
        data-tooltip={@help}
        data-tooltip-style="body"
        data-tooltip-stop-propagation="true"
        tabindex={if @element == "span", do: "0"}
        role={if @element == "span", do: "img"}
        aria-label={"About #{@label}: #{@help}"}
      >
        <.icon name="fa-solid fa-circle-info" class="h-3.5 w-3.5" />
      </.dynamic_tag>
    </span>
    """
  end

  attr :intervention_index, :integer, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :required, :boolean, default: true
  attr :disabled, :boolean, default: false

  defp text_field(assigns) do
    ~H"""
    <div>
      <label for={"intervention-#{@intervention_index}-#{@key}"}>{@label}</label>
      <input
        id={"intervention-#{@intervention_index}-#{@key}"}
        class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-gray-900 shadow-sm outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        name={"configuration[interventions][#{@intervention_index}][#{@key}]"}
        value={@value}
        required={@required}
        disabled={@disabled}
      />
    </div>
    """
  end

  attr :intervention_index, :integer, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :display_value, :any, required: true
  attr :picker_kind, :string, required: true
  attr :required, :boolean, default: true
  attr :disabled, :boolean, default: false

  defp selector_field(assigns) do
    ~H"""
    <div>
      <label for={"intervention-#{@intervention_index}-#{@key}"}>{@label}</label>
      <input
        type="hidden"
        name={"configuration[interventions][#{@intervention_index}][#{@key}]"}
        value={@value}
      />
      <div class="flex w-full">
        <input
          id={"intervention-#{@intervention_index}-#{@key}"}
          class={[
            "min-w-0 flex-1 rounded-l-md rounded-r-none border border-r-0 border-gray-300 bg-white px-3 py-2 text-gray-900 shadow-sm outline-none focus:z-10 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:disabled:bg-gray-700 dark:disabled:text-gray-400",
            @disabled && "cursor-not-allowed",
            !@disabled && "cursor-pointer"
          ]}
          value={@display_value || "Not selected"}
          readonly
          disabled={@disabled}
          aria-required={to_string(@required)}
          aria-haspopup="dialog"
          phx-click={if @disabled, do: nil, else: "open_option_picker"}
          phx-value-kind={@picker_kind}
          phx-value-intervention-index={@intervention_index}
        />
        <button
          type="button"
          class="whitespace-nowrap rounded-l-none rounded-r-md border border-blue-600 bg-white px-3 py-2 font-medium text-blue-700 shadow-sm hover:bg-blue-50 focus:z-10 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:border-gray-300 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-800 dark:text-blue-300 dark:hover:bg-gray-700"
          phx-click="open_option_picker"
          phx-value-kind={@picker_kind}
          phx-value-intervention-index={@intervention_index}
          disabled={@disabled}
          aria-haspopup="dialog"
        >
          Choose…
        </button>
      </div>
    </div>
    """
  end

  defp experiment_configuration(authoring_view) do
    bindings_by_intervention =
      Map.new(authoring_view.assessment_bindings, &{&1.intervention_id, &1})

    definition = authoring_view.definition

    interventions =
      Enum.map(authoring_view.interventions, fn intervention ->
        binding = Map.get(bindings_by_intervention, intervention.id)

        %{
          page_resource_id: intervention.page_resource_id,
          content_element_id: intervention.content_element_id,
          assessment_page_resource_id: binding && binding.assessment_page_resource_id,
          reward_threshold: binding && binding.reward_threshold
        }
      end)

    %{
      algorithm: definition.algorithm,
      assignment_scope: definition.assignment_scope,
      alternatives_resource_id: definition.alternatives_resource_id,
      conditions: Enum.map(authoring_view.conditions, &condition_configuration/1),
      interventions: interventions,
      prior_alpha: definition.prior_alpha,
      prior_beta: definition.prior_beta,
      warm_up_assignments: definition.warm_up_assignments,
      max_condition_share: definition.max_condition_share,
      fixed_control_allocation: definition.fixed_control_allocation,
      imbalance_threshold: definition.imbalance_threshold
    }
  end

  defp condition_configuration(condition) do
    Map.take(condition, [
      :id,
      :condition_code,
      :label,
      :active,
      :option_id,
      :weight,
      :position
    ])
  end

  defp selected_alternatives_candidate(experiment, candidates) do
    Enum.find(candidates, &(&1.alternatives_resource_id == experiment.alternatives_resource_id))
  end

  defp candidate_options(nil), do: []

  defp candidate_options(candidate),
    do: Enum.map(candidate.options, &{candidate.option_labels[&1] || &1, &1})

  defp empty_intervention do
    %{
      page_resource_id: nil,
      content_element_id: nil,
      assessment_page_resource_id: nil,
      reward_threshold: "1.0"
    }
  end

  defp build_picker(socket, "intervention_page", intervention_index) do
    with {:ok, options} <- ABExperiments.list_available_pages(authoring_scope(socket)) do
      {:ok,
       %{
         title: "Choose intervention page",
         label: "Page",
         options: options,
         filter: fn _option -> true end,
         description_key: nil,
         position_key: nil,
         selection_mode: :single,
         selected_values: [],
         page: 1,
         page_size: 8,
         intervention_index: intervention_index,
         key: :page_resource_id
       }}
    end
  end

  defp build_picker(socket, "assessment_page", intervention_index) do
    with {:ok, options} <- ABExperiments.list_available_pages(authoring_scope(socket)) do
      {:ok,
       %{
         title: "Choose scored page",
         label: "Scored page",
         options: options,
         filter: fn option -> option.graded end,
         description_key: nil,
         position_key: nil,
         selection_mode: :single,
         selected_values: [],
         page: 1,
         page_size: 8,
         intervention_index: intervention_index,
         key: :assessment_page_resource_id
       }}
    end
  end

  defp build_picker(socket, "placement_element", intervention_index) do
    with %{alternatives_resource_id: alternatives_resource_id, interventions: interventions} <-
           current_configuration(socket),
         %{page_resource_id: page_resource_id} <- Enum.at(interventions, intervention_index),
         true <- is_integer(page_resource_id),
         {:ok, options} <-
           ABExperiments.list_page_alternatives_elements(
             page_resource_id,
             authoring_scope(socket)
           ) do
      {:ok,
       %{
         title: "Choose placement element",
         label: "A/B Test Alternatives",
         description: "Elements are listed in the order they appear on the page",
         options: Enum.map(options, &describe_element_option/1),
         filter: &experiment_alternatives_element?(&1, alternatives_resource_id),
         description_key: :description,
         position_key: :position,
         selection_mode: :single,
         selected_values: [],
         page: 1,
         page_size: 8,
         intervention_index: intervention_index,
         key: :content_element_id
       }}
    end
  end

  defp build_picker(_socket, _kind, _intervention_index),
    do: {:error, :invalid_picker}

  defp experiment_alternatives_element?(option, alternatives_resource_id),
    do:
      option.type == "alternatives" and option.experiment_controlled? and
        option.alternatives_resource_id == alternatives_resource_id

  defp describe_element_option(option) do
    option
    |> Map.put(:label, element_type_label(option.type))
    |> Map.put(
      :description,
      OliWeb.Common.Utils.extract_text_from_content(option.content)
    )
  end

  defp element_type_label("alternatives"), do: "Alternative Content"
  defp element_type_label(type), do: Oli.Utils.snake_case_to_friendly(type)

  defp parse_picker_value(:content_element_id, value) when is_binary(value) and value != "",
    do: {:ok, value}

  defp parse_picker_value(key, value)
       when key in [:page_resource_id, :assessment_page_resource_id],
       do: parse_positive_integer(value)

  defp parse_picker_value(_key, _value), do: {:error, :invalid_picker_value}

  defp toggle_picker_value(values, value) do
    case value in values do
      true -> List.delete(values, value)
      false -> [value | values]
    end
  end

  defp maybe_clear_element_selection(intervention, :page_resource_id),
    do: %{intervention | content_element_id: nil}

  defp maybe_clear_element_selection(intervention, _key), do: intervention

  defp page_option_label(options, resource_id) do
    case Enum.find(options, &(&1.value == resource_id)) do
      nil -> if(resource_id, do: "Selected page", else: nil)
      option -> option.label
    end
  end

  defp alternatives_candidates(_authoring_view, scope),
    do: ABExperiments.list_available_alternatives(scope)

  defp update_configuration(socket, fun) do
    case socket.assigns.experiment.state do
      :draft ->
        {:noreply, update_configuration_socket(socket, fun)}

      _ ->
        {:noreply, assign(socket, configuration_error: "Experiment configuration is read-only.")}
    end
  end

  defp update_configuration_socket(socket, fun) do
    current = current_configuration(socket)
    updated = fun.(current)
    baseline = socket.assigns.configuration_changeset.data

    changeset = configuration_changeset(baseline, updated)

    assign(socket,
      configuration_changeset: changeset,
      configuration_error: nil,
      configuration_field_errors: configuration_field_errors_for_changeset(changeset)
    )
  end

  defp current_configuration(socket),
    do: Ecto.Changeset.apply_changes(socket.assigns.configuration_changeset)

  defp configuration_changeset(baseline, configuration) do
    baseline =
      baseline |> normalize_configuration() |> ExperimentConfigurationForm.from_configuration()

    configuration = normalize_configuration(configuration)

    ExperimentConfigurationForm.changeset(baseline, configuration)
  end

  defp configuration_dirty?(changeset), do: changeset.valid? and changeset.changes != %{}

  defp normalize_configuration(configuration) do
    configuration
    |> normalize_configuration_number(:prior_alpha)
    |> normalize_configuration_number(:prior_beta)
    |> normalize_configuration_integer(:warm_up_assignments)
    |> normalize_configuration_number(:max_condition_share)
    |> normalize_configuration_number(:fixed_control_allocation, optional: true)
    |> normalize_configuration_number(:imbalance_threshold)
    |> Map.update!(:conditions, fn conditions ->
      Enum.map(conditions, &Map.update!(&1, :weight, fn value -> normalize_number(value) end))
    end)
    |> Map.update!(:interventions, fn interventions ->
      Enum.map(interventions, fn intervention ->
        Map.update!(intervention, :reward_threshold, &normalize_decimal/1)
      end)
    end)
  end

  defp normalize_configuration_number(configuration, key, options \\ []) do
    Map.update!(configuration, key, fn value ->
      case {Keyword.get(options, :optional, false), value} do
        {true, value} when value in [nil, ""] -> nil
        _ -> normalize_number(value)
      end
    end)
  end

  defp normalize_configuration_integer(configuration, key) do
    Map.update!(configuration, key, fn
      value when is_integer(value) -> value
      value -> parse_normalized_integer(value)
    end)
  end

  defp normalize_number(value) when is_number(value), do: value

  defp normalize_number(value) do
    case Float.parse(to_string(value)) do
      {number, ""} -> number
      _ -> value
    end
  end

  defp parse_normalized_integer(value) do
    case Integer.parse(to_string(value)) do
      {integer, ""} -> integer
      _ -> value
    end
  end

  defp normalize_decimal(nil), do: nil
  defp normalize_decimal(%Decimal{} = value), do: value

  defp normalize_decimal(value) do
    case Decimal.cast(value) do
      {:ok, decimal} -> decimal
      :error -> value
    end
  end

  defp parse_index(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp parse_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {index, ""} when index >= 0 -> {:ok, index}
      _ -> {:error, :invalid_index}
    end
  end

  defp parse_index(_value), do: {:error, :invalid_index}

  defp invalid_configuration_event(socket),
    do: {:noreply, assign(socket, configuration_error: "Invalid configuration selection.")}

  defp save_draft_configuration(socket, params) do
    with :draft <- socket.assigns.experiment.state,
         {:ok, request} <- configuration_request(socket, params),
         {:ok, experiment} <-
           ABExperiments.update_experiment(socket.assigns.experiment.id, request),
         {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(experiment.id, authoring_scope(socket)) do
      {:noreply,
       assign(socket,
         experiment: experiment,
         authoring_view: authoring_view,
         configuration_changeset:
           authoring_view
           |> experiment_configuration()
           |> then(&configuration_changeset(&1, &1)),
         configuration_success: "Experiment configuration saved.",
         configuration_error: nil,
         configuration_field_errors: %{}
       )}
    else
      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        field_errors = configuration_field_errors_for_experiment_error(error)

        {:noreply,
         assign(socket,
           configuration_error: if(field_errors == %{}, do: error.message, else: nil),
           configuration_field_errors: field_errors,
           configuration_success: nil
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           configuration_error: nil,
           configuration_field_errors: configuration_field_errors_for_changeset(changeset),
           configuration_success: nil
         )}

      {:error, message} when is_binary(message) ->
        {:noreply,
         assign(socket,
           configuration_error: message,
           configuration_field_errors: %{},
           configuration_success: nil
         )}

      _ ->
        configuration_read_only(socket)
    end
  end

  defp save_condition_availabilities(socket, _params) do
    scope = authoring_scope(socket)

    condition_fields =
      case socket.assigns.experiment.algorithm do
        :weighted_random -> [:id, :active, :weight]
        _ -> [:id, :active]
      end

    availabilities =
      Enum.map(current_configuration(socket).conditions, &Map.take(&1, condition_fields))

    with {:ok, _conditions} <-
           ABExperiments.update_condition_availabilities(
             socket.assigns.experiment.id,
             availabilities,
             scope
           ),
         {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(socket.assigns.experiment.id, scope) do
      {:noreply,
       assign(socket,
         authoring_view: authoring_view,
         configuration_changeset:
           authoring_view
           |> experiment_configuration()
           |> then(&configuration_changeset(&1, &1)),
         configuration_success: "Experiment configuration saved.",
         configuration_error: nil
       )}
    else
      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply,
         assign(socket,
           configuration_error: error.message,
           configuration_success: nil
         )}
    end
  end

  defp configuration_read_only(socket) do
    {:noreply,
     assign(socket,
       configuration_error: "Experiment configuration is read-only.",
       configuration_success: nil
     )}
  end

  defp configuration_request(socket, params) do
    algorithm = socket.assigns.experiment.algorithm

    with {:ok, %{assignment_scope: assignment_scope}} <-
           ExperimentConfigurationForm.cast_assignment_scope(params),
         {:ok, conditions} <- parse_conditions(params["conditions"]),
         {:ok, resource_id} <- parse_positive_integer(params["alternatives_resource_id"]),
         {:ok, interventions} <- parse_interventions(params["interventions"], algorithm),
         {:ok, policy_fields} <- parse_policy_fields(params, algorithm) do
      {:ok,
       %UpdateExperimentRequest{
         scope: authoring_scope(socket),
         algorithm: algorithm,
         assignment_scope: assignment_scope,
         alternatives_resource_id: resource_id,
         prior_alpha: policy_fields.prior_alpha,
         prior_beta: policy_fields.prior_beta,
         warm_up_assignments: policy_fields.warm_up_assignments,
         max_condition_share: policy_fields.max_condition_share,
         fixed_control_allocation: policy_fields.fixed_control_allocation,
         imbalance_threshold: policy_fields.imbalance_threshold,
         reward_source: policy_fields.reward_source,
         conditions: conditions,
         interventions: interventions
       }}
    end
  end

  defp parse_conditions(params) when is_map(params) do
    params
    |> ordered_values()
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {condition, position}, {:ok, acc} ->
      with {:ok, id} <- parse_positive_integer(condition["id"]),
           label when is_binary(label) and label != "" <- String.trim(condition["label"] || ""),
           {:ok, active} <- parse_boolean(condition["active"]),
           option_id when is_binary(option_id) and option_id != "" <- condition["option_id"],
           {:ok, weight} <- parse_non_negative_number(condition["weight"]) do
        parsed = %{
          id: id,
          label: label,
          active: active,
          option_id: option_id,
          weight: weight,
          position: position
        }

        {:cont, {:ok, [parsed | acc]}}
      else
        _ -> {:halt, {:error, "Every condition requires a label and valid identity."}}
      end
    end)
    |> reverse_parsed_values()
  end

  defp parse_conditions(_params), do: {:error, "At least two conditions are required."}

  defp parse_interventions(_params, :weighted_random), do: {:ok, []}

  defp parse_interventions(params, :thompson_sampling) when is_map(params) do
    params
    |> ordered_values()
    |> Enum.reduce_while({:ok, []}, fn intervention, {:ok, acc} ->
      with {:ok, page_resource_id} <- parse_positive_integer(intervention["page_resource_id"]),
           element_id when is_binary(element_id) and element_id != "" <-
             String.trim(intervention["content_element_id"] || ""),
           {:ok, binding} <- parse_binding(intervention, :thompson_sampling) do
        parsed = %{
          page_resource_id: page_resource_id,
          content_element_id: element_id,
          assessment_binding: binding
        }

        {:cont, {:ok, [parsed | acc]}}
      else
        _ -> {:halt, {:error, "Every intervention requires a page resource and placement ID."}}
      end
    end)
    |> reverse_parsed_values()
  end

  defp parse_interventions(_params, _algorithm),
    do: {:error, "The experiment requires at least one intervention."}

  defp reverse_parsed_values({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reverse_parsed_values(error), do: error

  defp parse_binding(params, :thompson_sampling) do
    with {:ok, page_id} <- parse_positive_integer(params["assessment_page_resource_id"]),
         {:ok, threshold} <- parse_share(params["reward_threshold"]) do
      {:ok,
       %{assessment_page_resource_id: page_id, reward_threshold: Decimal.from_float(threshold)}}
    end
  end

  defp parse_policy_fields(point, algorithm)
       when algorithm in [:weighted_random, :thompson_sampling] do
    with {:ok, alpha} <- parse_positive_number(point["prior_alpha"]),
         {:ok, beta} <- parse_positive_number(point["prior_beta"]),
         {:ok, warm_up} <- parse_non_negative_integer(point["warm_up_assignments"]),
         {:ok, max_share} <- parse_share(point["max_condition_share"]),
         {:ok, fixed} <- parse_optional_share(point["fixed_control_allocation"]),
         {:ok, imbalance} <- parse_share(point["imbalance_threshold"]) do
      {:ok,
       %{
         prior_alpha: alpha,
         prior_beta: beta,
         warm_up_assignments: warm_up,
         max_condition_share: max_share,
         fixed_control_allocation: fixed,
         imbalance_threshold: imbalance,
         reward_source: "assessment_page:normalized_score"
       }}
    end
  end

  defp submitted_configuration_changes(params, algorithm) when is_map(params) do
    ~w(prior_alpha prior_beta warm_up_assignments max_condition_share fixed_control_allocation imbalance_threshold)
    |> Enum.reduce(%{algorithm: algorithm}, fn key, changes ->
      case Map.fetch(params, key) do
        {:ok, value} -> Map.put(changes, String.to_existing_atom(key), value)
        :error -> changes
      end
    end)
    |> put_submitted(:assignment_scope, params["assignment_scope"])
    |> Map.put(:interventions, submitted_intervention_values(params["interventions"]))
  end

  defp submitted_configuration_changes(_params, algorithm), do: %{algorithm: algorithm}

  defp configuration_field_errors_for_experiment_error(%{
         details: %{field: field},
         message: message
       })
       when is_atom(field),
       do: %{field => message}

  defp configuration_field_errors_for_experiment_error(_error), do: %{}

  defp configuration_field_errors_for_changeset(changeset) do
    ExperimentConfigurationForm.field_errors(changeset)
  end

  defp configuration_field_error(errors, field), do: Map.get(errors, field)

  defp submitted_condition_changes(params) when is_map(params) do
    submitted_indexed_changes(params, fn condition ->
      %{}
      |> put_submitted(:label, condition["label"])
      |> put_submitted(:active, submitted_boolean(condition["active"]))
      |> put_submitted(:option_id, condition["option_id"])
      |> put_submitted(:weight, condition["weight"])
    end)
  end

  defp submitted_condition_changes(_params), do: %{}

  defp normalize_submitted_weights(changes) do
    Map.new(changes, fn {index, condition} ->
      normalized =
        case Map.fetch(condition, :weight) do
          {:ok, weight} ->
            case parse_non_negative_number(to_string(weight)) do
              {:ok, parsed} -> Map.put(condition, :weight, parsed)
              {:error, _reason} -> condition
            end

          :error ->
            condition
        end

      {index, normalized}
    end)
  end

  defp submitted_intervention_changes(params) when is_map(params) do
    submitted_indexed_changes(params, fn intervention ->
      %{}
      |> put_submitted(
        :page_resource_id,
        submitted_positive_integer(intervention["page_resource_id"])
      )
      |> put_submitted(:content_element_id, intervention["content_element_id"])
      |> put_submitted(
        :assessment_page_resource_id,
        submitted_positive_integer(intervention["assessment_page_resource_id"])
      )
      |> put_submitted(:reward_threshold, intervention["reward_threshold"])
    end)
  end

  defp submitted_intervention_changes(_params), do: %{}

  defp submitted_intervention_values(params) when is_map(params) do
    params
    |> submitted_intervention_changes()
    |> then(
      &merge_indexed_changes(
        Enum.map(ordered_values(params), fn _ -> empty_intervention() end),
        &1
      )
    )
  end

  defp submitted_intervention_values(_params), do: []

  defp submitted_indexed_changes(params, changes_for_value) do
    Enum.reduce(params, %{}, fn {index, value}, changes ->
      case parse_index(index) do
        {:ok, parsed_index} -> Map.put(changes, parsed_index, changes_for_value.(value))
        _ -> changes
      end
    end)
  end

  defp merge_indexed_changes(values, changes) do
    Enum.with_index(values, fn value, index ->
      case Map.get(changes, index) do
        value_changes when is_map(value_changes) ->
          Map.merge(value, value_changes)

        nil ->
          value
      end
    end)
  end

  defp put_submitted(changes, _key, nil), do: changes
  defp put_submitted(changes, key, value), do: Map.put(changes, key, value)

  defp submitted_boolean("true"), do: true
  defp submitted_boolean("false"), do: false
  defp submitted_boolean(value), do: value

  defp submitted_positive_integer(value) do
    case parse_positive_integer(value) do
      {:ok, parsed} -> parsed
      _ -> value
    end
  end

  defp ordered_values(map) do
    map
    |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, acc} ->
      case parse_index(key) do
        {:ok, index} -> {:cont, {:ok, [{index, value} | acc]}}
        _ -> {:halt, {:error, :invalid_collection}}
      end
    end)
    |> case do
      {:ok, indexed} -> indexed |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))
      {:error, _} -> []
    end
  end

  defp parse_boolean("true"), do: {:ok, true}
  defp parse_boolean("false"), do: {:ok, false}
  defp parse_boolean(_), do: {:error, :invalid_boolean}

  defp parse_non_negative_number(value) do
    case Float.parse(value || "") do
      {number, ""} when number >= 0 -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end

  defp parse_positive_number(value) do
    case parse_non_negative_number(value) do
      {:ok, number} when number >= 0.0001 and number <= 1000 -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end

  defp parse_non_negative_integer(value) do
    case Integer.parse(value || "") do
      {number, ""} when number >= 0 -> {:ok, number}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_share(value) do
    case parse_non_negative_number(value) do
      {:ok, number} when number >= 0 and number <= 1 -> {:ok, number}
      _ -> {:error, :invalid_share}
    end
  end

  defp parse_optional_share(value) when value in [nil, ""], do: {:ok, nil}
  defp parse_optional_share(value), do: parse_share(value)

  defp show_policy_report?(experiment, snapshot),
    do: experiment.state != :draft and snapshot != []

  defp condition_weight_editable?(%{state: :draft}), do: true

  defp condition_weight_editable?(%{algorithm: :weighted_random, state: state})
       when state in [:active, :paused],
       do: true

  defp condition_weight_editable?(_experiment), do: false

  defp condition_weight_label(:thompson_sampling), do: "Warm-up weight"
  defp condition_weight_label(_algorithm), do: "Weight"

  defp format_percent(value), do: :erlang.float_to_binary(value * 100, decimals: 1) <> "%"

  defp format_policy_mode(:warm_up_weighted_random), do: "Warm-up weighted random"
  defp format_policy_mode(:fixed_control), do: "Fixed-control enforcement"
  defp format_policy_mode(:traffic_cap), do: "Traffic-cap enforcement"
  defp format_policy_mode(:thompson_sampling), do: "Thompson Sampling"

  defp policy_mode_help(:warm_up_weighted_random),
    do:
      "Assignments are being distributed for initial evidence before adaptive allocation begins."

  defp policy_mode_help(:fixed_control),
    do:
      "Allocation is currently preserving the configured assignment share for the control condition."

  defp policy_mode_help(:traffic_cap),
    do:
      "The traffic cap is preventing a condition from exceeding its configured maximum assignment share."

  defp policy_mode_help(:thompson_sampling),
    do:
      "No guardrail is currently active; Thompson Sampling is using the current posterior evidence."

  defp policy_mode_help(_mode), do: "The allocation behavior currently active for this condition."

  defp guardrail_progress(%{effective_mode: :warm_up_weighted_random} = row) do
    "Warm-up progress: #{row.guardrail_state["assignment_count"]}/#{row.guardrail_state["warm_up_assignments"]} assignments"
  end

  defp guardrail_progress(%{effective_mode: :fixed_control} = row) do
    "Fixed-control target: #{format_percent(row.guardrail_state["fixed_control_allocation"])}"
  end

  defp guardrail_progress(%{effective_mode: :traffic_cap} = row) do
    "Traffic cap: #{format_percent(row.guardrail_state["max_condition_share"])}"
  end

  defp guardrail_progress(row) do
    "Imbalance warning threshold: #{format_percent(row.guardrail_state["imbalance_threshold"])}"
  end

  defp lifecycle_policy_message(:paused),
    do: "Assignment is paused. The policy snapshot remains current."

  defp lifecycle_policy_message(:completed),
    do: "Assignment has ended. This is the frozen final snapshot."

  defp lifecycle_policy_message(:archived),
    do: "This archived experiment shows its frozen final snapshot."

  defp format_snapshot_datetime(nil), do: "—"
  defp format_snapshot_datetime(value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M UTC")

  defp authoring_scope(socket) do
    %Scope{
      author_id: socket.assigns.ctx.author.id,
      project_id: socket.assigns.project.id
    }
  end

  defp page_sections(participation, page) do
    participation.eligible_sections
    |> Enum.slice((page - 1) * @page_size, @page_size)
  end

  defp page_count(participation) do
    max(ceil(length(participation.eligible_sections) / @page_size), 1)
  end

  defp clamp_page(page, participation), do: min(page, page_count(participation))

  defp parse_page(value) do
    case parse_positive_integer(value || "1") do
      {:ok, page} -> page
      _ -> 1
    end
  end

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_positive_integer(_value), do: {:error, :invalid_integer}

  defp toggle_id(ids, id) do
    if id in ids, do: List.delete(ids, id), else: Enum.sort([id | ids])
  end

  defp page_path(project_slug, experiment_id, page) do
    "/workspaces/course_author/#{project_slug}/experiments/#{experiment_id}?page=#{max(page, 1)}"
  end

  defp format_algorithm(:weighted_random), do: "Weighted random"
  defp format_algorithm(:thompson_sampling), do: "Thompson Sampling"
  defp format_algorithm(value), do: display_value(value)

  defp format_assignment_scope(:section_enrollment),
    do: "Same condition within each participating course section"

  defp format_assignment_scope(:intervention), do: "Independent at each intervention"

  defp format_state(value), do: display_value(value)

  defp status_badge_class(:active), do: "badge-primary"
  defp status_badge_class(:completed), do: "badge-success"
  defp status_badge_class(_state), do: "badge-secondary"

  defp parse_confirmation_action("complete"), do: {:ok, :complete}
  defp parse_confirmation_action("archive"), do: {:ok, :archive}
  defp parse_confirmation_action(_action), do: {:error, :invalid_action}

  defp transition_available?(state, :complete), do: state in [:active, :paused]
  defp transition_available?(state, :archive), do: state in [:draft, :completed]
  defp transition_available?(_state, _action), do: false

  defp transition_title(:complete), do: "Complete Experiment"
  defp transition_title(:archive), do: "Archive Experiment"

  defp transition_button_label(:complete), do: "Complete"
  defp transition_button_label(:archive), do: "Archive"

  defp transition_confirmation(experiment, :complete) do
    "Complete “#{experiment.name}”? Participation can no longer be changed after completion."
  end

  defp transition_confirmation(experiment, :archive) do
    "Archive “#{experiment.name}”? The experiment will be removed from active use."
  end

  defp display_value(nil), do: "—"

  defp display_value(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = value), do: value |> DateTime.to_date() |> format_date()

  defp format_date(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.to_date() |> format_date()

  defp format_date(%Date{} = value), do: Oli.Cldr.Date.to_string!(value, format: :medium)
end
