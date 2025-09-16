defmodule OliWeb.Experiments.ExperimentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live}
  use Phoenix.HTML
  use OliWeb.Common.Modal

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.Components.Common
  import OliWeb.ErrorHelpers
  import OliWeb.Resources.AlternativesEditor.GroupOption

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Authoring.Experiments
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision
  alias OliWeb.Common.Modal.DeleteModal
  alias OliWeb.Common.Modal.FormModal
  alias OliWeb.Router.Helpers, as: Routes

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx
  on_mount {OliWeb.LiveSessionPlugs.SetProject, :default}

  @title "Experiments"
  @alternatives_type_id ResourceType.id_for_alternatives()
  @default_error_message "Something went wrong. Please refresh the page and try again."

  def mount(_params, _session, socket) do
    experiment = Experiments.get_latest_experiment(socket.assigns.project.slug)

    socket =
      socket
      |> assign(is_upgrade_enabled: socket.assigns.project.has_experiments)
      |> assign(title: @title)
      |> assign(experiment: experiment)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    {render_modal(assigns)}
    <div class="flex flex-col gap-y-6 ml-8 mt-4">
      <h3>A/B Testing with UpGrade</h3>
      <p>
        To support A/B testing, Torus integrates with the A/B testing platform,
        <a
          class="underline text-inherit decoration-grey-500/30"
          href="https://upgrade.oli.cmu.edu/login"
        >
          UpGrade
        </a>
      </p>
      <.input
        type="checkbox"
        class="form-check-input"
        name="experiments"
        value={@is_upgrade_enabled}
        label="Enable A/B testing with UpGrade"
        phx-click="enable_upgrade"
        checked={@is_upgrade_enabled}
      />

      <%= if @experiment do %>
        <OliWeb.Resources.AlternativesEditor.group
          group={@experiment}
          editing_enabled={@is_upgrade_enabled}
          source={:experiments}
        />
      <% end %>

      <div :if={@is_upgrade_enabled} class="flex gap-4">
        <.button
          class="btn btn-md btn-primary mt-2"
          href={Routes.experiment_path(OliWeb.Endpoint, :segment_download, assigns.project.slug)}
        >
          Download Segment JSON
        </.button>

        <.button
          class="btn btn-md btn-primary mt-2"
          href={Routes.experiment_path(OliWeb.Endpoint, :experiment_download, assigns.project.slug)}
        >
          Download Experiment JSON
        </.button>
      </div>
    </div>
    """
  end

  def handle_event("enable_upgrade", _params, socket) do
    socket =
      case socket.assigns.experiment do
        nil ->
          {:ok, experiment} =
            create_experiment(socket.assigns.project, socket.assigns.current_author)

          {:ok, updated_project = %Project{has_experiments: has_experiments}} =
            Course.update_project(socket.assigns.project, %{has_experiments: true})

          assign(socket,
            experiment: experiment,
            is_upgrade_enabled: has_experiments,
            project: updated_project
          )

        %Revision{} ->
          {:ok, updated_project = %Project{}} =
            Course.update_project(socket.assigns.project, %{
              has_experiments: !socket.assigns.project.has_experiments
            })

          assign(socket,
            is_upgrade_enabled: updated_project.has_experiments,
            project: updated_project
          )
      end

    {:noreply, socket}
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

  defp create_experiment(project, author) do
    initial_opts = [
      %{"id" => uuid(), "name" => "Option 1"},
      %{"id" => uuid(), "name" => "Option 2"}
    ]

    attrs = %{
      title: "Decision Point",
      content: %{"options" => initial_opts, "strategy" => "upgrade_decision_point"}
    }

    ResourceEditor.create(project.slug, author, @alternatives_type_id, attrs)
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
