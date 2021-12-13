defmodule OliWeb.Progress.StudentResourceView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Surface.Components.{Form}
  alias Surface.Components.Form.{Field, Label, NumberInput, ErrorTag}
  alias OliWeb.Progress.AttemptHistory
  alias OliWeb.Sections.Mount
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Progress.Passback

  data breadcrumbs, :any
  data title, :string, default: "Student Progress"
  data section, :any, default: nil
  data changeset, :any
  data resource_access, :any
  data revision, :any
  data user, :any
  data is_editing, :boolean, default: false
  data grade_sync_result, :any, default: nil

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, _) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "View Resource Progress"
        })
      ]
  end

  def mount(
        %{"section_slug" => section_slug, "user_id" => user_id, "resource_id" => resource_id},
        session,
        socket
      ) do
    case get_user_and_revision(section_slug, user_id, resource_id) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:ok, user, revision} ->
        case Mount.for(section_slug, session) do
          {:error, e} ->
            Mount.handle_error(socket, {:error, e})

          {type, _, section} ->
            resource_access = get_resource_access(resource_id, section_slug, user_id)

            changeset =
              case resource_access do
                nil -> nil
                _ -> ResourceAccess.changeset(resource_access, %{})
              end

            {:ok,
             assign(socket,
               changeset: changeset,
               breadcrumbs: set_breadcrumbs(type, section),
               section: section,
               resource_access: resource_access,
               revision: revision,
               user: user
             )}
        end
    end
  end

  defp get_resource_access(resource_id, section_slug, user_id) do
    case Oli.Delivery.Attempts.Core.get_resource_access(
           resource_id,
           section_slug,
           user_id
         ) do
      nil -> nil
      ra -> Oli.Repo.preload(ra, :resource_attempts)
    end
  end

  defp get_user_and_revision(section_slug, user_id, resource_id) do
    case Oli.Publishing.DeliveryResolver.from_resource_id(section_slug, resource_id) do
      nil ->
        {:error, :not_found}

      revision ->
        case Oli.Accounts.get_user!(user_id) do
          nil -> {:error, :not_found}
          user -> {:ok, user, revision}
        end
    end
  end

  def render(assigns) do
    case assigns.resource_access do
      nil -> render_never_visited(assigns)
      _ -> render_with_access(assigns)
    end
  end

  def render_with_access(assigns) do
    ~F"""
    <Groups>
      <Group label="Details" description="">
        <ReadOnly label="Student" value={OliWeb.Common.Utils.name(@user)}/>
        <ReadOnly label="Resource" value={@revision.title}/>
      </Group>
      {#if @revision.graded}
      <Group label="Current Grade" description="">

          <Form as={:resource_access} for={@changeset} change="validate" submit="save" opts={autocomplete: "off"}>
            <Field name={:score} class="form-label-group">
              <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
              <NumberInput class="form-control" opts={disabled: !@is_editing}/>
            </Field>
            <Field name={:out_of} class="form-label-group mb-4">
              <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
              <NumberInput class="form-control" opts={disabled: !@is_editing}/>
            </Field>

            {#if @is_editing}
              <button class="btn btn-primary" type="submit">Save</button>
              <button class="btn btn-primary" type="button" :on-click="disable_score_edit">Cancel</button>
            {#else}
              <button class="btn btn-primary" type="button" :on-click="enable_score_edit">Change Score</button>
            {/if}
          </Form>

          {#if !@section.open_and_free}
            <div class="mb-3"/>
            <Passback click="passback" grade_sync_result={@grade_sync_result}/>
          {/if}

      </Group>
      {/if}
      <Group label="Attempt History" description="">
        <AttemptHistory resource_attempts={@resource_access.resource_attempts}/>
      </Group>
    </Groups>
    """
  end

  def render_never_visited(assigns) do
    ~F"""
    <Groups>
      <Group label="Details" description="">
        <ReadOnly label="Student" value={OliWeb.Common.Utils.name(@user)}/>
        <ReadOnly label="Resource" value={@revision.title}/>
      </Group>
      <Group label="Attempt History" description="">
        The student has not yet accessed this course resource
      </Group>
    </Groups>
    """
  end

  def handle_event("enable_score_edit", _, socket) do
    {:noreply, assign(socket, is_editing: true)}
  end

  def handle_event("disable_score_edit", _, socket) do
    {:noreply, assign(socket, is_editing: false)}
  end

  def handle_event("validate", %{"resource_access" => params}, socket) do
    params =
      ensure_no_nil(params, "score")
      |> ensure_no_nil("out_of")

    changeset =
      socket.assigns.resource_access
      |> ResourceAccess.changeset(params)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("passback", _, socket) do
    section = socket.assigns.section
    user = socket.assigns.user
    revision = socket.assigns.revision

    # Read the latest resource_access to account for cases where a student has
    # just finalized another attempt, or the instructor has overriden the grade in another
    # instance of this window
    resource_access = get_resource_access(revision.resource_id, section.slug, user.id)

    grade_sync_result = send_one_grade(section, user, resource_access)

    {:noreply,
     assign(socket, grade_sync_result: grade_sync_result, resource_access: resource_access)}
  end

  def handle_event("save", %{"resource_access" => params}, socket) do
    params =
      ensure_no_nil(params, "score")
      |> ensure_no_nil("out_of")

    case Core.update_resource_access(socket.assigns.resource_access, params) do
      {:ok, resource_access} ->
        socket = put_flash(socket, :info, "Grade changed")

        {:noreply,
         assign(socket,
           is_editing: false,
           resource_access: resource_access,
           changeset: ResourceAccess.changeset(resource_access, %{})
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp access_token_provider(section) do
    fn ->
      {_deployment, registration} =
        Oli.Delivery.Sections.get_deployment_registration_from_section(section)

      Lti_1p3.Tool.AccessToken.fetch_access_token(registration, Oli.Grading.ags_scopes(), host())
    end
  end

  def send_one_grade(section, user, resource_access) do
    Oli.Grading.send_score_to_lms(section, user, resource_access, access_token_provider(section))
  end

  defp ensure_no_nil(params, key) do
    case Map.get(params, key) do
      nil -> Map.delete(params, key)
      "" -> Map.delete(params, key)
      _ -> params
    end
  end
end
