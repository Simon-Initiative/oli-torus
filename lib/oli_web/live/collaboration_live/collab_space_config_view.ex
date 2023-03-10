defmodule OliWeb.CollaborationLive.CollabSpaceConfigView do
  use Surface.LiveView

  alias Oli.Authoring.Course
  alias Oli.Delivery
  alias Oli.Delivery.{DeliverySetting, Sections}
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias OliWeb.CollaborationLive.CollabSpaceView
  alias Phoenix.PubSub
  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, Field, HiddenInput, Inputs, Label, NumberInput}

  data is_delivery, :boolean, default: false
  data author_id, :string
  data user_id, :string
  data collab_space_config, :any
  data collab_space_status, :atom
  data changeset, :any
  data page_revision, :any
  data page_resource, :any
  data parent_entity, :any

  def mount(
        _params,
        %{
          "collab_space_config" => collab_space_config,
          "page_slug" => page_slug
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

        delivery_setting =
          case Delivery.get_delivery_setting_by(%{
                 section_id: section.id,
                 resource_id: page_resource.id
               }) do
            nil -> %DeliverySetting{}
            ds -> ds
          end

        {
          DeliveryResolver.from_revision_slug(section_slug, page_slug),
          Delivery.change_delivery_setting(delivery_setting, %{
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
       changeset: changeset,
       page_revision: page_revision,
       page_resource: page_resource,
       parent_entity: parent_entity,
       topic: topic
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="card max-w-full">
        <div class="flex flex-col md:flex-row md:items-center card-body justify-between">
          <div class="flex flex-col justify-start md:flex-row md:items-center gap-2">
            <h3 class="card-title">Collaborative Space Config</h3>
            <div>
              <span class="bg-delivery-primary-200 badge badge-info">{humanize(@collab_space_status)}</span>
            </div>
          </div>

          <div class="mt-4 md:mt-0">
            {#case @collab_space_status}
              {#match :disabled}
                <button class="torus-button primary" :on-click="enable">Enable</button>
              {#match :enabled}
                <button class="torus-button outline" :on-click="archive">Archive</button>
                <button class="torus-button secondary" :on-click="disable">Disable</button>
              {#match _}
                <button class="torus-button primary border outline" :on-click="enable">Enable</button>
                <button class="torus-button secondary" :on-click="disable">Disable</button>
            {/case}
          </div>
        </div>
        {#if @collab_space_status == :enabled}
          <div class="card-footer bg-transparent flex mt-8">
            <Form class="w-full" for={@changeset} submit="save">
              <Inputs for={:collab_space_config}>
                <HiddenInput field={:status}/>

                <Field name={:threaded} class="form-check mt-1">
                  <Checkbox class="form-check-input"/>
                  <Label class="form-check-label" text="Allow threading of posts with replies"/>
                </Field>

                <Field name={:auto_accept} class="form-check mt-1">
                  <Checkbox class="form-check-input"/>
                  <Label class="form-check-label" text="Allow posts to be visible without approval"/>
                </Field>

                <Field name={:show_full_history} class="form-check mt-1">
                  <Checkbox class="form-check-input"/>
                  <Label class="form-check-label" />
                </Field>

                <Field name={:anonymous_posting} class="form-check mt-1">
                  <Checkbox class="form-check-input"/>
                  <Label class="form-check-label" text="Allow anonymous posts"/>
                </Field>

                <br>
                Participation requirements
                <div class="flex flex-col gap-4">
                  <Field name={:participation_min_replies} class="form-group">
                    <Label text="Minimum replies"/>
                    <NumberInput class="form-control" opts={min: 0}/>
                  </Field>

                  <Field name={:participation_min_posts} class="form-group">
                    <Label text="Minimum posts" />
                    <NumberInput class="form-control" opts={min: 0}/>
                  </Field>
                </div>
              </Inputs>

              <button class="torus-button primary !flex ml-auto mt-8" type="submit">Save</button>
            </Form>
          </div>
        {/if}
      </div>
    """
  end

  def handle_event("save", %{"delivery_setting" => %{"collab_space_config" => attrs}}, socket) do
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
  # update the revision or the delivery_setting configuration
  defp upsert_collab_space(true, action, attrs, socket) do
    socket = clear_flash(socket)

    attrs = %{
      "section_id" => socket.assigns.parent_entity.id,
      "resource_id" => socket.assigns.page_resource.id,
      "user_id" => socket.assigns.user_id,
      "collab_space_config" => attrs
    }

    case Delivery.upsert_delivery_setting(attrs) do
      {:ok, delivery_setting} ->
        socket = put_flash(socket, :info, "Collaborative space successfully #{action}.")
        collab_space_config = delivery_setting.collab_space_config

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:updated_collab_space_config, collab_space_config}
        )

        {:noreply,
         assign(socket,
           changeset: Delivery.change_delivery_setting(delivery_setting),
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
           changeset: Resources.change_revision(next_page_revision),
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

  defp humanize(atom) do
    atom
    |> Atom.to_string()
    |> String.capitalize()
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
