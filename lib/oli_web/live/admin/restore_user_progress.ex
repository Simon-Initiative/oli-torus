defmodule OliWeb.Admin.RestoreUserProgress do
  use OliWeb, :live_view

  import Ecto.Query
  alias Oli.Repo
  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Resources.Revision

  def mount(_, _, socket) do

    {:ok,
     assign(socket,
       title: "Restore User Progress",
       email: nil,
       true_user: nil,
       changes: []
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <input
        type="text"
        id="email"
        phx-hook="TextInputListener"
        phx-value-change="email"
        class="w-full p-2 border border-gray-300 rounded"/>

      <button phx-click="preview" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
        Preview Changes
      </button>

      <button phx-click="commit" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
        Commit Changes
      </button>

    </div>
    """
  end

  def handle_event("email", %{"value" => email}, socket) do
    {:noreply, assign(socket, email: email)}
  end

  def handle_event("preview", _, socket) do

    {true_user, changes} = preview(socket.email)
    {:noreply, assign(socket, true_user: true_user, changes: changes)}
  end

  def handle_event("commit", _, socket) do

    result = case Repo.transaction(fn -> process(socket.assigns.true_user, socket.assigns.changes) end) do
      {:ok, :ok} -> "success!"
      {_, reason} -> "failed: #{inspect(reason)}"
    end

    {:noreply, assign(socket, changes: [], result: result)}
  end

  defp preview(email) do

    [true_user | rest] = fetch_users(email)
    all_users = [true_user | rest]
    enrollments = fetch_enrollments(all_users)

    changes = Enum.group_by(enrollments, & &1.section_id)
    |> Enum.map(fn {section_id, enrollments} ->

      # If the true user is not enrolled in the section OR if there is a single enrollment
      # there is nothing to restore, as this is likely a previous semester section.
      case Enum.any?(enrollments, fn e -> e.user_id == true_user.id end) and Enum.count(enrollments) > 1 do
        true ->

          enrolled_user_ids = Enum.map(enrollments, & &1.user_id) |> MapSet.new()
          enrolled_users = Enum.reduce(all_users, [], fn user, acc ->
            if MapSet.member?(enrolled_user_ids, user.id) do
              [user | acc]
            else
              acc
            end
          end)

          fetch_resource_accesses(section_id, enrolled_users)
          |> preview_section_changes(true_user)

        false ->
          nil
      end

    end)
    |> List.flatten()
    |> Enum.filter(& &1 != nil)
    |> Enum.sort()

    {true_user, changes}

  end

  defp preview_section_changes(resource_accesses, true_user) do

    Enum.group_by(resource_accesses, & &1.resource_id)
    |> Enum.map(fn {resource_id, resource_accesses} ->
      is_graded = is_graded?(resource_id)

      access_for_true = access_for(resource_accesses, true_user)
      other_accesses = Enum.filter(resource_accesses, fn ra ->
        is_nil(access_for_true) or ra.id != access_for_true.id
      end)

      if is_graded do

        # Is there a resource access for the true user?
        case access_for_true do

          # No access for the true user, so we need to find the most recently scored access
          # and make it the true user's access
          nil -> get_most_recently_scored(other_accesses)

          # There is an access for the true user, but there isn't a score.  In this case
          # we need to find the most recently scored access and make it the true user's access,
          # but we also need to detach the resource access from the true user.  We indicate
          # this detachment action by returning a negative id.
          %{score: nil, id: to_nil} -> [get_most_recently_scored(other_accesses), -to_nil]

          # This must be a case where there is a score on the true user's access
          # we do nothing
          _ -> nil

        end

      else

        most_recent_other_id = case other_accesses do
          [] -> nil
          [one | _rest] -> one.id
        end

        # Is there a resource access for the true user?
        case access_for_true do

          # No access for the true user, so we take the most recent other access
          nil -> most_recent_other_id

          _ -> nil

        end

      end

    end)

  end

  defp process(true_user, changes) do

    Enum.reduce(changes, :ok, fn id, _ ->

      access_to_edit = Repo.get!(ResourceAccess, abs(id))

      changeset = cond do
        id < 0 -> ResourceAccess.changeset(access_to_edit, %{user_id: nil})
        id > 0 -> ResourceAccess.changeset(access_to_edit, %{user_id: true_user.id})
      end

      case Repo.update(changeset) do
        {:ok, _struct} -> {:cont, :ok}
        {:error, e} -> {:halt, e}
      end

    end)

  end

  defp get_most_recently_scored(resource_accesses) do
    case Enum.filter(resource_accesses, fn ra -> !is_nil(ra.score) end) do
      [] -> nil
      [one | _rest] -> one.id
    end
  end

  defp access_for(resource_accesses, user)  do
    Enum.find(resource_accesses, fn ra -> ra.user_id == user.id end)
  end

  defp fetch_users(email) do
    query = from u in User,
      where: u.email == ^email and u.independent_user == false,
      order_by: [desc: :inserted_at]

    Repo.all(query)
  end

  defp fetch_enrollments(user_ids) do
    query = from e in Enrollment,
      where: e.user_id in ^user_ids

    Repo.all(query)
  end

  defp fetch_resource_accesses(section_id, user_ids) do
    query = from ra in ResourceAccess,
      where: ra.section_id == ^section_id and ra.user_id in ^user_ids,
      order_by: [desc: :inserted_at]

    Repo.all(query)
  end

  defp is_graded?(resource_id) do
    query = from r in Revision,
      where: r.resource_id == ^resource_id,
      limit: 1,
      select: r.graded

    Repo.one(query)
  end

end
