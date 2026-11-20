defmodule OliWeb.Admin.RestoreUserProgress do
  @moduledoc """
  System admin tool that merges the progress of a source user into a target user enrolled in the
  same section.

  The admin enters a section slug and both user IDs, verifies that both users are enrolled in the
  section, previews the resource access changes, and finally commits them in a single transaction.
  """

  use OliWeb, :live_view

  import Ecto.Query

  require Logger

  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Enrollment, Section}
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias OliWeb.Common.{FormatDateTime, SessionContext}

  def mount(_, session, socket) do
    {:ok,
     socket
     |> assign(title: "Restore User Progress")
     |> assign_new(:ctx, fn -> SessionContext.init(socket, session, is_liveview: true) end)
     |> assign_form(%{"section_slug" => "", "target_user_id" => "", "source_user_id" => ""})
     |> reset_verification()}
  end

  defp assign_form(socket, params), do: assign(socket, form: to_form(params))

  defp form_params(params),
    do: Map.take(params, ["section_slug", "target_user_id", "source_user_id"])

  # Clears everything derived from a previous verification so that a preview or commit can never
  # run against users other than the ones currently entered in the form.
  defp reset_verification(socket) do
    socket
    |> clear_flash()
    |> assign(
      verified: nil,
      true_user: nil,
      changes: [],
      commit_done: false
    )
  end

  @doc """
  Verifies that the target and source users are both enrolled in the section identified by
  `section_slug`.

  Inputs are the raw (string) values entered by the admin. Enrollments are matched regardless
  of their status, so that suspended or otherwise inactive duplicate accounts can still be merged.

  Returns `{:ok, %{section: section, target_enrollment: enrollment, source_enrollment: enrollment}}`
  with the `:user` association preloaded on both enrollments, or `{:error, message}` describing
  the first check that failed.
  """
  @spec verify_enrollments(term(), term(), term()) :: {:ok, map()} | {:error, String.t()}
  def verify_enrollments(section_slug, target_user_id, source_user_id) do
    with {:ok, section_slug} <- parse_section_slug(section_slug),
         {:ok, target_user_id} <- parse_user_id(target_user_id, "target"),
         {:ok, source_user_id} <- parse_user_id(source_user_id, "source"),
         :ok <- ensure_different_users(target_user_id, source_user_id),
         {:ok, section} <- fetch_section(section_slug),
         {:ok, target_enrollment} <- fetch_enrollment(section, target_user_id, "Target"),
         {:ok, source_enrollment} <- fetch_enrollment(section, source_user_id, "Source") do
      {:ok,
       %{
         section: section,
         target_enrollment: target_enrollment,
         source_enrollment: source_enrollment
       }}
    end
  end

  defp parse_section_slug(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, "Set a section slug."}
      slug -> {:ok, slug}
    end
  end

  defp parse_section_slug(_), do: {:error, "Set a section slug."}

  defp parse_user_id(value, label) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, "Set a valid #{label} user ID."}
    end
  end

  defp parse_user_id(_, label), do: {:error, "Set a valid #{label} user ID."}

  defp ensure_different_users(user_id, user_id),
    do: {:error, "Target and source user IDs must be different."}

  defp ensure_different_users(_, _), do: :ok

  defp fetch_section(section_slug) do
    case Sections.get_section_by(slug: section_slug) do
      nil -> {:error, "Section #{section_slug} not found."}
      section -> {:ok, section}
    end
  end

  defp fetch_enrollment(%Section{slug: section_slug}, user_id, label) do
    case Sections.get_enrollment(section_slug, user_id, filter_by_status: false) do
      nil ->
        {:error, "#{label} user #{user_id} is not enrolled in section #{section_slug}."}

      enrollment ->
        {:ok, Repo.preload(enrollment, :user)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mb-4 border-l-4 border-red-600 bg-gray-50 p-4 text-gray-800 dark:border-red-500 dark:bg-gray-800 dark:text-gray-100">
      <strong>Warning!</strong>
      This is a developer tool and should only be used by developers.  This can result in data loss.
    </div>

    <div class="mb-4 border-l-4 border-gray-300 bg-gray-50 p-4 text-gray-700 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-300">
      This tool allows you to merge the progress of a source user into a target user enrolled in the same section.
      This is useful in scenarios where a user is incorrectly enrolled in a section from different user accounts, and you want to consolidate their progress.
      Enter the section slug and both user IDs, verify the enrollments, then preview and commit the changes.
    </div>

    <div>
      <.form
        for={@form}
        id="verify_form"
        phx-change="validate"
        phx-submit="verify"
        class="flex flex-col gap-4 md:flex-row md:items-end"
      >
        <div class="flex-1">
          <.input
            field={@form[:section_slug]}
            label="Section Slug"
            label_class="font-semibold"
            class="w-full p-2 border border-gray-300 rounded"
          />
        </div>

        <div class="flex-1">
          <.input
            field={@form[:target_user_id]}
            label="Target User ID"
            label_class="font-semibold"
            class="w-full p-2 border border-gray-300 rounded"
          />
        </div>

        <div class="flex-1">
          <.input
            field={@form[:source_user_id]}
            label="Source User ID"
            label_class="font-semibold"
            class="w-full p-2 border border-gray-300 rounded"
          />
        </div>

        <button
          id="verify_button"
          type="submit"
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Verify
        </button>
      </.form>

      <div :if={@verified} id="verified_users" class="my-4">
        <h3 id="verified_users_heading">
          Verified Users in {@verified.section.title} ({@verified.section.slug})
        </h3>

        <div class="overflow-x-auto">
          <table class="w-full text-left" aria-labelledby="verified_users_heading">
            <thead>
              <tr>
                <th scope="col">ROLE</th>
                <th scope="col">ENROLLMENT ID</th>
                <th scope="col">USER ID</th>
                <th scope="col">NAME</th>
                <th scope="col">EMAIL</th>
                <th scope="col">ENROLLED AT</th>
                <th scope="col">ENROLLMENT STATUS</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={
                  {role, enrollment} <- [
                    {"Target", @verified.target_enrollment},
                    {"Source", @verified.source_enrollment}
                  ]
                }
                id={"verified_#{String.downcase(role)}"}
              >
                <td>{role}</td>
                <td>{enrollment.id}</td>
                <td>{enrollment.user.id}</td>
                <td>{enrollment.user.given_name} {enrollment.user.family_name}</td>
                <td>{enrollment.user.email}</td>
                <td>
                  {FormatDateTime.date(enrollment.inserted_at,
                    ctx: @ctx,
                    precision: :minutes,
                    show_timezone: true
                  )}
                </td>
                <td>{enrollment.status}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-4 flex gap-2">
        <button
          id="preview_button"
          phx-click="preview"
          class="bg-blue-500 enabled:hover:bg-blue-700 text-white font-bold py-2 px-4 rounded disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={is_nil(@verified) or @commit_done}
        >
          Preview Changes
        </button>

        <button
          id="commit_button"
          phx-click="commit"
          class="bg-blue-500 enabled:hover:bg-blue-700 text-white font-bold py-2 px-4 rounded disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={not can_commit?(assigns)}
        >
          <%= if @commit_done do %>
            Done!
          <% else %>
            Commit Changes
          <% end %>
        </button>
      </div>

      <div :if={@true_user} id="preview_changes">
        <h3>Changes</h3>

        <p :if={@changes == [] and not @commit_done}>
          There is no progress to restore for these users.
        </p>

        <div :for={change <- @changes}>{inspect(change)}</div>
      </div>
    </div>
    """
  end

  def handle_event("validate", params, socket) do
    {:noreply,
     socket
     |> assign_form(form_params(params))
     |> reset_verification()}
  end

  def handle_event("verify", params, socket) do
    params = form_params(params)
    socket = socket |> assign_form(params) |> reset_verification()

    case verify_enrollments(
           params["section_slug"],
           params["target_user_id"],
           params["source_user_id"]
         ) do
      {:ok, verified} -> {:noreply, assign(socket, verified: verified)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("preview", _, %{assigns: %{verified: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Verify the users before previewing changes.")}
  end

  def handle_event("preview", _, socket) do
    %{target_enrollment: target_enrollment, source_enrollment: source_enrollment} =
      socket.assigns.verified

    {_all_users, true_user, changes} = preview(target_enrollment, source_enrollment)

    {:noreply,
     socket
     |> clear_flash()
     |> assign(true_user: true_user, changes: changes)}
  end

  def handle_event("commit", _, socket) do
    case commit_blocker(socket.assigns) do
      nil -> {:noreply, commit_changes(socket)}
      reason -> {:noreply, put_flash(socket, :error, reason)}
    end
  end

  defp commit_changes(%{assigns: %{true_user: true_user, changes: changes}} = socket) do
    case Repo.transaction(fn -> process(true_user, changes) end) do
      {:ok, _} ->
        socket
        |> put_flash(:info, "Success: #{length(changes)} change(s) applied.")
        |> assign(changes: [], commit_done: true)

      {_, reason} ->
        Logger.error(
          "Restore user progress commit failed for target user #{true_user.id}: #{inspect(reason)}"
        )

        socket
        |> put_flash(:error, "Failed to restore progress. Check the server logs for details.")
        |> assign(changes: [], commit_done: false)
    end
  end

  defp can_commit?(assigns), do: is_nil(commit_blocker(assigns))

  # Returns the reason why a commit is not allowed in the current state, or nil when it is.
  defp commit_blocker(%{commit_done: true}), do: "Changes have already been committed."
  defp commit_blocker(%{true_user: nil}), do: "Preview changes before committing."
  defp commit_blocker(%{changes: []}), do: "There are no changes to commit."
  defp commit_blocker(_), do: nil

  defp preview(
         %Enrollment{user: true_user} = target_enrollment,
         %Enrollment{user: source_user} = source_enrollment
       ) do
    # The true user is derived from the target enrollment. Additional enrollments
    # represent alternate accounts whose progress we want to merge in.
    all_users =
      [true_user, source_user]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)

    enrollments = Enum.reject([target_enrollment, source_enrollment], &is_nil/1)

    # We process the progress restoration on a per section basis, being careful
    # to only consider the users that are actually enrolled in the section.
    changes =
      Enum.group_by(enrollments, & &1.section_id)
      |> Enum.map(fn {section_id, enrollments_for_section} ->
        # If the true user is not enrolled in the section OR if there is only a single enrollment
        # then there is nothing to restore, as this is likely a previous semester section.
        case Enum.any?(enrollments_for_section, fn e -> e.user_id == true_user.id end) and
               Enum.count(enrollments_for_section) > 1 do
          true ->
            enrolled_user_ids = Enum.map(enrollments_for_section, & &1.user_id) |> MapSet.new()

            enrolled_users =
              Enum.reduce(all_users, [], fn user, acc ->
                if MapSet.member?(enrolled_user_ids, user.id) do
                  [user | acc]
                else
                  acc
                end
              end)

            fetch_resource_accesses(section_id, Enum.map(enrolled_users, & &1.id))
            |> preview_section_changes(true_user)

          false ->
            nil
        end
      end)
      |> List.flatten()
      |> Enum.filter(&(&1 != nil))

    {all_users, true_user, changes}
  end

  defp preview_section_changes(resource_accesses, true_user) do
    Enum.group_by(resource_accesses, & &1.resource_id)
    |> Enum.map(fn {resource_id, resource_accesses} ->
      # Look up in the most recent revision to see if this is graded or practice
      is_graded = is_graded?(resource_id)

      access_for_true = access_for(resource_accesses, true_user)

      other_accesses =
        Enum.filter(resource_accesses, fn ra ->
          is_nil(access_for_true) or ra.id != access_for_true.id
        end)

      # Here now is the core logic for progress restoration.  We handle graded and
      # practice pages differently but both driven from an initial step where we look
      # to see if the true user has a resource access record for this resource.  For graded
      # pages, having a resource access can simply mean that they visited the prologue page - but
      # of course it can also mean that they have completed one or more attempts OR even that
      # they have their first attempt in progress. For practice pages, having a resource access
      # simply means that they have viewed the page.

      if is_graded do
        # Is there a resource access for the true user?
        case access_for_true do
          # Case 1: No access for the true user, so we need to find the most recently scored access
          # and make it the true user's access
          nil ->
            get_most_recently_scored(other_accesses)

          # Case 2: There is an access for the true user, but there isn't a score.  In this case
          # we need to check if another access does have a score and if so, we need to shift
          # the score and all resource attempts to the true user's access record.
          %{score: nil, id: to_shift_to} ->
            case get_most_recently_scored(other_accesses) do
              nil -> nil
              to_shift_from -> {to_shift_from, to_shift_to}
            end

          # Case 3: This must be a case where there is a score on the true user's access
          # so we do nothing
          _ ->
            nil
        end
      else
        most_recent_other_id =
          case other_accesses do
            [] -> nil
            [one | _rest] -> one.id
          end

        # Is there a resource access for the true user?
        case access_for_true do
          # Case 1: No access for the true user, so we take the most recent other access
          nil -> most_recent_other_id
          # Case 2: There is an access for the true user, so we do nothing
          _ -> nil
        end
      end
    end)
  end

  defp process(true_user, changes) do
    Enum.map(changes, fn change ->
      case change do
        {shift_from, shift_to} ->
          # We need to edit the shift_to access score and out_of to match the shift_from
          access_to_edit = Repo.get!(ResourceAccess, shift_to)
          access_to_read = Repo.get!(ResourceAccess, shift_from)

          changeset =
            ResourceAccess.changeset(access_to_edit, %{
              score: access_to_read.score,
              out_of: access_to_read.out_of
            })

          {:ok, _} = Repo.update(changeset)

          # We also need to shift all resource attempts to the shift_to access record BUT only
          # if there are no attempts for the shift_to access record
          if fetch_resource_attempts(shift_to) == [] do
            resource_attempts_from = fetch_resource_attempts(shift_from)

            Enum.map(resource_attempts_from, fn ra ->
              changeset = ResourceAttempt.changeset(ra, %{resource_access_id: shift_to})
              {:ok, _} = Repo.update(changeset)
            end)
          end

        id ->
          access_to_edit = Repo.get!(ResourceAccess, id)
          changeset = ResourceAccess.changeset(access_to_edit, %{user_id: true_user.id})

          {:ok, _} = Repo.update(changeset)
      end
    end)
  end

  defp get_most_recently_scored(resource_accesses) do
    case Enum.filter(resource_accesses, fn ra -> !is_nil(ra.score) end) do
      [] -> nil
      [one | _rest] -> one.id
    end
  end

  defp access_for(resource_accesses, user) do
    Enum.find(resource_accesses, fn ra -> ra.user_id == user.id end)
  end

  defp fetch_resource_accesses(section_id, user_ids) do
    query =
      from ra in ResourceAccess,
        where: ra.section_id == ^section_id and ra.user_id in ^user_ids,
        order_by: [desc: :inserted_at]

    Repo.all(query)
  end

  defp fetch_resource_attempts(resource_access_id) do
    query =
      from ra in ResourceAttempt,
        where: ra.resource_access_id == ^resource_access_id

    Repo.all(query)
  end

  defp is_graded?(resource_id) do
    query =
      from r in Revision,
        where: r.resource_id == ^resource_id,
        limit: 1,
        select: r.graded

    Repo.one(query)
  end
end
