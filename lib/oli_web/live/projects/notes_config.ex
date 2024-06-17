defmodule OliWeb.Projects.NotesConfig do
  use Phoenix.LiveComponent

  import OliWeb.Components.Common

  alias Oli.Resources
  alias Oli.Publishing.{AuthoringResolver}
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  def update(assigns, socket) do
    project = assigns.project
    collab_space_config = assigns.collab_space_config
    page_slug = assigns.resource_slug

    page_revision = AuthoringResolver.from_revision_slug(project.slug, page_slug)

    changeset =
      Resources.change_revision(page_revision, %{
        collab_space_config: from_struct(collab_space_config)
      })

    {notes_enabled_pages_count, pages_count} =
      Collaboration.count_collab_spaces_enabled_in_pages_for_project(project.slug)

    {:ok,
     assign(socket,
       project: project,
       notes_enabled: notes_enabled_pages_count > 0,
       total_pages_count: pages_count,
       notes_enabled_pages_count: notes_enabled_pages_count,
       form: to_form(changeset)
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <Modal.modal
        id="enable_notes_space_modal"
        class="!w-auto"
        on_confirm={
          JS.dispatch("click", to: "#enable_collab_submit_button")
          |> Modal.hide_modal("enable_notes_space_modal")
        }
      >
        Are you sure you want to <strong>enable</strong>
        Notes for all pages in the course?
        <br />The following configuration will be bulk-applied to all pages:
        <.form
          class="w-full"
          for={@form}
          phx-submit="enable_all_page_collab_spaces"
          phx-target={@myself}
        >
          <.collab_space_form_content form={@form} />
          <button id="enable_collab_submit_button" class="hidden" type="submit" />
        </.form>

        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <Modal.modal
        id="disable_notes_modal"
        class="!w-auto"
        on_confirm={
          JS.push("disable_all_page_collab_spaces", target: @myself)
          |> Modal.hide_modal("disable_notes_modal")
        }
      >
        Are you sure you want to <strong>disable</strong>
        collaboration spaces for all pages in the course?
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <div class="inline-flex py-2 mb-2 border-b dark:border-gray-700">
        <span>Enable Notes for all pages in the course</span>
        <.toggle_switch
          class="ml-4"
          checked={@notes_enabled}
          on_toggle={
            if @notes_enabled do
              Modal.show_modal("disable_notes_modal")
            else
              Modal.show_modal("enable_notes_space_modal")
            end
          }
        />
      </div>
      <div>
        <%= ~s{#{if @total_pages_count == @notes_enabled_pages_count, do: "All"} #{@notes_enabled_pages_count} #{Gettext.ngettext(OliWeb.Gettext, "page currently has", "pages currently have", @notes_enabled_pages_count)}} %> Notes enabled.
      </div>
    </div>
    """
  end

  attr :form, :map

  def collab_space_form_content(assigns) do
    ~H"""
    <.inputs_for :let={cs} field={@form[:collab_space_config]}>
      <.input type="hidden" field={cs[:status]} />

      <.input type="hidden" field={cs[:threaded]} />
      <.input type="hidden" field={cs[:show_full_history]} />
      <.input type="hidden" field={cs[:participation_min_replies]} value={0} />
      <.input type="hidden" field={cs[:participation_min_posts]} value={0} />

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
          field={cs[:anonymous_posting]}
          class="form-check-input"
          label="Allow anonymous posts"
        />
      </div>
    </.inputs_for>
    """
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
        socket.assigns.project.slug,
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

    {:noreply, assign(socket, notes_enabled: true, notes_enabled_pages_count: total_page_count)}
  end

  def handle_event("disable_all_page_collab_spaces", _params, socket) do
    Collaboration.disable_all_page_collab_spaces_for_project(socket.assigns.project.slug)

    {:noreply, assign(socket, notes_enabled: false, notes_enabled_pages_count: 0)}
  end

  defp from_struct(nil), do: %{}
  defp from_struct(collab_space), do: Map.from_struct(collab_space)
end
