defmodule OliWeb.Curriculum.OptionsModalContent do
  use OliWeb, :live_component

  import OliWeb.Curriculum.Utils

  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.ExplanationStrategy
  alias Oli.Utils.S3Storage
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

  @max_file_size 5_000_000
  @default_poster_image "/images/course_default.jpg"

  def mount(socket) do
    {:ok,
     socket
     |> assign(step: :general)
     |> assign(max_size: trunc(@max_file_size / 1_000_000))
     |> assign(uploaded_files: [])
     |> assign(default_poster_image: @default_poster_image)
     |> allow_upload(:poster_image,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       auto_upload: true,
       max_file_size: @max_file_size
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
      <h2 class="text-lg mb-6">
        <span :if={@poster_image_urls != []}>Select a poster image or</span>
        <a href="#" phx-click={JS.dispatch("click", to: "##{@uploads.poster_image.ref}")}>
          <%= if @poster_image_urls != [], do: "upload a new one", else: "Upload a poster image" %>
        </a>
        <span class="text-xs text-gray-500">(max size: <%= @max_size %> MB)</span>
      </h2>
      <div
        id="s3_uploaded_images"
        class="grid grid-cols-4 gap-4 gap-y-10 p-6 max-h-[65vh] overflow-y-scroll"
        phx-drop-target={@uploads.poster_image.ref}
      >
        <article
          :for={entry <- @uploads.poster_image.entries}
          :if={entry.valid?}
          class="relative hover:scale-[1.02]"
        >
          <figure>
            <.live_img_preview
              entry={entry}
              class={[
                "object-cover h-[162px] w-[288px] mx-auto rounded-lg cursor-pointer outline outline-1 outline-gray-200 shadow-lg",
                if(fetch_field(@changeset, :poster_image) == "uploaded_one",
                  do: "!outline-[7px] outline-blue-400"
                )
              ]}
              phx-click="select-poster-image"
              phx-value-url="uploaded_one"
              phx-target={@myself}
            />
          </figure>

          <button
            type="button"
            phx-click="cancel-upload"
            phx-value-ref={entry.ref}
            aria-label="cancel"
            class="absolute flex justify-center items-center h-6 w-6 -top-3 -left-3 p-2 bg-gray-300 rounded-full shadow-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-opacity-50"
            phx-target={@myself}
          >
            <span>&times;</span>
          </button>
        </article>
        <img
          :for={url <- @poster_image_urls}
          src={url}
          phx-click="select-poster-image"
          phx-value-url={url}
          phx-target={@myself}
          class={[
            "object-cover h-[162px] w-[288px] mx-auto rounded-lg cursor-pointer outline outline-1 outline-gray-200 shadow-lg hover:scale-[1.02]",
            if(url == fetch_field(@changeset, :poster_image), do: "!outline-[7px] outline-blue-400")
          ]}
        />
      </div>

      <div class="modal-footer">
        <form id="upload-form" action="#" phx-change="validate-upload" phx-target={@myself}>
          <div class="hidden">
            <.live_file_input upload={@uploads.poster_image} />
          </div>
          <div :if={fetch_field(@changeset, :poster_image) == "uploaded_one"}>
            <%= for entry <- @uploads.poster_image.entries do %>
              <progress :if={entry.valid? and entry.progress != 100} value={entry.progress} max="100">
                <%= entry.progress %>%
              </progress>
              <%= for err <- upload_errors(@uploads.poster_image, entry) do %>
                <p class="alert alert-danger"><%= error_to_string(err) %></p>
              <% end %>
            <% end %>
          </div>
        </form>
        <button
          type="button"
          class="btn btn-secondary"
          phx-click="change_step"
          phx-value-target_step="general"
          phx-value-action="cancel"
          phx-target={@myself}
        >
          Cancel
        </button>
        <button
          type="button"
          phx-disable-with="Selecting..."
          class="btn btn-primary"
          phx-click={
            if fetch_field(@changeset, :poster_image) == "uploaded_one",
              do: JS.push("consume-uploaded") |> JS.push("change_step"),
              else: "change_step"
          }
          phx-value-target_step="general"
          phx-value-action="save"
          phx-target={@myself}
          disabled={
            !can_submit_poster_selection?(
              fetch_field(@changeset, :poster_image),
              @uploads.poster_image.entries
            )
          }
        >
          Select
        </button>
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
        <%= if !is_container?(@revision) do %>
          <div class="flex gap-10">
            <div>
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
            </div>
            <.poster_image_selection
              target={@myself}
              poster_image={fetch_field(@changeset, :poster_image) || @default_poster_image}
            />
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
        <% else %>
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
          <.poster_image_selection
            target={@myself}
            poster_image={fetch_field(@changeset, :poster_image) || @default_poster_image}
          />
        <% end %>

        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" phx-click={@cancel}>Cancel</button>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">Save</button>
        </div>
      </.form>
    </div>
    """
  end

  attr :poster_image, :string
  attr :target, :map

  def poster_image_selection(assigns) do
    ~H"""
    <div class="form-group flex flex-col gap-2">
      <label>Poster image</label>
      <.input type="hidden" name="revision[poster_image]" value={@poster_image} />
      <img
        src={@poster_image}
        class="object-cover h-[162px] w-[288px] mx-auto rounded-lg outline outline-1 outline-gray-200 shadow-lg"
      />
      <button
        type="button"
        class="btn btn-primary mx-auto mt-2"
        phx-click="change_step"
        phx-value-target_step="poster_image_selection"
        phx-target={@target}
      >
        Select
      </button>
    </div>
    """
  end

  def handle_event("change_step", %{"target_step" => "poster_image_selection"}, socket) do
    {:ok, poster_image_urls} =
      list_poster_image_urls(socket.assigns.project.slug)
      |> list_selected_image_first(fetch_field(socket.assigns.changeset, :poster_image))

    {
      :noreply,
      socket
      |> maybe_cancel_not_consumed_uploads()
      |> assign(
        step: :poster_image_selection,
        poster_image_urls: poster_image_urls
      )
    }
  end

  def handle_event("change_step", %{"target_step" => "general", "action" => "cancel"}, socket) do
    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.delete_change(:poster_image)

    {:noreply,
     socket
     |> maybe_cancel_not_consumed_uploads()
     |> assign(step: :general, changeset: changeset)}
  end

  def handle_event("change_step", %{"target_step" => "general", "action" => "save"}, socket) do
    if is_nil(Ecto.Changeset.get_change(socket.assigns.changeset, :poster_image)) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, step: :general)}
    end
  end

  def handle_event("select-poster-image", %{"url" => url}, socket) do
    changeset = Ecto.Changeset.put_change(socket.assigns.changeset, :poster_image, url)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("validate-upload", _params, socket) do
    changeset = Ecto.Changeset.put_change(socket.assigns.changeset, :poster_image, "uploaded_one")

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    changeset = Ecto.Changeset.delete_change(socket.assigns.changeset, :poster_image)

    {:noreply, cancel_upload(socket, :poster_image, ref) |> assign(changeset: changeset)}
  end

  def handle_event("consume-uploaded", _params, socket) do
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    uploaded_files =
      consume_uploaded_entries(socket, :poster_image, fn %{path: temp_file_path}, entry ->
        image_file_name = "#{entry.uuid}.#{ext(entry)}"

        upload_path = poster_images_path(socket.assigns.project.slug) <> "/#{image_file_name}"

        S3Storage.upload_file(bucket_name, upload_path, temp_file_path)
      end)

    changeset =
      Ecto.Changeset.put_change(socket.assigns.changeset, :poster_image, hd(uploaded_files))

    {:noreply, assign(socket, :changeset, changeset)}
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

  defp can_submit_poster_selection?(nil, _uploaded_entries), do: false

  defp can_submit_poster_selection?(selected_poster_image, _uploaded_entries)
       when selected_poster_image != "uploaded_one",
       do: true

  defp can_submit_poster_selection?(
         "uploaded_one",
         [%{progress: 100, valid?: true} | _other_entries] = _uploaded_entries
       ),
       do: true

  defp can_submit_poster_selection?(
         "uploaded_one",
         _uploaded_entries
       ),
       do: false

  defp error_to_string(:too_large), do: "The uploaded image is too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp list_poster_image_urls(project_slug) do
    poster_images_path(project_slug)
    |> S3Storage.list_file_urls()
  end

  defp list_selected_image_first({:ok, images}, selected_image) do
    case Enum.find(images, &(&1 == selected_image)) do
      nil -> {:ok, images}
      selected_image -> {:ok, [selected_image] ++ Enum.reject(images, &(&1 == selected_image))}
    end
  end

  defp list_selected_image_first(error, _selected_image), do: error

  defp poster_images_path(project_slug), do: Path.join(["poster_images", project_slug])

  defp maybe_cancel_not_consumed_uploads(socket) do
    # we need to cancel any residual not consumed image between step navigations
    # in order to allow the user to upload a new image.
    for entry <- socket.assigns.uploads.poster_image.entries do
      cancel_upload(socket, :poster_image, entry.ref)
    end
    |> case do
      [] -> socket
      [socket | _rest] -> socket
    end
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
