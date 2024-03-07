defmodule OliWeb.Curriculum.OptionsModalContent do
  use OliWeb, :live_component

  import OliWeb.Curriculum.Utils

  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.ExplanationStrategy
  alias OliWeb.Components.HierarchySelector

  @attempt_options [
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
    "5": 5,
    "6": 6,
    "7": 7,
    "8": 8,
    "9": 9,
    "10": 10,
    "15": 15,
    "25": 25,
    "50": 50,
    "100": 100,
    Unlimited: 0
  ]

  def mount(socket) do
    {:ok,
     socket
     |> assign(step: :general)
     |> allow_upload(:poster_image,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       auto_upload: true,
       max_file_size: 5_000_000
     )}
  end

  attr(:redirect_url, :string, required: true)
  attr(:revision, :map, required: true)
  attr(:changeset, :map, required: true)
  attr(:project, :map, required: true)
  attr(:project_hierarchy, :map, required: true)
  attr(:validate, :string, required: true)
  attr(:submit, :string, required: true)
  attr(:cancel, :map, required: true)

  attr(:attempt_options, :list, default: @attempt_options)
  attr(:selected_resources, :list, default: [])

  def render(%{step: :poster_image_selection} = assigns) do
    ~H"""
    <div>
      <form
        id="upload-form"
        action="#"
        phx-submit="save-upload"
        phx-change="validate-upload"
        phx-target={@myself}
      >
        <.live_file_input upload={@uploads.poster_image} />
        <%!-- use phx-drop-target with the upload ref to enable file drag and drop --%>
        <section phx-drop-target={@uploads.poster_image.ref}>
          <%!-- render each poster_image entry --%>
          <%= for entry <- @uploads.poster_image.entries do %>
            <article class="upload-entry">
              <figure>
                <.live_img_preview entry={entry} />
                <figcaption><%= entry.client_name %></figcaption>
              </figure>

              <%!-- entry.progress will update automatically for in-flight entries --%>
              <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>

              <%!-- a regular click event whose handler will invoke Phoenix.LiveView.cancel_upload/3 --%>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                aria-label="cancel"
                phx-target={@myself}
              >
                &times;
              </button>

              <%!-- Phoenix.Component.upload_errors/2 returns a list of error atoms --%>
              <%= for err <- upload_errors(@uploads.poster_image, entry) do %>
                <p class="alert alert-danger"><%= error_to_string(err) %></p>
              <% end %>
            </article>
          <% end %>

          <%!-- Phoenix.Component.upload_errors/1 returns a list of error atoms --%>
          <%= for err <- upload_errors(@uploads.poster_image) do %>
            <p class="alert alert-danger"><%= error_to_string(err) %></p>
          <% end %>
        </section>
        <button type="submit">Upload</button>
      </form>

      <div class="modal-footer">
        <button
          type="button"
          class="btn btn-secondary"
          phx-click="change_step"
          phx-value-step="general"
          phx-target={@myself}
        >
          Back/Cancel
        </button>
        <button type="button" phx-disable-with="Selecting..." class="btn btn-primary">Select</button>
      </div>
    </div>
    """
  end

  def render(%{step: :general} = assigns) do
    ~H"""
    <div>
      <.form
        for={@changeset}
        id="revision-settings-form"
        phx-change={@validate}
        phx-submit={@submit}
        action="#"
      >
        <div class="form-group">
          <label for="title">Title</label>
          <.input
            id="title"
            name="revision[title]"
            class="form-control"
            aria-describedby="title_description"
            placeholder="Title"
            value={fetch_field(@changeset, :title)}
          />
          <small id="title_description" class="form-text text-muted">
            The title is used to identify this <%= resource_type_label(@revision) %>.
          </small>
        </div>

        <%= if !is_container?(@revision) do %>
          <div class="form-group">
            <label for="grading_type">Grading Type</label>
            <.input
              type="select"
              name="revision[graded]"
              id="grading_type"
              aria-describedby="grading_type_description"
              placeholder="Grading Type"
              class="form-control custom-select"
              value={fetch_field(@changeset, :graded)}
              options={[{"Graded Assessment", "true"}, {"Ungraded Practice Page", "false"}]}
            />
            <small id="grading_type_description" class="form-text text-muted">
              Graded assessments report a grade to the grade book, while practice pages do not.
            </small>
          </div>

          <div class="form-group">
            <label>Explanation Strategy</label>
            <div class="flex gap-2">
              <.input
                type="select"
                name="revision[explanation_strategy][type]"
                class="form-control custom-select w-full"
                aria-describedby="explanation_strategy_description"
                placeholder="Explanation Strategy"
                value={Map.get(fetch_field(@changeset, :explanation_strategy) || %{}, :type)}
                options={
                  Enum.map(
                    ExplanationStrategy.types(),
                    &{Oli.Utils.snake_case_to_friendly(&1), &1}
                  )
                }
              />
              <%= case Map.get(fetch_field(@changeset, :explanation_strategy) || %{}, :type) do %>
                <% :after_set_num_attempts -> %>
                  <div class="ml-2">
                    <.input
                      name="revision[explanation_strategy][set_num_attempts]"
                      type="number"
                      class="form-control"
                      placeholder="# of Attempts"
                      value={
                        Map.get(
                          fetch_field(@changeset, :explanation_strategy),
                          :set_num_attempts
                        )
                      }
                    />
                  </div>
                <% _ -> %>
              <% end %>
            </div>
            <small id="explanation_strategy_description" class="form-text text-muted">
              Explanation strategy determines how activity explanations will be shown to learners.
            </small>
          </div>

          <div class="form-group">
            <label for="max_attempts">Number of Attempts</label>
            <.input
              type="select"
              id="max_attempts"
              name="revision[max_attempts]"
              aria-describedby="number_of_attempts_description"
              placeholder="Number of Attempts"
              disabled={is_disabled(@changeset, @revision)}
              class="form-control custom-select"
              value={fetch_field(@changeset, :max_attempts) || 0}
              options={@attempt_options}
            />
            <small id="number_of_attempts_description" class="form-text text-muted">
              Graded assessments allow a configurable number of attempts, while practice pages offer unlimited attempts.
            </small>
          </div>

          <div class="form-group">
            <label for="duration_minutes">Suggested Duration (minutes)</label>
            <.input
              id="duration_minutes"
              type="number"
              min="0"
              step="1"
              name="revision[duration_minutes]"
              class="form-control"
              aria-describedby="duration_description"
              value={fetch_field(@changeset, :duration_minutes)}
            />
            <small id="duration_description" class="form-text text-muted">
              A suggested time in minutes that the page should take a student to complete.
            </small>
          </div>

          <div class="form-group">
            <label for="scoring_strategy_id">Scoring Strategy</label>
            <.input
              type="select"
              id="scoring_strategy_id"
              name="revision[scoring_strategy_id]"
              aria-describedby="scoring_strategy_description"
              placeholder="Scoring Strategy"
              disabled={is_disabled(@changeset, @revision)}
              class="form-control custom-select"
              value={fetch_field(@changeset, :scoring_strategy_id)}
              options={
                Enum.map(
                  ScoringStrategy.get_types(),
                  &{Oli.Utils.snake_case_to_friendly(&1[:type]), &1[:id]}
                )
              }
            />
            <small id="scoring_strategy_description" class="form-text text-muted">
              The scoring strategy determines how to calculate the final grade book score across all attempts.
            </small>
          </div>

          <div class="form-group">
            <label for="retake_mode">Retake Mode</label>
            <.input
              type="select"
              id="retake_mode"
              name="revision[retake_mode]"
              aria-describedby="retake_mode_description"
              placeholder="Retake Mode"
              disabled={is_disabled(@changeset, @revision)}
              class="form-control custom-select"
              value={fetch_field(@changeset, :retake_mode)}
              options={[
                {"Normal: Students answer all questions in each attempt", :normal},
                {"Targeted: Students answer only incorrect questions from previous attempts",
                 :targeted}
              ]}
            />
            <small id="retake_mode_description" class="form-text text-muted">
              The retake mode determines how subsequent attempts are presented to students.
            </small>
          </div>

          <div class="form-group">
            <label for="purpose">Purpose</label>
            <.input
              type="select"
              id="purpose"
              name="revision[purpose]"
              placeholder="Purpose"
              class="form-control custom-select"
              value={fetch_field(@changeset, :purpose)}
              options={[
                {"Foundation", :foundation},
                {"Deliberate Practice", :deliberate_practice},
                {"Exploration", :application}
              ]}
            />
          </div>

          <div class="form-group">
            <label>Related Resource</label>
            <%= live_component(HierarchySelector,
              disabled: !@revision.graded && is_foundation(@changeset, @revision),
              field_name: "revision[relates_to][]",
              id: "related-resources-selector",
              items: @project_hierarchy.children,
              initial_values: get_selected_related_resources(@revision, @project_hierarchy)
            ) %>
          </div>
        <% end %>

        <div class="form-group flex flex-col gap-2">
          <label>Poster image</label>
          <img
            :if={@revision.poster_image}
            src={@revision.poster_image}
            class="object-cover h-56 mx-auto"
          />
          <button
            type="button"
            class="btn btn-primary mx-auto"
            phx-click="change_step"
            phx-value-step="poster_image_selection"
            phx-target={@myself}
          >
            Select
          </button>
        </div>

        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" phx-click={@cancel}>Cancel</button>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">Save</button>
        </div>
      </.form>
    </div>
    """
  end

  # TODO si no hay que hacer algo especial en poster, como generar el uploads, unificar estos dos
  def handle_event("change_step", %{"step" => "poster_image_selection"}, socket) do
    {:noreply, assign(socket, step: :poster_image_selection)}
  end

  def handle_event("change_step", %{"step" => "general"}, socket) do
    {:noreply, assign(socket, step: :general)}
  end

  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :poster_image, ref)}
  end

  def handle_event("save-upload", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :poster_image, fn %{path: path}, _entry ->
        dest = Path.join([:code.priv_dir(:oli), "static", "uploads", Path.basename(path)])
        File.cp!(path, dest)
        {:ok, ~p"/uploads/#{Path.basename(dest)}"}
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  defp is_foundation(changeset, revision) do
    if !is_nil(changeset.changes |> Map.get(:purpose)) do
      changeset.changes.purpose == :foundation
    else
      revision.purpose == :foundation
    end
  end

  defp is_disabled(changeset, revision) do
    if !is_nil(changeset.changes[:graded]) do
      !changeset.changes[:graded]
    else
      !revision.graded
    end
  end

  defp get_selected_related_resources(revision, project_hierarchy) do
    related_resources = revision.relates_to
    flatten_project_hierarchy = flatten_project_hierarchy(project_hierarchy)

    Enum.reduce(flatten_project_hierarchy, [], fn {name, id}, acc ->
      if Enum.member?(related_resources, id) do
        [{name, "#{id}"}] ++ acc
      else
        acc
      end
    end)
  end

  defp flatten_project_hierarchy(%{id: id, name: name, children: children}) do
    children
    |> Enum.map(&flatten_project_hierarchy/1)
    |> List.flatten()
    |> Enum.concat([{name, id}])
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
