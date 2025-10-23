defmodule OliWeb.Workspaces.CourseAuthor.AlternativesLive do
  use OliWeb, :live_view
  use Phoenix.HTML
  use OliWeb.Common.Modal

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.Common.Components
  import OliWeb.ErrorHelpers
  import OliWeb.Resources.AlternativesEditor.GroupOption

  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Publishing
  alias Oli.Resources.{ResourceType, Revision}
  alias OliWeb.Common.Modal.{FormModal, DeleteModal}
  alias OliWeb.Resources.AlternativesEditor.PreventDeletionModal

  @alternatives_type_id ResourceType.id_for_alternatives()

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{ctx: ctx, project: project} = socket.assigns

    {:ok, alternatives} =
      ResourceEditor.list(
        project.slug,
        ctx.author,
        @alternatives_type_id
      )

    alternatives =
      Enum.filter(alternatives, fn a -> a.content["strategy"] != "upgrade_decision_point" end)

    subscriptions = subscribe(alternatives, project.slug)

    {:ok,
     assign(socket,
       ctx: ctx,
       project: project,
       author: ctx.author,
       title: "Alternatives | " <> project.title,
       alternatives: Enum.reverse(alternatives),
       subscriptions: subscriptions,
       resource_slug: project.slug,
       resource_title: project.title
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    {render_modal(assigns)}

    <div class="alternatives-groups container p-8">
      <h2>Alternatives</h2>
      <div class="d-flex flex-row">
        <div class="flex-grow-1"></div>
        <button class="btn btn-primary" phx-click="show_create_modal">
          <i class="fa fa-plus"></i> New Alternative
        </button>
      </div>
      <div class="d-flex flex-column my-4">
        <%= if Enum.count(@alternatives) > 0 do %>
          <%= for group <- @alternatives do %>
            <.group group={group} />
          <% end %>
        <% else %>
          <div class="text-center"><em>There are no alternatives groups</em></div>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:editing_enabled, :boolean, default: true)
  attr(:source, :atom, default: :alternatives)
  attr(:group, :any)

  def group(assigns) do
    ~H"""
    <div class="alternatives-group bg-gray-100 dark:bg-neutral-800 dark:border-gray-700 border p-3 my-2">
      <div class="d-flex flex-row align-items-center">
        <div>
          <b>{@group.title}</b>
        </div>
        <div class="flex-grow-1"></div>
        <.icon_button
          :if={@editing_enabled}
          class="mr-1"
          icon="fa-solid fa-pencil"
          on_click="show_edit_group_modal"
          values={["phx-value-resource-id": @group.resource_id]}
        />
        <button
          :if={@source == :alternatives}
          class="btn btn-danger btn-sm mr-2"
          phx-click="show_delete_group_modal"
          phx-value-resource_id={@group.resource_id}
        >
          Delete
        </button>
      </div>
      <div class="mt-3">
        <%= if Enum.count(@group.content["options"]) > 0 do %>
          <ul class="list-group">
            <%= for option <- @group.content["options"] do %>
              <.group_option group={@group} option={option} show_actions={@editing_enabled} />
            <% end %>
          </ul>
        <% else %>
          <div class="my-2">
            <div class="text-center"><em>There are no options in this group</em></div>
          </div>
        <% end %>
        <button
          :if={@editing_enabled}
          class="btn btn-link btn-sm my-2"
          phx-click="show_create_option_modal"
          phx-value-resource_id={@group.resource_id}
        >
          <i class="fa fa-plus"></i> New Option
        </button>
      </div>
    </div>
    """
  end

  def handle_event("show_create_experiment", _, socket) do
    changeset =
      {%{}, %{name: :string}}
      |> Ecto.Changeset.cast(%{}, [:name])

    form_body_fn = fn assigns ->
      ~H"""
      <div class="form-group">
        {text_input(
          @form,
          :name,
          class: "form-control my-2" <> error_class(@form, :name, "is-invalid"),
          placeholder: "Enter the name of the experiment decision point from Upgrade",
          phx_hook: "InputAutoSelect",
          required: true
        )}
      </div>
      """
    end

    modal_assigns = %{
      id: "create_modal",
      title: "Create Experiment Decision Point",
      submit_label: "Create",
      changeset: changeset,
      form_body_fn: form_body_fn,
      on_validate: "validate_group",
      on_submit: "create_experiment"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("show_create_modal", _, socket) do
    changeset =
      {%{}, %{name: :string}}
      |> Ecto.Changeset.cast(%{}, [:name])

    form_body_fn = fn assigns ->
      ~H"""
      <div class="form-group">
        {text_input(
          @form,
          :name,
          class: "form-control my-2" <> error_class(@form, :name, "is-invalid"),
          placeholder: "Enter a name for the alternative",
          phx_hook: "InputAutoSelect",
          required: true
        )}
      </div>
      """
    end

    modal_assigns = %{
      id: "create_modal",
      title: "Create Alternative",
      submit_label: "Create",
      changeset: changeset,
      form_body_fn: form_body_fn,
      on_validate: "validate_group",
      on_submit: "create_group"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("validate_group", %{"params" => %{"name" => _}}, socket) do
    {:noreply, socket}
  end

  def handle_event("create_group", %{"params" => %{"name" => name}}, socket) do
    %{project: project, author: author, alternatives: alternatives} = socket.assigns

    {:ok, group} =
      ResourceEditor.create(
        project.slug,
        author,
        @alternatives_type_id,
        %{title: name, content: %{"options" => [], "strategy" => "user_section_preference"}}
      )

    {:noreply, hide_modal(socket) |> assign(alternatives: [group | alternatives])}
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

  def handle_event("validate_option", %{"params" => %{"name" => _}}, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "create_option",
        %{"params" => %{"id" => option_id, "name" => name, "resource_id" => resource_id}},
        socket
      ) do
    %{project: project, author: author, alternatives: alternatives} = socket.assigns
    resource_id = ensure_integer(resource_id)

    %{content: %{"options" => options} = content} =
      Enum.find(alternatives, fn g -> g.resource_id == resource_id end)

    new_options = [%{"id" => option_id, "name" => name} | options]

    case edit_group_options(
           project.slug,
           author,
           alternatives,
           resource_id,
           content,
           new_options
         ) do
      {:ok, alternatives, _group} ->
        {:noreply, hide_modal(socket) |> assign(alternatives: alternatives)}

      _ ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_delete_group_modal",
        %{"resource_id" => resource_id},
        socket
      ) do
    %{project: project, alternatives: alternatives} = socket.assigns
    resource_id = ensure_integer(resource_id)

    publication_id = Publishing.get_unpublished_publication_id!(project.id)

    case Publishing.find_alternatives_group_references_in_pages(resource_id, publication_id) do
      [] ->
        preview_fn = fn assigns ->
          ~H"""
          <div class="text-center mt-3"><b>{@group.title}</b></div>
          """
        end

        modal_assigns = %{
          id: "delete_modal",
          title: "Delete Group",
          message: "Are you sure you want to delete this alternatives group?",
          preview_fn: preview_fn,
          group: find_group(alternatives, resource_id),
          on_delete: "delete_group",
          phx_values: ["phx-value-resource-id": resource_id]
        }

        modal = fn assigns ->
          ~H"""
          <DeleteModal.modal {@modal_assigns} />
          """
        end

        {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}

      references ->
        modal_assigns = %{
          id: "prevent_deletion_modal",
          references: references,
          project_slug: project.slug
        }

        modal = fn assigns ->
          ~H"""
          <PreventDeletionModal.modal {@modal_assigns} />
          """
        end

        {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
    end
  end

  def handle_event("delete_group", %{"resource-id" => resource_id}, socket) do
    %{project: project, author: author, alternatives: alternatives} = socket.assigns

    {:ok, deleted} = ResourceEditor.delete(project.slug, resource_id, author)

    alternatives = Enum.filter(alternatives, fn r -> r.resource_id != deleted.resource_id end)

    {:noreply,
     socket
     |> hide_modal()
     |> assign(alternatives: alternatives)}
  end

  def handle_event(
        "show_edit_group_modal",
        %{"resource-id" => resource_id},
        socket
      ) do
    %{alternatives: alternatives} = socket.assigns

    resource_id = ensure_integer(resource_id)
    group = find_group(alternatives, resource_id)

    # {%{resource_id: resource_id}, %{id: :string, resource_id: :int, title: :string}}
    # |> Ecto.Changeset.cast(group, [:id, :resource_id, :title])
    changeset = Revision.changeset(group)

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

  def handle_event("validate_group", %{"params" => %{"title" => _}}, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "edit_group",
        %{"params" => %{"resource_id" => resource_id, "title" => title}},
        socket
      ) do
    %{project: project, author: author, alternatives: alternatives} = socket.assigns
    resource_id = ensure_integer(resource_id)

    case edit_group_title(
           project.slug,
           author,
           alternatives,
           resource_id,
           title
         ) do
      {:ok, alternatives, _group} ->
        {:noreply, hide_modal(socket) |> assign(alternatives: alternatives)}

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_edit_option_modal",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    %{alternatives: alternatives} = socket.assigns

    resource_id = ensure_integer(resource_id)
    option = find_group_option(alternatives, resource_id, option_id)

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

  def handle_event(
        "edit_option",
        %{"params" => %{"resource_id" => resource_id, "id" => option_id, "name" => name}},
        socket
      ) do
    %{project: project, author: author, alternatives: alternatives} = socket.assigns
    resource_id = ensure_integer(resource_id)

    %{content: %{"options" => options} = content} =
      Enum.find(alternatives, fn g -> g.resource_id == resource_id end)

    # new_options = Enum.filter(options, fn o -> o["id"] != option_id end)
    updated_options =
      Enum.map(options, fn o ->
        if o["id"] == option_id do
          %{o | "name" => name}
        else
          o
        end
      end)

    case edit_group_options(
           project.slug,
           author,
           alternatives,
           resource_id,
           content,
           updated_options
         ) do
      {:ok, alternatives, _group} ->
        {:noreply, hide_modal(socket) |> assign(alternatives: alternatives)}

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event(
        "show_delete_option_modal",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    %{alternatives: alternatives} = socket.assigns

    resource_id = ensure_integer(resource_id)
    option = find_group_option(alternatives, resource_id, option_id)

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
      group: find_group(alternatives, resource_id),
      option: option,
      on_delete: "delete_option",
      phx_values: ["phx-value-resource-id": resource_id, "phx-value-option-id": option_id]
    }

    modal = fn assigns ->
      ~H"""
      <DeleteModal.modal {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "delete_option",
        %{"resource-id" => resource_id, "option-id" => option_id},
        socket
      ) do
    %{project: project, author: author, alternatives: alternatives} = socket.assigns
    resource_id = ensure_integer(resource_id)

    %{content: %{"options" => options} = content} =
      Enum.find(alternatives, fn g -> g.resource_id == resource_id end)

    new_options = Enum.filter(options, fn o -> o["id"] != option_id end)

    case edit_group_options(
           project.slug,
           author,
           alternatives,
           resource_id,
           content,
           new_options
         ) do
      {:ok, alternatives, _group} ->
        {:noreply, hide_modal(socket) |> assign(alternatives: alternatives)}

      {:error, _} ->
        show_error(socket)
    end
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, hide_modal(socket)}
  end

  @impl Phoenix.LiveView
  def terminate(_reason, socket) do
    %{project: project, subscriptions: subscriptions} = socket.assigns

    unsubscribe(subscriptions, project.slug)
  end

  # spin up subscriptions for the alternatives resources
  defp subscribe(alternatives, project_slug) do
    ids = Enum.map(alternatives, fn p -> p.resource_id end)
    Enum.each(ids, &Subscriber.subscribe_to_new_revisions_in_project(&1, project_slug))

    Subscriber.subscribe_to_new_resources_of_type(
      @alternatives_type_id,
      project_slug
    )

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Subscriber.unsubscribe_to_new_resources_of_type(
      @alternatives_type_id,
      project_slug
    )

    Enum.each(ids, &Subscriber.unsubscribe_to_new_revisions_in_project(&1, project_slug))
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
    case ResourceEditor.edit(project_slug, resource_id, author, %{
           content: %{content | "options" => updated_options}
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

  defp find_group(
         alternatives,
         resource_id
       ) do
    Enum.find(alternatives, fn g ->
      g.resource_id == resource_id
    end)
  end

  defp find_group_option(
         alternatives,
         resource_id,
         option_id
       ) do
    Enum.find_value(alternatives, fn g ->
      if g.resource_id == resource_id do
        Enum.find(g.content["options"], fn o -> o["id"] === option_id end)
      else
        nil
      end
    end)
  end

  defp ensure_integer(i) when is_integer(i), do: i

  defp ensure_integer(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _rem} -> i
      _ -> throw("Invalid integer")
    end
  end

  defp show_error(socket) do
    {:noreply,
     put_flash(socket, :error, "Something went wrong. Please refresh the page and try again.")}
  end
end
