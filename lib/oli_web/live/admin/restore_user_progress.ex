defmodule OliWeb.Admin.RestoreUserProgress do
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  use OliWeb, :live_view

  import Ecto.Query
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Resources.Revision

  def mount(_, _, socket) do
    {:ok,
     assign(socket,
       title: "Restore User Progress",
       target_enrollment_id: nil,
       source_enrollment_id: nil,
       result: "",
       true_user: nil,
       all_users: [],
       changes: [],
       user_enrollments: %{},
       commit_done: false
     )}
  end

  defp parse_enrollment_id(value) when is_binary(value) do
    case String.trim(value) do
      "" ->
        nil

      trimmed ->
        case Integer.parse(trimmed) do
          {id, ""} -> id
          _ -> nil
        end
    end
  end

  defp parse_enrollment_id(_), do: nil

  defp build_preview(nil, _), do: {:error, "Set a target enrollment ID."}
  defp build_preview(_, nil), do: {:error, "Set a source enrollment ID."}

  defp build_preview(target_enrollment_id, source_enrollment_id) do
    with {:ok, target_enrollment} <- fetch_enrollment_with_user(target_enrollment_id),
         {:ok, source_enrollment} <- fetch_enrollment_with_user(source_enrollment_id),
         :ok <- ensure_same_section(target_enrollment, source_enrollment) do
      {all_users, true_user, changes} = preview(target_enrollment, source_enrollment)

      {:ok,
       %{
         all_users: all_users,
         true_user: true_user,
         changes: changes,
         user_enrollments: build_user_enrollment_map([target_enrollment, source_enrollment])
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_same_section(%Enrollment{section_id: section_id}, %Enrollment{
         section_id: section_id
       }),
       do: :ok

  defp ensure_same_section(_, _),
    do: {:error, "Target and source enrollments must belong to the same section."}

  defp fetch_enrollment_with_user(enrollment_id) do
    case Repo.get(Enrollment, enrollment_id) |> Repo.preload(:user) do
      nil -> {:error, "Enrollment #{enrollment_id} not found."}
      %Enrollment{user: nil} -> {:error, "Enrollment #{enrollment_id} is missing a user."}
      enrollment -> {:ok, enrollment}
    end
  end

  defp build_user_enrollment_map(enrollments) do
    Enum.reduce(enrollments, %{}, fn %Enrollment{id: id, user_id: user_id}, acc ->
      Map.put(acc, user_id, id)
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="alert alert-danger" role="alert">
      <strong>Warning!</strong>
      This is a developer tool and should only be used by developers.  This can result in data loss.
    </div>

    <div class="alert alert-info" role="alert">
      This tool allows you to merge user progress across multiple enrollments into a single, target enrollment.
      This is useful in scenarios where a user is incorrectly enrolled multiple times in a section from different user accounts, and you want to consolidate their progress.
    </div>

    <div>
      <div class="flex flex-col gap-4 md:flex-row">
        <div class="flex-1">
          <label class="block font-semibold" for="target_enrollment_id">Target Enrollment ID</label>
          <input
            type="text"
            id="target_enrollment_id"
            value={@target_enrollment_id || ""}
            phx-hook="TextInputListener"
            phx-value-change="target_enrollment"
            class="w-full p-2 border border-gray-300 rounded"
          />
        </div>

        <div class="flex-1">
          <label class="block font-semibold" for="source_enrollment_id">Source Enrollment ID</label>
          <input
            type="text"
            id="source_enrollment_id"
            value={@source_enrollment_id || ""}
            phx-hook="TextInputListener"
            phx-value-change="source_enrollment"
            class="w-full p-2 border border-gray-300 rounded"
          />
        </div>
      </div>

      <button
        phx-click="preview"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Preview Changes
      </button>

      <button
        phx-click="commit"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded disabled:opacity-50"
        disabled={@commit_done}
      >
        <%= if @commit_done do %>
          Done!
        <% else %>
          Commit Changes
        <% end %>
      </button>

      <div>{@result}</div>

      <h3>User Records</h3>

      <table>
        <thead>
          <tr>
            <th>TARGET</th>
            <th>ENROLLMENT ID</th>
            <th>ID</th>
            <th>GIVEN NAME</th>
            <th>FAMILY NAME</th>
            <th>EMAIL</th>
          </tr>
        </thead>
        <tbody>
          <%= for user <- @all_users do %>
            <tr>
              <td>
                {if user.id == @true_user.id do
                  "TRUE"
                else
                  ""
                end}
              </td>
              <td>{Map.get(@user_enrollments, user.id, "")}</td>
              <td>{user.id}</td>
              <td>{user.given_name}</td>
              <td>{user.family_name}</td>
              <td>{user.email}</td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <h3>Changes</h3>

      <%= for change <- @changes do %>
        <div>{inspect(change)}</div>
      <% end %>
    </div>
    """
  end

  def handle_event("target_enrollment", %{"value" => value}, socket) do
    {:noreply, assign(socket, target_enrollment_id: parse_enrollment_id(value))}
  end

  def handle_event("source_enrollment", %{"value" => value}, socket) do
    {:noreply, assign(socket, source_enrollment_id: parse_enrollment_id(value))}
  end

  def handle_event("preview", _, socket) do
    case build_preview(socket.assigns.target_enrollment_id, socket.assigns.source_enrollment_id) do
      {:ok,
       %{
         all_users: all_users,
         true_user: true_user,
         changes: changes,
         user_enrollments: user_enrollments
       }} ->
        {:noreply,
         assign(socket,
           all_users: all_users,
           true_user: true_user,
           changes: changes,
           user_enrollments: user_enrollments,
           result: ""
         )}

      {:error, reason} ->
        {:noreply,
         assign(socket,
           result: reason,
           changes: [],
           all_users: [],
           true_user: nil,
           user_enrollments: %{}
         )}
    end
  end

  def handle_event("commit", _, socket) do
    if is_nil(socket.assigns.true_user) do
      {:noreply, assign(socket, result: "Preview changes before committing.")}
    else
      case Repo.transaction(fn -> process(socket.assigns.true_user, socket.assigns.changes) end) do
        {:ok, _} ->
          {:noreply,
           assign(socket,
             changes: [],
             result: "success",
             commit_done: true
           )}

        {_, reason} ->
          {:noreply,
           assign(socket,
             changes: [],
             result: "failed: #{inspect(reason)}",
             commit_done: false
           )}
      end
    end
  end

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
