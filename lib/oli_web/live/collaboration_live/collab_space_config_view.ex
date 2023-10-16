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
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  def mount(
        _params,
        %{
          "collab_space_config" => collab_space_config,
          "resource_slug" => page_slug
        } = session,
        socket
      ) do
    is_delivery = Map.get(session, "is_delivery", false)
    page_resource = Resources.get_resource_from_slug(page_slug)

    slug =
      if is_delivery, do: Map.get(session, "section_slug"), else: Map.get(session, "project_slug")

    {page_revision, changeset, parent_entity, topic} =
      if is_delivery do
        section = Sections.get_section_by_slug(slug)

        topic = CollabSpaceView.channels_topic(slug, page_resource.id)
        PubSub.subscribe(Oli.PubSub, topic)

        section_resource = Sections.get_section_resource(section.id, page_resource.id)

        {
          DeliveryResolver.from_revision_slug(slug, page_slug),
          SectionResource.changeset(section_resource, %{
            collab_space_config: from_struct(collab_space_config)
          }),
          section,
          topic
        }
      else
        page_revision = AuthoringResolver.from_revision_slug(slug, page_slug)

        {
          page_revision,
          Resources.change_revision(page_revision, %{
            collab_space_config: from_struct(collab_space_config)
          }),
          Course.get_project_by_slug(slug),
          ""
        }
      end

    {collab_space_pages_count, pages_count} =
      get_collab_space_pages_count(is_delivery, slug)

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
       pages_count: pages_count,
       collab_space_pages_count: collab_space_pages_count,
       topic: topic,
       is_overview_render: Map.get(session, "is_overview_render"),
       slug: slug
     )}
  end

  def render(assigns) do
    ~H"""
    <Modal.modal
      id="enable_collab_space_modal"
      class="!w-auto"
      on_confirm={
        JS.dispatch("click", to: "#enable_collab_submit_button")
        |> Modal.hide_modal("enable_collab_space_modal")
      }
    >
      Are you sure you want to <strong>enable</strong>
      collaboration spaces for all pages in the course?
      <br />The following configuration will be bulk-applied to all pages:
      <.form class="w-full" for={@form} phx-submit="enable_all_page_collab_spaces">
        <.collab_space_form_content form={@form} />
        <button id="enable_collab_submit_button" class="hidden" type="submit" />
      </.form>

      <:confirm>OK</:confirm>
      <:cancel>Cancel</:cancel>
    </Modal.modal>

    <Modal.modal
      id="disable_collab_space_modal"
      class="!w-auto"
      on_confirm={
        JS.push("disable_all_page_collab_spaces") |> Modal.hide_modal("disable_collab_space_modal")
      }
    >
      Are you sure you want to <strong>disable</strong>
      collaboration spaces for all pages in the course?
      <:confirm>OK</:confirm>
      <:cancel>Cancel</:cancel>
    </Modal.modal>

    <div class={"card max-w-full #{if @is_overview_render, do: "shadow-none p-0"}"}>
      <section>
        <h5 :if={@is_overview_render} class="mb-2">Student Course Portal Collaborative Space</h5>
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
              <.collab_space_form_content form={@form} />
              <button class="torus-button primary !flex ml-auto mt-4" type="submit">Save</button>
            </.form>
          </div>
        <% end %>
      </section>

      <section
        :if={@is_overview_render}
        class="flex flex-col space-y-4 mt-8 pt-6 border-t border-gray-200"
      >
        <h5>
          <%= ~s{#{if @pages_count == @collab_space_pages_count, do: "All"} #{@collab_space_pages_count} #{Gettext.ngettext(OliWeb.Gettext, "page currently has", "pages currently have", @collab_space_pages_count)}} %> Collaborative Spaces enabled
        </h5>
        <button
          phx-click={
            @pages_count > @collab_space_pages_count &&
              Modal.show_modal("enable_collab_space_modal")
          }
          class={[
            "btn btn-primary w-[450px]",
            "#{if @pages_count == @collab_space_pages_count, do: "disabled"}"
          ]}
        >
          Enable Collaboration Spaces for all pages in the course
        </button>
        <button
          phx-click={@collab_space_pages_count > 0 && Modal.show_modal("disable_collab_space_modal")}
          class={[
            "btn btn-primary w-[450px]",
            "#{if @collab_space_pages_count == 0, do: "disabled"}"
          ]}
        >
          Disable Collaboration Spaces for all pages in the course
        </button>
      </section>
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

  attr :form, :map

  def collab_space_form_content(assigns) do
    ~H"""
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

  def handle_event("disable_all_page_collab_spaces", _params, socket) do
    if socket.assigns.is_delivery do
      Collaboration.disable_all_page_collab_spaces_for_section(socket.assigns.slug)
    else
      Collaboration.disable_all_page_collab_spaces_for_project(socket.assigns.slug)
    end

    {:noreply, assign(socket, collab_space_pages_count: 0)}
  end

  def handle_event(
        "enable_all_page_collab_spaces",
        %{
          "section_resource" => %{
            "collab_space_config" => collab_space_config
          }
        },
        socket
      ) do
    {total_page_count, _section_resources} =
      Collaboration.enable_all_page_collab_spaces_for_section(
        socket.assigns.slug,
        %CollabSpaceConfig{
          status: :enabled,
          threaded: Oli.Utils.string_to_boolean(collab_space_config["threaded"]),
          auto_accept: Oli.Utils.string_to_boolean(collab_space_config["auto_accept"]),
          show_full_history:
            Oli.Utils.string_to_boolean(collab_space_config["show_full_history"]),
          anonymous_posting:
            Oli.Utils.string_to_boolean(collab_space_config["anonymous_posting"]),
          participation_min_replies:
            String.to_integer(collab_space_config["participation_min_replies"]),
          participation_min_posts:
            String.to_integer(collab_space_config["participation_min_posts"])
        }
      )

    {:noreply, assign(socket, collab_space_pages_count: total_page_count)}
  end

  def handle_event(
        "enable_all_page_collab_spaces",
        %{
          "revision" => %{
            "collab_space_config" => collab_space_config
          }
        },
        socket
      ) do
    {total_page_count, _revisions} =
      Collaboration.enable_all_page_collab_spaces_for_project(
        socket.assigns.slug,
        %CollabSpaceConfig{
          status: :enabled,
          threaded: Oli.Utils.string_to_boolean(collab_space_config["threaded"]),
          auto_accept: Oli.Utils.string_to_boolean(collab_space_config["auto_accept"]),
          show_full_history:
            Oli.Utils.string_to_boolean(collab_space_config["show_full_history"]),
          anonymous_posting:
            Oli.Utils.string_to_boolean(collab_space_config["anonymous_posting"]),
          participation_min_replies:
            String.to_integer(collab_space_config["participation_min_replies"]),
          participation_min_posts:
            String.to_integer(collab_space_config["participation_min_posts"])
        }
      )

    {:noreply, assign(socket, collab_space_pages_count: total_page_count)}
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

  _docp = """
  Calculates the number of pages that have collaborative spaces enabled and
  the total number of pages, for authoring and instructor Overview page.
  """

  defp get_collab_space_pages_count(false, project_slug) do
    Collaboration.count_collab_spaces_enabled_in_pages_for_project(project_slug)
  end

  defp get_collab_space_pages_count(true, section_slug) do
    Collaboration.count_collab_spaces_enabled_in_pages_for_section(section_slug)
  end

  defp get_collab_space_pages_count(nil, _), do: %{with_collab_spaces_enabled: 0, total: 0}

  defp from_struct(nil), do: %{}
  defp from_struct(collab_space), do: Map.from_struct(collab_space)

  def handle_info(_, socket), do: {:noreply, socket}
end
