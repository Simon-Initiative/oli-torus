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

  @max_poster_image_size 5_000_000
  @default_poster_image "/images/course_default.jpg"

  @max_intro_video_size 50_000_000

  def mount(socket) do
    {:ok,
     socket
     |> assign(step: :general)
     |> assign(
       max_upload_size: %{
         poster_image: trunc(@max_poster_image_size / 1_000_000),
         intro_video: trunc(@max_intro_video_size / 1_000_000)
       }
     )
     |> assign(uploaded_files: [])
     |> assign(default_poster_image: @default_poster_image)
     |> allow_upload(:poster_image,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       auto_upload: true,
       max_file_size: @max_poster_image_size
     )
     |> allow_upload(:intro_video,
       accept: ~w(video/*),
       max_entries: 1,
       auto_upload: true,
       max_file_size: @max_intro_video_size
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

  def render(%{step: step} = assigns) when step in [:poster_image, :intro_video] do
    ~H"""
    <div>
      <div
        id="options-modal-uploader-trigger"
        data-auto_open_uploader={JS.dispatch("click", to: "##{@uploads[@step].ref}")}
      >
      </div>
      <h2 class="text-lg mb-6">
        <span :if={@resource_urls != []}>
          <%= "Select #{humanize_and_pluralize_atom(@step)} or" %>
        </span>
        <a
          href="#"
          phx-click={
            JS.dispatch("click", to: "##{@uploads[@step].ref}")
            |> JS.push("cancel_not_consumed_uploads")
          }
          phx-target={@myself}
        >
          <%= if @resource_urls != [],
            do: "upload a new one",
            else: "Upload #{humanize_and_pluralize_atom(@step)}" %>
        </a>
        <span class="text-xs text-gray-500">(max size: <%= @max_upload_size[@step] %> MB)</span>
      </h2>
      <div
        id="s3_uploaded_resources"
        class="grid grid-cols-4 gap-4 gap-y-10 p-6 max-h-[65vh] overflow-y-scroll"
        phx-drop-target={@uploads[@step].ref}
      >
        <article
          :for={entry <- @uploads[@step].entries}
          :if={entry.valid?}
          class="relative hover:scale-[1.02]"
        >
          <figure>
            <.live_img_preview
              :if={@step == :poster_image}
              entry={entry}
              class={[
                "object-cover h-[162px] w-[288px] mx-auto rounded-lg cursor-pointer outline outline-1 outline-gray-200 shadow-lg",
                if(fetch_field(@changeset, @step) == "uploaded_one",
                  do: "!outline-[7px] outline-blue-400"
                )
              ]}
              phx-click="select-resource"
              phx-value-url="uploaded_one"
              phx-target={@myself}
            />

            <div
              :if={@step == :intro_video}
              phx-hook="VideoPreview"
              ref={entry.ref}
              id={"video_preview_#{entry.ref}"}
              name={@step}
            >
              <video
                class={[
                  "object-cover h-[162px] w-[288px] mx-auto rounded-lg cursor-pointer outline outline-1 outline-gray-200 shadow-lg",
                  if(fetch_field(@changeset, @step) == "uploaded_one",
                    do: "!outline-[7px] outline-blue-400"
                  )
                ]}
                phx-click="select-resource"
                phx-value-url="uploaded_one"
                phx-target={@myself}
                preload="metadata"
                controls
              >
                <source />
              </video>
            </div>
          </figure>

          <button
            type="button"
            phx-click="cancel-upload"
            phx-value-ref={entry.ref}
            aria-label="cancel"
            class="absolute flex justify-center items-center h-6 w-6 -top-3 -left-3 p-2 bg-gray-300 rounded-full shadow-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-opacity-50"
            phx-target={@myself}
          >
            <span>&times;</span>
          </button>
        </article>
        <img
          :for={url <- @resource_urls}
          :if={@step == :poster_image}
          src={url}
          phx-click="select-resource"
          phx-value-url={url}
          phx-target={@myself}
          data-filename={get_filename(url)}
          class={[
            "object-cover h-[162px] w-[288px] mx-auto rounded-lg cursor-pointer outline outline-1 outline-gray-200 shadow-lg hover:scale-[1.02]",
            if(get_filename(url) == get_filename(fetch_field(@changeset, @step)),
              do: "!outline-[7px] outline-blue-400"
            )
          ]}
        />

        <video
          :for={url <- @resource_urls}
          :if={@step == :intro_video}
          id={"video_#{url}"}
          phx-click="select-resource"
          phx-value-url={url}
          phx-target={@myself}
          data-filename={get_filename(url)}
          class={[
            "object-cover h-[162px] w-[288px] mx-auto rounded-lg cursor-pointer outline outline-1 outline-gray-200 shadow-lg hover:scale-[1.02]",
            if(get_filename(url) == get_filename(fetch_field(@changeset, @step)),
              do: "!outline-[7px] outline-blue-400"
            )
          ]}
          phx-hook="PauseOthersOnSelected"
          preload="metadata"
          controls
          data-filename={get_filename(url)}
        >
          <source src={"#{url}"} type="video/mp4" /> Your browser does not support the video tag.
        </video>
      </div>

      <div class="modal-footer">
        <form
          id="upload-form"
          action="#"
          phx-change="validate-upload"
          phx-target={@myself}
          phx-submit="consume-uploaded"
        >
          <div class="hidden">
            <.live_file_input upload={@uploads[@step]} />
          </div>
          <div :if={fetch_field(@changeset, @step) == "uploaded_one"}>
            <%= for entry <- @uploads[@step].entries do %>
              <progress :if={entry.valid? and entry.progress != 100} value={entry.progress} max="100">
                <%= entry.progress %>%
              </progress>
              <%= for err <- upload_errors(@uploads[@step], entry) do %>
                <p class="alert alert-danger"><%= error_to_string(err, @step) %></p>
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
            if fetch_field(@changeset, @step) == "uploaded_one",
              do: JS.push("consume-uploaded") |> JS.push("change_step"),
              else: "change_step"
          }
          phx-value-target_step="general"
          phx-value-action="save"
          phx-target={@myself}
          disabled={
            !can_submit_resource_selection?(
              fetch_field(@changeset, @step),
              @uploads[@step].entries
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
              delete_button_enabled={
                fetch_field(@changeset, :poster_image) not in [nil, @default_poster_image]
              }
            />
            <.intro_video_selection
              target={@myself}
              intro_video={fetch_field(@changeset, :intro_video)}
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
            delete_button_enabled={
              fetch_field(@changeset, :poster_image) not in [nil, @default_poster_image]
            }
          />
          <.intro_video_selection
            target={@myself}
            intro_video={fetch_field(@changeset, :intro_video)}
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
  attr :delete_button_enabled, :boolean, default: false

  def poster_image_selection(assigns) do
    ~H"""
    <div class="form-group flex flex-col gap-2">
      <label>Poster image</label>
      <.input type="hidden" name="revision[poster_image]" value={@poster_image} />
      <div class="relative mx-auto">
        <button
          :if={@delete_button_enabled}
          type="button"
          phx-click="clear-resource"
          phx-value-resource_name="poster_image"
          aria-label="remove"
          class="absolute cursor-pointer flex justify-center items-center h-6 w-6 -top-3 -left-3 p-2 bg-gray-300 hover:scale-105 hover:bg-gray-400 rounded-full shadow-md focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-opacity-50"
          phx-target={@target}
        >
          <span>&times;</span>
        </button>
        <img
          src={@poster_image}
          class="object-cover h-[162px] w-[288px] mx-auto rounded-lg outline outline-1 outline-gray-200 shadow-lg"
          role="poster_image"
          data-filename={get_filename(@poster_image)}
        />
      </div>
      <button
        type="button"
        class="btn btn-primary mx-auto mt-2"
        phx-click="change_step"
        phx-value-target_step="poster_image"
        phx-target={@target}
      >
        Select
      </button>
    </div>
    """
  end

  attr :intro_video, :string
  attr :target, :map

  def intro_video_selection(%{intro_video: nil} = assigns) do
    ~H"""
    <div class="form-group flex flex-col gap-2">
      <label>Intro video</label>
      <.input type="hidden" name="revision[intro_video]" value={@intro_video} />
      <div
        class="flex items-center justify-center h-[162px] w-[288px] mx-auto rounded-lg border-[3px] border-dashed border-gray-300 cursor-pointer"
        data-filename={get_filename(@intro_video)}
        phx-click={JS.dispatch("click", to: "#select_intro_video_button")}
      >
        <i class="fa-solid fa-circle-plus scale-[200%] text-gray-400"></i>
      </div>
      <button
        id="select_intro_video_button"
        type="button"
        class="btn btn-primary mx-auto mt-2"
        phx-click="change_step"
        phx-value-target_step="intro_video"
        phx-target={@target}
      >
        Select
      </button>
    </div>
    """
  end

  def intro_video_selection(assigns) do
    ~H"""
    <div class="form-group flex flex-col gap-2">
      <label>Intro video</label>
      <.input type="hidden" name="revision[intro_video]" value={@intro_video} />
      <div class="relative mx-auto">
        <button
          type="button"
          phx-click="clear-resource"
          phx-value-resource_name="intro_video"
          aria-label="remove"
          class="absolute cursor-pointer flex justify-center items-center h-6 w-6 -top-3 -left-3 p-2 bg-gray-300 hover:scale-105 hover:bg-gray-400 rounded-full shadow-md focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-opacity-50"
          phx-target={@target}
        >
          <span>&times;</span>
        </button>

        <video
          class="object-cover h-[162px] w-[288px] mx-auto rounded-lg outline outline-1 outline-gray-200 shadow-lg"
          preload="metadata"
          controls
          data-filename={get_filename(@intro_video)}
        >
          <source src={"#{@intro_video}"} type="video/mp4" />
          Your browser does not support the video tag.
        </video>
      </div>
      <button
        id="select_intro_video_button"
        type="button"
        class="btn btn-primary mx-auto mt-2"
        phx-click="change_step"
        phx-value-target_step="intro_video"
        phx-target={@target}
      >
        Select
      </button>
    </div>
    """
  end

  def handle_event("change_step", %{"target_step" => target_step}, socket)
      when target_step in ["poster_image", "intro_video"] do
    resource_name = String.to_existing_atom(target_step)

    {:ok, resource_urls} =
      list_resource_urls(socket.assigns.project.slug, resource_name)
      |> list_selected_resource_first(fetch_field(socket.assigns.changeset, resource_name))

    socket =
      socket
      |> maybe_cancel_not_consumed_uploads(resource_name)
      |> assign(
        step: resource_name,
        resource_urls: resource_urls
      )

    if resource_urls == [] do
      # if there are no resources, we open the uploader automatically to reduce the amount of user interactions
      {:noreply,
       socket
       |> push_event("js-exec", %{
         to: "#options-modal-uploader-trigger",
         attr: "data-auto_open_uploader"
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_not_consumed_uploads", _params, socket) do
    {:noreply, maybe_cancel_not_consumed_uploads(socket, socket.assigns.step)}
  end

  def handle_event("change_step", %{"target_step" => "general", "action" => "cancel"}, socket) do
    %{changeset: changeset, step: step} = socket.assigns

    changeset =
      changeset
      |> Ecto.Changeset.delete_change(step)

    {:noreply,
     socket
     |> maybe_cancel_not_consumed_uploads(step)
     |> assign(step: :general, changeset: changeset)}
  end

  def handle_event("change_step", %{"target_step" => "general", "action" => "save"}, socket) do
    {:noreply, assign(socket, step: :general)}
  end

  def handle_event("select-resource", %{"url" => url}, socket) do
    changeset = Ecto.Changeset.put_change(socket.assigns.changeset, socket.assigns.step, url)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("validate-upload", _params, socket) do
    changeset =
      Ecto.Changeset.put_change(socket.assigns.changeset, socket.assigns.step, "uploaded_one")

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    changeset = Ecto.Changeset.delete_change(socket.assigns.changeset, socket.assigns.step)

    {:noreply, cancel_upload(socket, socket.assigns.step, ref) |> assign(changeset: changeset)}
  end

  def handle_event("consume-uploaded", _params, socket) do
    %{step: step, project: project, changeset: changeset} = socket.assigns

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    uploaded_files =
      consume_uploaded_entries(socket, step, fn %{path: temp_file_path}, entry ->
        resource_file_name = "#{entry.uuid}.#{ext(entry)}"

        upload_path =
          resource_path(project.slug, step) <> "/#{resource_file_name}"

        S3Storage.upload_file(bucket_name, upload_path, temp_file_path)
      end)

    changeset =
      Ecto.Changeset.put_change(changeset, step, hd(uploaded_files))

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("clear-resource", %{"resource_name" => resource_name}, socket) do
    changeset =
      Ecto.Changeset.put_change(
        socket.assigns.changeset,
        String.to_existing_atom(resource_name),
        nil
      )

    {:noreply, assign(socket, changeset: changeset)}
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

  defp can_submit_resource_selection?(nil, _uploaded_entries), do: false

  defp can_submit_resource_selection?(selected_resource, _uploaded_entries)
       when selected_resource != "uploaded_one",
       do: true

  defp can_submit_resource_selection?(
         "uploaded_one",
         [%{progress: 100, valid?: true} | _other_entries] = _uploaded_entries
       ),
       do: true

  defp can_submit_resource_selection?(
         "uploaded_one",
         _uploaded_entries
       ),
       do: false

  defp error_to_string(:too_large, resource_name),
    do: "The uploaded #{humanize_atom(resource_name)} is too large"

  defp error_to_string(:too_many_files, _resource_name), do: "You have selected too many files"

  defp error_to_string(:not_accepted, _resource_name),
    do: "You have selected an unacceptable file type"

  defp list_resource_urls(project_slug, resource_name) do
    resource_path(project_slug, resource_name)
    |> S3Storage.list_file_urls()
  end

  defp list_selected_resource_first({:ok, resource}, selected_resource) do
    case Enum.find(resource, &(get_filename(&1) == get_filename(selected_resource))) do
      nil ->
        {:ok, resource}

      selected_resource ->
        {:ok,
         [selected_resource] ++
           Enum.reject(resource, &(get_filename(&1) == get_filename(selected_resource)))}
    end
  end

  defp list_selected_resource_first(error, _selected_resource), do: error

  defp resource_path(project_slug, resource_name),
    do: Path.join([Atom.to_string(resource_name) <> "s", project_slug]) |> IO.inspect()

  defp maybe_cancel_not_consumed_uploads(socket, allow_upload_name) do
    # we need to cancel any residual not consumed resource between step navigations
    # in order to allow the user to upload a new resource.
    for entry <- socket.assigns.uploads[allow_upload_name].entries do
      cancel_upload(socket, allow_upload_name, entry.ref)
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

  defp get_filename(nil), do: nil

  defp get_filename(url) do
    url
    |> String.split("/")
    |> List.last()
  end

  defp humanize_and_pluralize_atom(:intro_video), do: "an #{humanize_atom(:intro_video)}"
  defp humanize_and_pluralize_atom(atom), do: "a #{humanize_atom(atom)}"

  defp humanize_atom(atom), do: Phoenix.Naming.humanize(atom) |> String.downcase()
end
