defmodule OliWeb.CollaborationLive.CollabSpaceConfigView do
  use Surface.LiveView

  alias Oli.Authoring.Course
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, Field, HiddenInput, Inputs, Label, NumberInput}

  data author_id, :string
  data project, :any
  data collab_space_config, :any
  data changeset, :any
  data status, :atom
  data page_slug, :any
  data page, :any

  def mount(_params, %{
    "collab_space_config" => collab_space_config,
    "current_author_id" => current_author_id,
    "project_slug" => project_slug,
    "page_slug" => page_slug
  }, socket) do
    revision = AuthoringResolver.from_revision_slug(project_slug, page_slug)

    {:ok,
      assign(socket,
        author_id: current_author_id,
        project: Course.get_project_by_slug(project_slug),
        collab_space_config: collab_space_config,
        changeset: Resources.change_revision(revision),
        status: get_status(collab_space_config),
        page_slug: page_slug,
        page: revision
      )}
  end

  def render(assigns) do
    ~F"""
      <div class="card">
        <div class="card-body d-flex justify-content-between">
          <div class="d-flex">
            <div class="card-title h5">Collaborative Space</div>
            <span class="badge badge-info ml-2" style="height: fit-content">{humanize(@status)}</span>
          </div>

          {#case @status}
            {#match :disabled}
              <button class="btn btn-outline-primary" :on-click="enable">Enable</button>
            {#match :enabled}
              <div>
                <button class="btn btn-outline-primary" :on-click="archive">Archive</button>
                <button class="btn btn-outline-danger" :on-click="disable">Disable</button>
              </div>
            {#match _}
              <div>
                <button class="btn btn-outline-primary" :on-click="enable">Enable</button>
                <button class="btn btn-outline-danger" :on-click="disable">Disable</button>
              </div>
          {/case}
        </div>
        {#if @status == :enabled}
          <div class="card-footer bg-transparent d-flex justify-content-center">
            <Form for={@changeset} submit="save">
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

                <br>
                Participation requirements
                <div class="ml-4">
                  <Field name={:participation_min_replies} class="form-group mt-1">
                    <Label text="Minimum replies"/>
                    <NumberInput class="form-control"/>
                  </Field>

                  <Field name={:participation_min_posts} class="form-group mt-1">
                    <Label text="Minimum posts" />
                    <NumberInput class="form-control"/>
                  </Field>
                </div>
              </Inputs>

              <button class="form-button btn btn-md btn-primary mt-3" type="submit">Save</button>
            </Form>
          </div>
        {/if}
      </div>
    """
  end

  def handle_event("save", %{"revision" => %{"collab_space_config" => attrs}}, socket) do
    upsert_collab_space("updated", attrs, socket)
  end

  def handle_event("enable", _params, socket) do
    upsert_collab_space(
      "enabled",
      Map.merge(Map.from_struct(socket.assigns.collab_space_config), %{status: :enabled}),
      socket
    )
  end

  def handle_event("disable", _params, socket) do
    upsert_collab_space(
      "disabled",
      Map.merge(Map.from_struct(socket.assigns.collab_space_config), %{status: :disabled}),
      socket
    )
  end

  def handle_event("archive", _params, socket) do
    upsert_collab_space(
      "archived",
      Map.merge(Map.from_struct(socket.assigns.collab_space_config), %{status: :archived}),
      socket
    )
  end

  defp upsert_collab_space(action, attrs, socket) do
    socket = clear_flash(socket)

    case Collaboration.upsert_collaborative_space(
      attrs,
      socket.assigns.project,
      socket.assigns.page_slug,
      socket.assigns.author_id
    ) do
      {:ok,
        %{
          project: _project,
          publication: _publication,
          page_resource: _page_resource,
          next_page_revision: next_page_revision
        }
      } ->
        socket = put_flash(socket, :info, "Collaborative space successfully #{action}.")
        collab_space_config = next_page_revision.collab_space_config

        {:noreply,
          assign(socket,
            page: next_page_revision,
            changeset: Resources.change_revision(next_page_revision),
            status: get_status(collab_space_config),
            collab_space_config: collab_space_config
          )}

      {:error, _} ->
        socket = put_flash(socket, :error, "Collaborative space couldn't be #{action}.")
        {:noreply, socket}
    end
  end

  defp get_status(nil), do: :disabled
  defp get_status(%CollabSpaceConfig{status: status}), do: status

  defp humanize(atom) do
    atom
    |> Atom.to_string()
    |> String.capitalize()
  end
end
