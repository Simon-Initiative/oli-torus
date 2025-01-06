defmodule OliWeb.Admin.RestoreUserProgress do
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
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
       result: "",
       true_user: nil,
       all_users: [],
       changes: []
     )}
  end

  def render(assigns) do
    ~H"""

    <div class="alert alert-danger" role="alert">
      <strong>Warning!</strong> This is a developer tool and should only be used by developers.  This can result in data loss.
    </div>

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

      <div><%= @result %></div>

      <h3>User Records</h3>

      <table>
        <thead>
          <tr>
            <th></th>
            <th>ID</th>
            <th>SUB</th>
            <th>INSTITUTION</th>
            <th>INSERTED</th>
          </tr>
        </thead>
        <tbody>
        <%= for user <- @all_users do %>
          <tr>
            <td><%= if user.id == @true_user.id do "TRUE" else "" end %></td>
            <td><%= user.id %></td>
            <td><%= user.sub %></td>
            <td><%= user.lti_institution_id %></td>
            <td><%= user.inserted_at %></td>
          </tr>
        <% end %>
        </tbody>
      </table>

      <h3>Changes</h3>

      <%= for change <- @changes do %>
        <div><%= inspect(change) %></div>
      <% end %>

    </div>
    """
  end

  def handle_event("email", %{"value" => email}, socket) do
    {:noreply, assign(socket, email: email)}
  end

  def handle_event("preview", _, socket) do

    {all_users, true_user, changes} = preview(socket.assigns.email)
    {:noreply, assign(socket, all_users: all_users, true_user: true_user, changes: changes)}
  end

  def handle_event("commit", _, socket) do

    result = case Repo.transaction(fn -> process(socket.assigns.true_user, socket.assigns.changes) end) do
      {:ok, _} -> "success"
      {_, reason} -> "failed: #{inspect(reason)}"
    end

    {:noreply, assign(socket, changes: [], result: result)}
  end

  defp preview(email) do

    # Get all of the LMS users for this email, sorting so the most recently
    # created user is first. This represents the true user, the user record
    # created at last launch.
    [true_user | rest] = fetch_users(email)
    all_users = [true_user | rest]

    enrollments = Enum.map(all_users, & &1.id) |> fetch_enrollments()

    # We process the progress restoration on a per section basis, being careful
    # to only consider the users that are actually enrolled in the section.
    changes = Enum.group_by(enrollments, & &1.section_id)
    |> Enum.map(fn {section_id, enrollments} ->

      # If the true user is not enrolled in the section OR if there is only a single enrollment
      # then there is nothing to restore, as this is likely a previous semester section.
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

          fetch_resource_accesses(section_id, Enum.map(enrolled_users, & &1.id))
          |> preview_section_changes(true_user)

        false ->
          nil
      end

    end)
    |> List.flatten()
    |> Enum.filter(& &1 != nil)

    {all_users, true_user, changes}

  end

  defp preview_section_changes(resource_accesses, true_user) do

    Enum.group_by(resource_accesses, & &1.resource_id)
    |> Enum.map(fn {resource_id, resource_accesses} ->

      # Look up in the most recent revision to see if this is graded or practice
      is_graded = is_graded?(resource_id)

      access_for_true = access_for(resource_accesses, true_user)
      other_accesses = Enum.filter(resource_accesses, fn ra ->
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
          nil -> get_most_recently_scored(other_accesses)

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
          _ -> nil

        end

      else

        most_recent_other_id = case other_accesses do
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
          changeset = ResourceAccess.changeset(access_to_edit, %{score: access_to_read.score, out_of: access_to_read.out_of})

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

  defp access_for(resource_accesses, user)  do
    Enum.find(resource_accesses, fn ra -> ra.user_id == user.id end)
  end

  defp fetch_users(email) do
    query = from u in User,
      where: u.email == ^email and u.independent_learner == false,
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

  defp fetch_resource_attempts(resource_access_id) do
    query = from ra in ResourceAttempt,
      where: ra.resource_access_id == ^resource_access_id

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
