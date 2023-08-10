defmodule OliWeb.CollaborationLive.CollabSpaceConfigView do
  use OliWeb, :live_view

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Delivery.Sections.SectionResource
  alias OliWeb.CollaborationLive.CollabSpaceView
  alias Phoenix.PubSub

  def mount(
        _params,
        %{
          "collab_space_config" => collab_space_config,
          "resource_slug" => page_slug
        } = session,
        socket
      ) do
    is_delivery = Map.get(session, "is_delivery")
    page_resource = Resources.get_resource_from_slug(page_slug)

    {page_revision, changeset, parent_entity, topic} =
      if is_delivery do
        section_slug = Map.get(session, "section_slug")
        section = Sections.get_section_by_slug(section_slug)

        topic = CollabSpaceView.channels_topic(section_slug, page_resource.id)
        PubSub.subscribe(Oli.PubSub, topic)

        section_resource = Sections.get_section_resource(section.id, page_resource.id)

        {
          DeliveryResolver.from_revision_slug(section_slug, page_slug),
          SectionResource.changeset(section_resource, %{
            collab_space_config: from_struct(collab_space_config)
          }),
          section,
          topic
        }
      else
        project_slug = Map.get(session, "project_slug")
        page_revision = AuthoringResolver.from_revision_slug(project_slug, page_slug)

        {
          page_revision,
          Resources.change_revision(page_revision, %{
            collab_space_config: from_struct(collab_space_config)
          }),
          Course.get_project_by_slug(project_slug),
          ""
        }
      end

    {:ok,
     assign(socket,
       is_delivery: is_delivery,
       author_id: Map.get(session, "current_author_id"),
       user_id: Map.get(session, "current_user_id"),
       collab_space_config: collab_space_config,
       collab_space_status: get_status(collab_space_config),
       form: to_form(changeset),
       page_revision: page_revision,
       page_resource: page_resource,
       parent_entity: parent_entity,
       topic: topic,
       is_overview_render: Map.get(session, "is_overview_render")
     )}
  end

  def render(assigns) do
    ~H"""
    <div class={"card max-w-full #{if @is_overview_render, do: "shadow-none"}"}>
      <div class="flex flex-col md:flex-row md:items-center card-body justify-between">
        <div class="flex flex-col justify-start md:flex-row md:items-center gap-2">
          <%= unless @is_overview_render do %>
            <h3 class="card-title">Collaborative Space Config</h3>
          <% end %>
          <div>
            <span class="bg-delivery-primary-200 badge badge-info">
              <%= humanize(@collab_space_status) %>
            </span>
          </div>
        </div>

        <div class="mt-4 md:mt-0">
          <.action_buttons status={@collab_space_status} />
        </div>
      </div>
      <%= if  @collab_space_status == :enabled do %>
        <div class="card-footer bg-transparent flex mt-8">
          <.form class="w-full" for={@form} phx-submit="save">
            <.inputs_for :let={cs} field={@form[:collab_space_config]}>
              <.input type="hidden" field={cs[:status]} />

              <div class="form-check mt-1">
                <.input
                  type="checkbox"
                  field={cs[:threaded]}
                  class="form-check-input"
                  label="Allow threading of posts with replies"
                />
              </div>

              <div class="form-check mt-1">
                <.input
                  type="checkbox"
                  field={cs[:auto_accept]}
                  class="form-check-input"
                  label="Allow posts to be visible without approval"
                />
              </div>

              <div class="form-check mt-1">
                <.input
                  type="checkbox"
                  field={cs[:show_full_history]}
                  class="form-check-input"
                  label="Show full history"
                />
              </div>

              <div class="form-check mt-1">
                <.input
                  type="checkbox"
                  field={cs[:anonymous_posting]}
                  class="form-check-input"
                  label="Allow anonymous posts"
                />
              </div>

              <br /> Participation requirements
              <div class="flex flex-col gap-4">
                <div class="form-group">
                  <.input
                    type="number"
                    min={0}
                    field={cs[:participation_min_replies]}
                    class="form-control"
                    label="Minimum replies"
                  />
                </div>

                <div class="form-group">
                  <.input
                    type="number"
                    min={0}
                    field={cs[:participation_min_posts]}
                    class="form-control"
                    label="Minimum posts"
                  />
                </div>
              </div>
            </.inputs_for>

            <button class="torus-button primary !flex ml-auto mt-8" type="submit">Save</button>
          </.form>
        </div>
      <% end %>
    </div>
    """
  end

  attr(:status, :atom)

  def action_buttons(%{status: :disabled} = assigns) do
    ~H"""
    <button class="torus-button primary" phx-click="enable">Enable</button>
    """
  end

  def action_buttons(%{status: :enabled} = assigns) do
    ~H"""
    <button class="torus-button outline" phx-click="archive">Archive</button>
    <button class="torus-button secondary" phx-click="disable">Disable</button>
    """
  end

  def action_buttons(assigns) do
    ~H"""
    <button class="torus-button primary border outline" phx-click="enable">Enable</button>
    <button class="torus-button secondary" phx-click="disable">Disable</button>
    """
  end

  def handle_event("save", %{"section_resource" => %{"collab_space_config" => attrs}}, socket) do
    upsert_collab_space(socket.assigns.is_delivery, "updated", attrs, socket)
  end

  def handle_event("save", %{"revision" => %{"collab_space_config" => attrs}}, socket) do
    upsert_collab_space(socket.assigns.is_delivery, "updated", attrs, socket)
  end

  def handle_event("enable", _params, socket) do
    upsert_collab_space(
      socket.assigns.is_delivery,
      "enabled",
      Map.merge(from_struct(socket.assigns.collab_space_config), %{status: :enabled}),
      socket
    )
  end

  def handle_event("disable", _params, socket) do
    upsert_collab_space(
      socket.assigns.is_delivery,
      "disabled",
      Map.merge(from_struct(socket.assigns.collab_space_config), %{status: :disabled}),
      socket
    )
  end

  def handle_event("archive", _params, socket) do
    upsert_collab_space(
      socket.assigns.is_delivery,
      "archived",
      Map.merge(from_struct(socket.assigns.collab_space_config), %{status: :archived}),
      socket
    )
  end

  # first argument is a flag that specifies whether it is delivery or not, to accordingly
  # update the revision or the section_resource configuration
  defp upsert_collab_space(true, action, attrs, socket) do
    socket = clear_flash(socket)

    case Oli.Delivery.Sections.get_section_resource(
           socket.assigns.parent_entity.id,
           socket.assigns.page_resource.id
         )
         |> Oli.Delivery.Sections.update_section_resource(%{collab_space_config: attrs}) do
      {:ok, section_resource} ->
        socket = put_flash(socket, :info, "Collaborative space successfully #{action}.")
        collab_space_config = section_resource.collab_space_config

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:updated_collab_space_config, collab_space_config}
        )

        {:noreply,
         assign(socket,
           form: to_form(SectionResource.changeset(section_resource, %{})),
           collab_space_status: get_status(collab_space_config),
           collab_space_config: collab_space_config
         )}

      {:error, _} ->
        socket = put_flash(socket, :error, "Collaborative space couldn't be #{action}.")
        {:noreply, socket}
    end
  end

  defp upsert_collab_space(_, action, attrs, socket) do
    socket = clear_flash(socket)

    case Collaboration.upsert_collaborative_space(
           attrs,
           socket.assigns.parent_entity,
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
        socket = put_flash(socket, :info, "Collaborative space successfully #{action}.")
        collab_space_config = next_page_revision.collab_space_config

        {:noreply,
         assign(socket,
           page_revision: next_page_revision,
           form: to_form(Resources.change_revision(next_page_revision)),
           collab_space_status: get_status(collab_space_config),
           collab_space_config: collab_space_config
         )}

      {:error, _} ->
        socket = put_flash(socket, :error, "Collaborative space couldn't be #{action}.")
        {:noreply, socket}
    end
  end

  defp get_status(nil), do: :disabled
  defp get_status(%CollabSpaceConfig{status: status}), do: status

  defp from_struct(nil), do: %{}
  defp from_struct(collab_space), do: Map.from_struct(collab_space)

  def handle_info(_, socket), do: {:noreply, socket}
end
