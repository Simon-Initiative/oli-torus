defmodule OliWeb.Workspaces.CourseAuthor.ExperimentsLive do
  use OliWeb, :live_view
  use Phoenix.HTML

  import Oli.Utils, only: [uuid: 0]
  alias OliWeb.Workspaces.CourseAuthor.AlternativesGroupManager

  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Authoring.Editing.{AlternativesOptionEditor, ResourceEditor}
  alias Oli.Experiments, as: ABExperiments
  alias Oli.Experiments.{CreateExperimentRequest, Scope}
  alias Oli.Experiments.Policies.ThompsonSampling
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Utils.Slug
  alias OliWeb.Components.ReorderableList
  alias Phoenix.LiveView.JS

  @default_error_message "Something went wrong. Please refresh the page and try again."
  @alternatives_type_id ResourceType.id_for_alternatives()
  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project
    scope = authoring_scope(socket)

    socket =
      socket
      |> assign_decision_points()
      |> subscribe_to_decision_points()
      |> assign_authoring_experiments()
      |> start_async(:load_eligible_sections, fn ->
        ABExperiments.list_eligible_sections(scope)
      end)

    {:ok,
     assign(socket,
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

      <%= if @experiment_error && !@show_create_experiment do %>
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
        <div id="ab-experiments-table-scroll" class="overflow-x-auto">
          <table class="table table-sm" id="ab-experiments-table">
            <caption class="sr-only">A/B Testing experiments</caption>
            <thead>
              <tr>
                <th scope="col">Name</th>
                <th scope="col">Slug</th>
                <th scope="col">Algorithm</th>
                <th scope="col">Status</th>
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
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>

      <section class="mt-10" aria-labelledby="decision-points-heading">
        <div class="mb-3">
          <h3 id="decision-points-heading" class="h4 mb-0">
            Experiment-Controlled Alternatives
          </h3>
        </div>
        <%= if Enum.empty?(@decision_points) do %>
          <div>
            No experiment-controlled alternatives groups have been created yet.
          </div>
        <% else %>
          <AlternativesGroupManager.group_card
            :for={decision_point <- @decision_points}
            group={decision_point}
            item_label="Condition"
            empty_item_label="There are no conditions in this group"
            create_item_event="show_new_condition_form"
            delete_group_event="show_delete_decision_point_modal"
          >
            <:new_item_form :if={
              MapSet.member?(@open_new_condition_forms, decision_point.resource_id)
            }>
              <.new_condition_form
                group={decision_point}
                name={Map.get(@new_condition_names, decision_point.resource_id, "")}
              />
            </:new_item_form>
          </AlternativesGroupManager.group_card>
        <% end %>
        <div class="d-flex justify-content-start mt-3">
          <button class="btn btn-outline-primary" phx-click="show_create_decision_point">
            <i class="fa fa-plus"></i> New Decision Point
          </button>
        </div>
      </section>

      <OliWeb.Components.Modal.modal
        :if={@decision_point_modal}
        id={@decision_point_modal.id}
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-lg p-4"
        on_cancel={JS.push("close_decision_point_modal")}
      >
        <:title>{@decision_point_modal.title}</:title>
        <.form
          for={@decision_point_modal.form}
          id={"#{@decision_point_modal.id}-form"}
          phx-submit={@decision_point_modal.on_submit}
        >
          <input
            :for={{name, value} <- @decision_point_modal.hidden_fields}
            type="hidden"
            name={"params[#{name}]"}
            value={value}
          />
          <div class="form-group">
            <label for={"#{@decision_point_modal.id}-name"}>
              {@decision_point_modal.field_label}
            </label>
            <input
              id={"#{@decision_point_modal.id}-name"}
              type="text"
              name={"params[#{@decision_point_modal.field_name}]"}
              value={@decision_point_modal.field_value}
              class="form-control"
              placeholder={@decision_point_modal.placeholder}
              phx-hook="InputAutoSelect"
              required
            />
          </div>
          <div class="d-flex justify-content-end gap-2">
            <button
              type="button"
              class="btn btn-link"
              phx-click="close_decision_point_modal"
            >
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              {@decision_point_modal.submit_label}
            </button>
          </div>
        </.form>
      </OliWeb.Components.Modal.modal>

      <OliWeb.Components.Modal.modal
        :if={@decision_point_delete_modal}
        id={@decision_point_delete_modal.id}
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-lg p-4"
        on_cancel={JS.push("close_decision_point_delete_modal")}
      >
        <:title>{@decision_point_delete_modal.title}</:title>
        <p>{@decision_point_delete_modal.message}</p>
        <div class="text-center my-3">
          <strong>{@decision_point_delete_modal.item_name}</strong>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button
            type="button"
            class="btn btn-link"
            phx-click="close_decision_point_delete_modal"
          >
            Cancel
          </button>
          <button
            type="button"
            class="btn btn-danger"
            phx-click={
              JS.push(@decision_point_delete_modal.on_delete,
                value: @decision_point_delete_modal.values
              )
            }
          >
            Delete
          </button>
        </div>
      </OliWeb.Components.Modal.modal>

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
        :if={@show_create_experiment}
        id="create-experiment-modal"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-3xl p-4"
        on_cancel={Phoenix.LiveView.JS.push("close_create_experiment")}
      >
        <:title>Create Experiment</:title>
        <div
          :if={@experiment_error}
          id="create-experiment-error"
          class="alert alert-danger"
          role="alert"
          tabindex="-1"
          phx-mounted={JS.focus()}
        >
          {@experiment_error}
        </div>
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
                class={"form-control #{field_error_class(@experiment_field_errors, :slug)}"}
                name="experiment[slug]"
                value={@experiment_params["slug"]}
                aria-invalid={field_invalid?(@experiment_field_errors, :slug)}
                aria-describedby={field_error_id(@experiment_field_errors, :slug)}
                required
              />
              <%= if error = field_error(@experiment_field_errors, :slug) do %>
                <div id="experiment_slug_error" class="mb-2 block text-sm text-red-600">
                  {error}
                </div>
              <% end %>
              <div :if={@experiment_slug_suggestion} class="form-text">
                Suggested slug:
                <button
                  type="button"
                  id="use-suggested-experiment-slug"
                  class="btn btn-link p-0 align-baseline"
                  phx-click="use_suggested_experiment_slug"
                >
                  {@experiment_slug_suggestion}
                </button>
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

  @impl Phoenix.LiveView
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
        field_errors = field_errors_for_experiment_error(error)

        {:noreply,
         assign(socket,
           experiment_error: experiment_error_message(error, field_errors),
           experiment_success: nil,
           experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
           experiment_field_errors: field_errors,
           experiment_params: params,
           experiment_slug_suggestion: suggested_experiment_slug(params["name"])
         )}
    end
  end

  def handle_event("change_experiment_form", %{"experiment" => params}, socket) do
    previous_params = socket.assigns.experiment_params

    slug_suggestion =
      case params["name"] == previous_params["name"] do
        true -> socket.assigns.experiment_slug_suggestion
        false -> suggested_experiment_slug(params["name"])
      end

    params = Map.merge(previous_params, params)

    {:noreply,
     assign(socket,
       experiment_algorithm: Map.get(params, "algorithm", "weighted_random"),
       experiment_error: nil,
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
           experiment_error: nil,
           experiment_field_errors: %{},
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

  def handle_event("show_create_decision_point", _params, socket) do
    modal = %{
      id: "create_decision_point_modal",
      title: "Create Decision Point",
      submit_label: "Create",
      on_submit: "create_decision_point",
      form: to_form(%{}, as: :params),
      field_name: "name",
      field_label: "Name",
      field_value: "",
      placeholder: "Enter a name for the decision point",
      hidden_fields: []
    }

    {:noreply, assign(socket, decision_point_modal: modal)}
  end

  def handle_event("create_decision_point", %{"params" => %{"name" => name}}, socket) do
    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns

    case ResourceEditor.create(
           project.slug,
           ctx.author,
           @alternatives_type_id,
           %{title: name, content: %{"options" => [], "strategy" => "experiment_controlled"}}
         ) do
      {:ok, decision_point} ->
        {:noreply,
         socket
         |> assign(decision_point_modal: nil)
         |> assign(decision_points: sort_decision_points([decision_point | decision_points]))
         |> assign_authoring_experiments()}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_new_condition_form",
        %{"resource-id" => resource_id},
        socket
      ) do
    resource_id = ensure_integer(resource_id)

    {:noreply,
     assign(
       socket,
       :open_new_condition_forms,
       MapSet.put(socket.assigns.open_new_condition_forms, resource_id)
     )}
  end

  def handle_event(
        "change_new_condition",
        %{"condition" => %{"name" => name, "resource_id" => resource_id}},
        socket
      ) do
    resource_id = ensure_integer(resource_id)

    {:noreply,
     assign(
       socket,
       :new_condition_names,
       Map.put(socket.assigns.new_condition_names, resource_id, name)
     )}
  end

  def handle_event(
        "create_new_condition",
        %{"condition" => %{"name" => name, "resource_id" => resource_id}},
        socket
      ) do
    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns
    resource_id = ensure_integer(resource_id)
    %{content: %{"options" => options} = content} = find_group(decision_points, resource_id)

    case String.trim(name) do
      "" ->
        {:noreply, socket}

      name ->
        new_options = options ++ [%{"id" => uuid(), "name" => name}]

        case edit_group_options(
               project.slug,
               ctx.author,
               decision_points,
               resource_id,
               content,
               new_options
             ) do
          {:ok, decision_points, _group} ->
            {:noreply,
             socket
             |> assign(decision_points: decision_points)
             |> assign(
               new_condition_names: Map.delete(socket.assigns.new_condition_names, resource_id),
               open_new_condition_forms:
                 MapSet.delete(socket.assigns.open_new_condition_forms, resource_id)
             )
             |> assign_authoring_experiments()}

          {:error, message: error_message} ->
            show_error(socket, error_message)

          {:error, _} ->
            show_error(socket)
        end
    end
  end

  def handle_event("cancel_new_condition", params, socket) do
    resource_id = params["resource-id"] || params["resource_id"]
    resource_id = ensure_integer(resource_id)

    {:noreply,
     assign(
       socket,
       new_condition_names: Map.delete(socket.assigns.new_condition_names, resource_id),
       open_new_condition_forms:
         MapSet.delete(socket.assigns.open_new_condition_forms, resource_id)
     )}
  end

  def handle_event(
        "keyboard_reorder_option",
        params,
        socket
      ) do
    case ReorderableList.keyboard_move(params) do
      {:move, _source_index, drop_index} ->
        handle_event(
          "reorder_option",
          %{
            "resourceId" => params["resource-id"] || params["resource_id"],
            "optionId" => params["option-id"] || params["option_id"],
            "dropIndex" => drop_index
          },
          socket
        )

      :noop ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "reorder_option",
        %{"resourceId" => resource_id, "optionId" => option_id, "dropIndex" => drop_index},
        socket
      ) do
    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns

    case AlternativesOptionEditor.move_to(
           project.slug,
           ctx.author,
           decision_points,
           resource_id,
           option_id,
           drop_index
         ) do
      {:ok, decision_points, _group} ->
        {:noreply,
         socket
         |> assign(decision_points: decision_points)
         |> assign_authoring_experiments()}

      {:ok, :unchanged} ->
        {:noreply, socket}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_delete_decision_point_modal",
        %{"resource-id" => resource_id},
        socket
      ) do
    %{project: project, decision_points: decision_points} = socket.assigns
    resource_id = ensure_integer(resource_id)
    publication_id = Publishing.get_unpublished_publication_id!(project.id)

    with [] <- Publishing.find_alternatives_group_references_in_pages(resource_id, publication_id),
         {:ok, false} <-
           ABExperiments.decision_point_in_use?(resource_id, authoring_scope(socket)) do
      decision_point = find_group(decision_points, resource_id)

      modal = %{
        id: "delete_decision_point_modal",
        title: "Delete Decision Point",
        message: "Are you sure you want to delete this decision point?",
        item_name: decision_point.title,
        on_delete: "delete_decision_point",
        values: %{resource_id: resource_id}
      }

      {:noreply, assign(socket, decision_point_delete_modal: modal)}
    else
      [_ | _] ->
        show_error(
          socket,
          "This decision point cannot be deleted because it is used by project content."
        )

      {:ok, true} ->
        show_error(
          socket,
          "This decision point cannot be deleted because it is used by an active experiment"
        )

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event("delete_decision_point", params, socket) do
    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns
    resource_id = params["resource-id"] || params["resource_id"]
    resource_id = ensure_integer(resource_id)
    publication_id = Publishing.get_unpublished_publication_id!(project.id)

    with [] <- Publishing.find_alternatives_group_references_in_pages(resource_id, publication_id),
         {:ok, false} <-
           ABExperiments.decision_point_in_use?(resource_id, authoring_scope(socket)),
         {:ok, deleted} <- ResourceEditor.delete(project.slug, resource_id, ctx.author) do
      Subscriber.unsubscribe_to_new_revisions_in_project(resource_id, project.slug)

      {:noreply,
       socket
       |> assign(
         decision_point_delete_modal: nil,
         decision_points: Enum.reject(decision_points, &(&1.resource_id == deleted.resource_id)),
         decision_point_subscriptions:
           Enum.reject(socket.assigns.decision_point_subscriptions, &(&1 == resource_id))
       )
       |> assign_authoring_experiments()}
    else
      [_ | _] ->
        show_error(
          socket,
          "This decision point cannot be deleted because it is used by project content."
        )

      {:ok, true} ->
        show_error(
          socket,
          "This decision point cannot be deleted because it is used by an active experiment"
        )

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_edit_group_modal",
        %{"resource-id" => resource_id},
        socket
      ) do
    resource_id = ensure_integer(resource_id)

    decision_point = find_group(socket.assigns.decision_points, resource_id)

    modal = %{
      id: "edit_modal",
      title: "Edit Decision Point",
      submit_label: "Save",
      on_submit: "edit_group",
      form: to_form(%{}, as: :params),
      field_name: "title",
      field_label: "Title",
      field_value: decision_point.title,
      placeholder: "Enter a title",
      hidden_fields: [
        {"id", decision_point.id},
        {"resource_id", decision_point.resource_id}
      ]
    }

    {:noreply, assign(socket, decision_point_modal: modal)}
  end

  def handle_event("delete_option", params, socket) do
    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns
    resource_id = params["resource-id"] || params["resource_id"]
    option_id = params["option-id"] || params["option_id"]
    resource_id = ensure_integer(resource_id)
    %{content: %{"options" => options} = content} = find_group(decision_points, resource_id)

    new_options = Enum.filter(options, fn o -> o["id"] != option_id end)

    case edit_group_options(
           project.slug,
           ctx.author,
           decision_points,
           resource_id,
           content,
           new_options
         ) do
      {:ok, decision_points, _group} ->
        {:noreply,
         assign(socket,
           decision_point_delete_modal: nil,
           decision_points: decision_points
         )
         |> assign_authoring_experiments()}

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
    resource_id = ensure_integer(resource_id)
    decision_point = find_group(socket.assigns.decision_points, resource_id)
    option = Enum.find(decision_point.content["options"], fn o -> o["id"] === option_id end)

    modal = %{
      id: "delete_condition_modal",
      title: "Delete Condition",
      message: "Are you sure you want to delete this condition?",
      item_name: option["name"],
      on_delete: "delete_option",
      values: %{resource_id: resource_id, option_id: option_id}
    }

    {:noreply, assign(socket, decision_point_delete_modal: modal)}
  end

  def handle_event("close_decision_point_delete_modal", _params, socket) do
    {:noreply, assign(socket, decision_point_delete_modal: nil)}
  end

  def handle_event(
        "edit_group",
        %{"params" => %{"resource_id" => resource_id, "title" => title}},
        socket
      ) do
    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns

    case edit_group_title(
           project.slug,
           ctx.author,
           decision_points,
           ensure_integer(resource_id),
           title
         ) do
      {:ok, decision_points, _group} ->
        {:noreply,
         assign(socket,
           decision_point_modal: nil,
           decision_points: decision_points
         )
         |> assign_authoring_experiments()}

      {:error, message: error_message} ->
        show_error(socket, error_message)

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_edit_option_modal",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    resource_id = ensure_integer(resource_id)
    option = find_group_option(socket.assigns.decision_points, resource_id, option_id)

    modal = %{
      id: "edit_modal",
      title: "Edit Condition",
      submit_label: "Save",
      on_submit: "edit_option",
      form: to_form(%{}, as: :params),
      field_name: "name",
      field_label: "Name",
      field_value: option["name"],
      placeholder: "Enter a name",
      hidden_fields: [
        {"id", option["id"]},
        {"resource_id", resource_id}
      ]
    }

    {:noreply, assign(socket, decision_point_modal: modal)}
  end

  def handle_event("close_decision_point_modal", _params, socket) do
    {:noreply, assign(socket, decision_point_modal: nil)}
  end

  def handle_event(
        "edit_option",
        %{"params" => %{"resource_id" => resource_id, "id" => option_id, "name" => name}},
        socket
      ) do
    resource_id = ensure_integer(resource_id)

    %{content: %{"options" => options} = content} =
      find_group(socket.assigns.decision_points, resource_id)

    updated_options =
      Enum.map(options, fn o ->
        if o["id"] == option_id do
          %{o | "name" => name}
        else
          o
        end
      end)

    %{project: project, ctx: ctx, decision_points: decision_points} = socket.assigns

    case edit_group_options(
           project.slug,
           ctx.author,
           decision_points,
           resource_id,
           content,
           updated_options
         ) do
      {:ok, decision_points, _group} ->
        {:noreply,
         assign(socket, decision_point_modal: nil)
         |> assign(decision_points: decision_points)
         |> assign_authoring_experiments()}

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

  @impl Phoenix.LiveView
  def handle_info({:updated, revision, _project_slug}, socket) do
    decision_points =
      Enum.map(socket.assigns.decision_points, fn decision_point ->
        if decision_point.resource_id == revision.resource_id,
          do: revision,
          else: decision_point
      end)

    {:noreply,
     socket
     |> assign(decision_points: decision_points)
     |> assign_authoring_experiments()}
  end

  def handle_info({:new_resource, revision, project_slug}, socket) do
    case revision.content["strategy"] do
      strategy when strategy in ["experiment_controlled", "upgrade_decision_point"] ->
        unless revision.resource_id in socket.assigns.decision_point_subscriptions do
          Subscriber.subscribe_to_new_revisions_in_project(revision.resource_id, project_slug)
        end

        decision_points =
          case Enum.any?(
                 socket.assigns.decision_points,
                 &(&1.resource_id == revision.resource_id)
               ) do
            true -> socket.assigns.decision_points
            false -> sort_decision_points([revision | socket.assigns.decision_points])
          end

        {:noreply,
         socket
         |> assign(
           decision_points: decision_points,
           decision_point_subscriptions:
             Enum.uniq([revision.resource_id | socket.assigns.decision_point_subscriptions])
         )
         |> assign_authoring_experiments()}

      _other_strategy ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def terminate(_reason, socket) do
    if connected?(socket) do
      Subscriber.unsubscribe_to_new_resources_of_type(
        @alternatives_type_id,
        socket.assigns.project.slug
      )

      Enum.each(
        socket.assigns.decision_point_subscriptions,
        &Subscriber.unsubscribe_to_new_revisions_in_project(&1, socket.assigns.project.slug)
      )
    end

    :ok
  end

  attr :group, :any, required: true
  attr :name, :string, required: true

  defp new_condition_form(assigns) do
    ~H"""
    <form
      id={"new-condition-form-#{@group.resource_id}"}
      class="mt-3"
      phx-change="change_new_condition"
      phx-submit="create_new_condition"
    >
      <input type="hidden" name="condition[resource_id]" value={@group.resource_id} />
      <label
        class="form-label"
        for={"new-condition-input-#{@group.resource_id}"}
      >
        Condition name
      </label>
      <input
        id={"new-condition-input-#{@group.resource_id}"}
        type="text"
        name="condition[name]"
        value={@name}
        class="form-control"
        placeholder="Enter a new condition"
        phx-hook="InputAutoSelect"
        phx-keydown={JS.push("cancel_new_condition", value: %{resource_id: @group.resource_id})}
        phx-key="Escape"
      />
      <div class="d-flex justify-content-end gap-2 mt-2">
        <button
          type="button"
          class="btn btn-link"
          phx-click="cancel_new_condition"
          phx-value-resource-id={@group.resource_id}
        >
          Cancel
        </button>
        <button
          type="submit"
          class="btn btn-primary"
          disabled={String.trim(@name) == ""}
        >
          Create
        </button>
      </div>
    </form>
    """
  end

  defp assign_decision_points(socket) do
    %{project: project, ctx: ctx} = socket.assigns

    decision_points =
      case ResourceEditor.list(project.slug, ctx.author, @alternatives_type_id) do
        {:ok, alternatives} ->
          alternatives
          |> Enum.filter(
            &(&1.content["strategy"] in ["experiment_controlled", "upgrade_decision_point"])
          )
          |> sort_decision_points()

        _error ->
          []
      end

    assign(socket,
      decision_points: decision_points,
      decision_point_subscriptions: [],
      new_condition_names: %{},
      open_new_condition_forms: MapSet.new(),
      decision_point_modal: nil,
      decision_point_delete_modal: nil
    )
  end

  defp subscribe_to_decision_points(socket) do
    if connected?(socket) do
      resource_ids = Enum.map(socket.assigns.decision_points, & &1.resource_id)

      Enum.each(
        resource_ids,
        &Subscriber.subscribe_to_new_revisions_in_project(&1, socket.assigns.project.slug)
      )

      Subscriber.subscribe_to_new_resources_of_type(
        @alternatives_type_id,
        socket.assigns.project.slug
      )

      assign(socket, decision_point_subscriptions: resource_ids)
    else
      socket
    end
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
      eligible_sections: Map.get(socket.assigns, :eligible_sections, []),
      eligible_sections_status: Map.get(socket.assigns, :eligible_sections_status, :loading),
      section_participation: nil,
      section_participation_read_only: false
    )
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
         {:ok, section_ids} <- parse_section_ids(params["section_ids"]),
         [option_a, option_b | _rest] <- candidate.options do
      weight_a = 1.0
      weight_b = 1.0
      policy_fields = default_policy_fields(algorithm)

      {:ok,
       %CreateExperimentRequest{
         scope: scope,
         slug: params["slug"],
         name: params["name"],
         algorithm: algorithm,
         section_ids: section_ids,
         conditions: [
           %{
             client_ref: "condition-a",
             label: Map.get(candidate.option_labels, option_a, option_a),
             weight: weight_a,
             active: true,
             position: 0
           },
           %{
             client_ref: "condition-b",
             label: Map.get(candidate.option_labels, option_b, option_b),
             weight: weight_b,
             active: true,
             position: 1
           }
         ],
         decision_points: [
           %{
             alternatives_resource_id: candidate.alternatives_resource_id,
             decision_point_key: candidate.decision_point_key,
             title: candidate.title,
             algorithm: algorithm,
             prior_alpha: policy_fields.prior_alpha,
             prior_beta: policy_fields.prior_beta,
             warm_up_assignments: policy_fields.warm_up_assignments,
             max_condition_share: policy_fields.max_condition_share,
             fixed_control_allocation: policy_fields.fixed_control_allocation,
             imbalance_threshold: policy_fields.imbalance_threshold,
             reward_source: policy_fields.reward_source,
             mappings: [
               %{
                 condition_ref: "condition-a",
                 option_id: option_a,
                 weight: weight_a,
                 position: 0
               },
               %{condition_ref: "condition-b", option_id: option_b, weight: weight_b, position: 1}
             ],
             interventions: []
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

  defp default_policy_fields(algorithm) do
    config = ThompsonSampling.default_policy_config()

    %{
      prior_alpha: get_in(config, ["priors", "default", "alpha"]),
      prior_beta: get_in(config, ["priors", "default", "beta"]),
      warm_up_assignments: get_in(config, ["guardrails", "warm_up_assignments"]),
      max_condition_share: get_in(config, ["guardrails", "max_condition_share"]),
      fixed_control_allocation: get_in(config, ["guardrails", "fixed_control_allocation"]),
      imbalance_threshold: get_in(config, ["guardrails", "imbalance_threshold"]),
      reward_source:
        if(algorithm == :thompson_sampling,
          do: config["reward_source"],
          else: "assessment_page:normalized_score"
        )
    }
  end

  defp field_errors_for_message(_message), do: %{}

  defp field_errors_for_experiment_error(%{type: type, details: %{errors: errors}} = error) do
    case {type, Map.get(errors, :slug)} do
      {:conflict, messages} when is_list(messages) ->
        %{slug: "An experiment with this slug already exists in this project."}

      {_type, [message | _rest]} ->
        %{slug: "Slug #{message}."}

      _ ->
        field_errors_for_message(error.message)
    end
  end

  defp field_errors_for_experiment_error(error), do: field_errors_for_message(error.message)

  defp experiment_error_message(_error, %{slug: _message}), do: nil
  defp experiment_error_message(error, _field_errors), do: error.message

  defp field_error(errors, field), do: Map.get(errors, field)
  defp field_invalid?(errors, field), do: Map.has_key?(errors, field)

  defp field_error_class(errors, field),
    do: if(field_invalid?(errors, field), do: "is-invalid", else: "")

  defp field_error_id(errors, field) do
    case field_invalid?(errors, field) do
      true -> "experiment_#{field}_error"
      false -> nil
    end
  end

  defp format_state(state) do
    state
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_algorithm(:weighted_random), do: "Weighted random"
  defp format_algorithm(:thompson_sampling), do: "Thompson Sampling"

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

  defp find_group(decision_points, resource_id) do
    Enum.find(decision_points, &(&1.resource_id == resource_id))
  end

  defp sort_decision_points(decision_points) do
    decision_points
    |> Repo.preload(:resource)
    |> Enum.sort_by(
      fn decision_point ->
        {DateTime.to_unix(decision_point.resource.inserted_at, :microsecond),
         decision_point.resource_id}
      end,
      :asc
    )
  end

  defp find_group_option(decision_points, resource_id, option_id) do
    decision_points
    |> find_group(resource_id)
    |> then(&Enum.find(&1.content["options"], fn option -> option["id"] == option_id end))
  end

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
    {:noreply,
     socket
     |> assign(decision_point_modal: nil, decision_point_delete_modal: nil)
     |> put_flash(:error, message)}
  end
end
