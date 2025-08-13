defmodule OliWeb.Progress.StudentResourceView do
  use OliWeb, :live_view

  import Ecto.Query, warn: false

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Attempts.PageLifecycle.Broadcaster
  alias Oli.Repo
  alias OliWeb.Common.{Breadcrumb, Confirm, Utils}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias OliWeb.Progress.{AttemptHistory, Passback}
  alias OliWeb.Sections.Mount

  defp set_breadcrumbs(type, section, user_id) do
    OliWeb.Progress.StudentView.set_breadcrumbs(type, section, user_id)
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
        _session,
        socket
      ) do
    case get_user_and_revision(section_slug, user_id, resource_id) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:ok, user, revision} ->
        case Mount.for(section_slug, socket) do
          {:error, e} ->
            Mount.handle_error(socket, {:error, e})

          {type, _, section} ->
            resource_access = get_resource_access(resource_id, section_slug, user_id)

            resource_attempts =
              unless is_nil(resource_access),
                do:
                  resource_access.resource_attempts
                  |> Enum.sort(&(&1.attempt_number < &2.attempt_number)),
                else: []

            changeset =
              case resource_access do
                nil ->
                  nil

                _ ->
                  ResourceAccess.changeset(resource_access, %{
                    # limit score decimals to two significant figures, rounding up
                    score:
                      if is_nil(resource_access.score) do
                        nil
                      else
                        Utils.format_score(resource_access.score)
                      end
                  })
              end

            {:ok,
             assign(socket,
               changeset: changeset,
               breadcrumbs: set_breadcrumbs(type, section, user_id),
               section: section,
               resource_access: resource_access,
               resource_attempts: resource_attempts,
               revision: revision,
               last_failed: fetch_last_failed(resource_access),
               user: user,
               show_confirm: false,
               is_editing: false,
               grade_sync_result: nil
             )}
        end
    end
  end

  defp fetch_last_failed(resource_access) do
    if ResourceAccess.last_grade_update_failed?(resource_access) do
      Oli.Repo.get(
        Oli.Delivery.Attempts.Core.LMSGradeUpdate,
        resource_access.last_grade_update_id
      )
    else
      nil
    end
  end

  defp get_resource_access(resource_id, section_slug, user_id) do
    case Oli.Delivery.Attempts.Core.get_resource_access(
           resource_id,
           section_slug,
           user_id
         ) do
      nil ->
        nil

      ra ->
        Oli.Repo.preload(ra, :resource_attempts)
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
    ~H"""
    <Groups.render>
      <Group.render label="Details" description="">
        <ReadOnly.render label="Student" value={OliWeb.Common.Utils.name(@user)} />
        <ReadOnly.render label="Resource" value={@revision.title} />
      </Group.render>
      <%= if @revision.graded do %>
        <Group.render label="Current Score" description="">
          <.form
            as={:resource_access}
            for={@changeset}
            phx-change="validate"
            phx-submit="save"
            autocomplete="off"
          >
            <div class="form-group">
              <div class="d-flex justify-content-between items-center">
                <label for="score" class="mt-3">Score</label>
                <.error
                  :for={error <- Keyword.get_values(@changeset.errors || [], :score)}
                  for="resource_access[score]"
                >
                  {translate_error(error)}
                </.error>
              </div>
              <.input
                id="resource_access_score"
                class="form-control"
                type="number"
                name="resource_access[score]"
                value={fetch_field(@changeset, :score)}
                disabled={!@is_editing}
                step="0.01"
              />

              <div class="text-muted">Scores are rounded up, limiting to two decimal points.</div>
            </div>

            <div class="form-group">
              <div class="d-flex justify-content-between items-center">
                <label for="score" class="mt-3">Out Of</label>
                <.error
                  :for={error <- Keyword.get_values(@changeset.errors || [], :out_of)}
                  for="resource_access[out_of]"
                >
                  {translate_error(error)}
                </.error>
              </div>
              <.input
                id="resource_access_out_of"
                class="form-control"
                type="number"
                name="resource_access[out_of]"
                value={fetch_field(@changeset, :out_of)}
                disabled={!@is_editing}
                step="0.01"
              />
            </div>

            <%= if @is_editing do %>
              <button class="btn btn-primary" type="submit">Save</button>
              <button class="btn btn-primary" type="button" phx-click="disable_score_edit">
                Cancel
              </button>
            <% else %>
              <button class="btn btn-primary" type="button" phx-click="enable_score_edit">
                Change Score
              </button>
            <% end %>
          </.form>

          <%= if !@section.open_and_free do %>
            <div class="mb-3" />
            <Passback.render
              click="passback"
              last_failed={@last_failed}
              resource_access={@resource_access}
              grade_sync_result={@grade_sync_result}
            />
          <% end %>
        </Group.render>
      <% end %>
      <Group.render label="Attempt History" description="">
        <AttemptHistory.render
          revision={@revision}
          section={@section}
          resource_attempts={@resource_attempts}
          ctx={@ctx}
          request_path={~p"/sections/#{@section.slug}/progress/#{@user.id}/#{@revision.resource_id}"}
        />
      </Group.render>
    </Groups.render>
    <%= if @show_confirm do %>
      <Confirm.render
        title="Confirm Attempt Submit"
        id="dialog"
        ok="do_submit_attempt"
        cancel="cancel_modal"
      >
        Are you sure that you wish to finalize this attempt on behalf of the student?
      </Confirm.render>
    <% end %>
    """
  end

  def render_never_visited(assigns) do
    ~H"""
    <Groups.render>
      <Group.render label="Details" description="">
        <ReadOnly.render label="Student" value={OliWeb.Common.Utils.name(@user)} />
        <ReadOnly.render label="Resource" value={@revision.title} />
      </Group.render>
      <Group.render label="Attempt History" description="">
        <p>The student has not yet accessed this course resource.</p>

        <%= if @revision.graded do %>
          <p>
            If there is a need to manually set the grade for this student without the student ever having visited this page, first create the access record:
          </p>
          <button class="btn btn-primary mt-4" type="button" phx-click="create_access_record">
            Create Access Record
          </button>
        <% end %>
      </Group.render>
    </Groups.render>
    """
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("submit_attempt", %{"guid" => attempt_guid}, socket) do
    {:noreply, assign(socket, show_confirm: true, attempt_guid: attempt_guid)}
  end

  def handle_event("phx_modal.unmount", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("do_submit_attempt", _, socket) do
    attempt_guid = socket.assigns.attempt_guid

    datashop_session_id =
      case get_datashop_session_id(attempt_guid) do
        nil -> UUID.uuid4()
        id -> id
      end

    case Oli.Delivery.Attempts.PageLifecycle.finalize(
           socket.assigns.section.slug,
           attempt_guid,
           datashop_session_id
         ) do
      {:ok, _} ->
        resource_access =
          get_resource_access(
            socket.assigns.revision.resource_id,
            socket.assigns.section.slug,
            socket.assigns.user.id
          )

        socket =
          socket
          |> put_flash(:info, "Attempt submitted.")
          |> assign(resource_access: resource_access)

        {:noreply, socket}

      _ ->
        resource_access =
          get_resource_access(
            socket.assigns.revision.resource_id,
            socket.assigns.section.slug,
            socket.assigns.user.id
          )

        socket =
          socket
          |> put_flash(:error, "Unable to submit attempt.")
          |> assign(resource_access: resource_access)

        {:noreply, socket}
    end
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

  def handle_event("create_access_record", _, socket) do
    section = socket.assigns.section
    user = socket.assigns.user
    revision = socket.assigns.revision

    {:ok, resource_access} = Core.track_access(revision.resource_id, section.id, user.id)
    {:noreply, assign(socket, resource_access: resource_access)}
  end

  def handle_event("passback", _, socket) do
    section = socket.assigns.section
    user = socket.assigns.user
    revision = socket.assigns.revision

    # Read the latest resource_access to account for cases where a student has
    # just finalized another attempt, or the instructor has overriden the grade in another
    # instance of this window
    resource_access = get_resource_access(revision.resource_id, section.slug, user.id)

    {:ok, %Oban.Job{id: id}} =
      Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.create(
        section.id,
        resource_access.id,
        :manual
      )

    Broadcaster.subscribe_to_lms_grade_update(
      socket.assigns.section.id,
      socket.assigns.resource_access.id,
      id
    )

    {:noreply, assign(socket, grade_sync_result: "Pending...", resource_access: resource_access)}
  end

  def handle_event("save", %{"resource_access" => params}, socket) do
    params =
      ensure_no_nil(params, "score")
      |> ensure_no_nil("out_of")

    case Core.update_resource_access(socket.assigns.resource_access, params) do
      # Score is updated as provided, and it's formatted and rounded for display only
      {:ok, resource_access} ->
        socket = put_flash(socket, :info, "Grade changed")

        {:noreply,
         assign(socket,
           is_editing: false,
           resource_access: resource_access,
           changeset:
             ResourceAccess.changeset(resource_access, %{
               score: Utils.format_score(resource_access.score)
             })
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_info({:lms_grade_update_result, payload}, socket) do
    %Oli.Delivery.Attempts.PageLifecycle.GradeUpdatePayload{
      job: %{id: job_id},
      status: result
    } = payload

    %{
      resource_access: resource_access,
      section: section,
      user: user
    } = socket.assigns

    # Unsubscribe to this job when we reach a terminal state
    if result in [:success, :failure, :not_synced] do
      Broadcaster.unsubscribe_to_lms_grade_update(
        socket.assigns.section.id,
        resource_access.id,
        job_id
      )
    end

    resource_access = get_resource_access(resource_access.resource_id, section.slug, user.id)

    grade_sync_result =
      case result do
        :pending -> "LMS Update Pending..."
        :success -> "LMS Update Succeeded"
        :failure -> "LMS Update Failed"
        :retrying -> "LMS Update Failed, Retrying"
        :running -> "LMS Update Executing..."
        :not_synced -> "Grade passback not enabled"
      end

    {:noreply,
     assign(socket,
       resource_access: resource_access,
       last_failed: fetch_last_failed(resource_access),
       grade_sync_result: grade_sync_result
     )}
  end

  defp ensure_no_nil(params, key) do
    case Map.get(params, key) do
      nil -> Map.delete(params, key)
      "" -> Map.delete(params, key)
      _ -> params
    end
  end

  defp get_datashop_session_id(resource_attempt_guid) do
    part_attempts =
      Repo.all(
        from(
          part_attempt in PartAttempt,
          join: aa in ActivityAttempt,
          on: aa.id == part_attempt.activity_attempt_id,
          join: resource_attempt in ResourceAttempt,
          on: resource_attempt.id == aa.resource_attempt_id,
          where: resource_attempt.attempt_guid == ^resource_attempt_guid,
          limit: 1,
          select: part_attempt.datashop_session_id
        )
      )

    case part_attempts do
      [] -> nil
      [id] -> id
    end
  end
end
