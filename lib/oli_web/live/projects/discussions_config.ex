defmodule OliWeb.Projects.DiscussionsConfig do
  use Phoenix.LiveComponent

  import OliWeb.Components.Common

  alias Oli.Resources
  alias Oli.Publishing.{AuthoringResolver}
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  def update(assigns, socket) do
    project = assigns.project
    collab_space_config = assigns.collab_space_config
    page_slug = assigns.resource_slug

    page_revision = AuthoringResolver.from_revision_slug(project.slug, page_slug)

    changeset =
      Resources.change_revision(page_revision, %{
        collab_space_config: from_struct(collab_space_config)
      })

    collab_space_status = get_status(collab_space_config)

    {:ok,
     assign(socket,
       author_id: assigns.author.id,
       project: project,
       discussions_enabled: collab_space_status == :enabled,
       form: to_form(changeset),
       collab_space_config: collab_space_config,
       page_revision: page_revision
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <div class="inline-flex py-2 mb-2 border-b dark:border-gray-700">
        <span>Enable Course Discussions</span>
        <.toggle_switch
          class="ml-4"
          checked={@discussions_enabled}
          on_toggle="toggle_discussions"
          phx_target={@myself}
        />
      </div>

      <.form
        id="collab_space_config_form"
        class="w-full"
        for={@form}
        phx-change="save"
        phx-target={@myself}
      >
        <.inputs_for :let={cs} field={@form[:collab_space_config]}>
          <.input type="hidden" field={cs[:status]} />

          <.input type="hidden" field={cs[:threaded]} />
          <.input type="hidden" field={cs[:show_full_history]} />
          <.input type="hidden" field={cs[:participation_min_replies]} value={0} />
          <.input type="hidden" field={cs[:participation_min_posts]} value={0} />

          <.input
            type="checkbox"
            field={cs[:auto_accept]}
            class="form-check-input"
            label="Allow posts to be visible without approval"
          />
          <.input
            type="checkbox"
            field={cs[:anonymous_posting]}
            class="form-check-input"
            label="Allow anonymous posts"
          />
        </.inputs_for>
      </.form>
    </div>
    """
  end

  def handle_event("toggle_discussions", _params, socket) do
    case socket.assigns.discussions_enabled do
      true ->
        upsert_collab_space(
          "disabled",
          Map.merge(from_struct(socket.assigns.collab_space_config), %{status: :disabled}),
          assign(socket, discussions_enabled: false)
        )

      false ->
        upsert_collab_space(
          "enabled",
          Map.merge(from_struct(socket.assigns.collab_space_config), %{status: :enabled}),
          assign(socket, discussions_enabled: true)
        )
    end
  end

  def handle_event("save", %{"revision" => %{"collab_space_config" => attrs}}, socket) do
    upsert_collab_space("updated", attrs, socket)
  end

  defp upsert_collab_space(action, attrs, socket) do
    socket = clear_flash(socket)

    case Collaboration.upsert_collaborative_space(
           attrs,
           socket.assigns.project,
           socket.assigns.page_revision.slug,
           socket.assigns.author_id
         ) do
      {:ok,
       %{
         project: _project,
         publication: _publication,
         page_resource: _page_resource,
         next_page_revision: next_page_revision
       }} ->
        socket = put_flash(socket, :info, "Discussions successfully #{action}.")
        collab_space_config = next_page_revision.collab_space_config

        {:noreply,
         assign(socket,
           page_revision: next_page_revision,
           form: to_form(Resources.change_revision(next_page_revision)),
           collab_space_status: get_status(collab_space_config),
           collab_space_config: collab_space_config
         )}

      {:error, _} ->
        socket = put_flash(socket, :error, "Discussions couldn't be #{action}.")
        {:noreply, socket}
    end
  end

  defp get_status(nil), do: :disabled
  defp get_status(%CollabSpaceConfig{status: status}), do: status

  defp from_struct(nil), do: %{}
  defp from_struct(collab_space), do: Map.from_struct(collab_space)
end
