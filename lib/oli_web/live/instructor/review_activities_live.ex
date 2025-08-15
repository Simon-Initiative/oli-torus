defmodule OliWeb.Instructor.ReviewActivitiesLive do
  @moduledoc """
  LiveView for instructors to review and enable/disable activity bank activities.
  """

  use OliWeb, :live_view

  alias Oli.Delivery.BlacklistedActivities
  alias Oli.Activities.Realizer.Selection
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.BankEntry
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Activities
  alias Oli.Resources.ResourceType
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Paging
  alias OliWeb.Router.Helpers, as: Routes
  import Ecto.Query, warn: false
  alias Oli.Repo

  @impl Phoenix.LiveView
  def mount(%{"page_id" => page_id, "selection_id" => selection_id}, _session, socket) do
    section = socket.assigns.section

    case load_selection_and_activities(section, page_id, selection_id) do
      {:ok, selection, activities, revision} ->
        blacklisted_ids =
          BlacklistedActivities.get_blacklisted_activity_ids(section.id, selection.id)

        activity_types = Activities.list_activity_registrations()
        activity_types_map = Enum.reduce(activity_types, %{}, fn e, m -> Map.put(m, e.id, e) end)

        # Get additional scripts for rendering activities
        part_components = Oli.PartComponents.get_part_component_scripts(:delivery_script)

        additional_scripts =
          Enum.map(activity_types, fn a -> a.authoring_script end) |> Enum.concat(part_components)

        # Initialize paging
        limit = 10
        offset = 0
        total_count = length(activities)
        paged_activities = Enum.slice(activities, offset, limit)

        {:ok,
         assign(socket,
           section: section,
           page_id: page_id,
           selection_id: selection_id,
           selection: selection,
           activities: activities,
           paged_activities: paged_activities,
           paging: %{offset: offset, limit: limit, total: total_count},
           blacklisted_ids: MapSet.new(blacklisted_ids),
           selected_activity: nil,
           rendered_activity: nil,
           can_disable?: true,
           count_disabled: Enum.count(blacklisted_ids),
           total_count: total_count,
           activity_types_map: activity_types_map,
           additional_scripts: additional_scripts,
           revision: revision,
           breadcrumbs: set_breadcrumbs(section, revision)
         )
         |> update_can_disable()}

      {:error, reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Failed to load selection: #{reason}")
         |> redirect(to: Routes.page_delivery_path(socket, :page, section.slug, page_id))}
    end
  end

  # We only allow the user to disable (i.e. blacklist) activities
  # if the number of availalbe (non-blacklisted) activities exceeds the selection count.
  defp update_can_disable(socket) do
    available_count =
      Enum.count(socket.assigns.activities) - MapSet.size(socket.assigns.blacklisted_ids)

    assign(socket, can_disable?: available_count > socket.assigns.selection.count)
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_blacklist", _, socket) do
    activity_id = socket.assigns.selected_activity.resource_id
    section = socket.assigns.section

    case BlacklistedActivities.toggle_blacklist(
           section.id,
           socket.assigns.selection.id,
           activity_id
         ) do
      {:ok, :added} ->
        {:noreply,
         assign(socket,
           count_disabled: socket.assigns.count_disabled + 1,
           blacklisted_ids: MapSet.put(socket.assigns.blacklisted_ids, activity_id)
         )
         |> update_can_disable()}

      {:ok, :removed} ->
        {:noreply,
         assign(socket,
           count_disabled: socket.assigns.count_disabled - 1,
           blacklisted_ids: MapSet.delete(socket.assigns.blacklisted_ids, activity_id)
         )
         |> update_can_disable()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update blacklist")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("select_activity", %{"activity_id" => activity_id}, socket) do
    activity_id = String.to_integer(activity_id)

    activity =
      Enum.find(socket.assigns.activities, fn a -> a.resource_id == activity_id end)

    if activity do
      rendered = render_activity(activity, socket.assigns)

      {:noreply,
       assign(socket,
         selected_activity: activity,
         rendered_activity: rendered
       )}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("paged", %{"offset" => offset, "limit" => limit}, socket) do
    offset = String.to_integer(offset)
    limit = String.to_integer(limit)

    paged_activities = Enum.slice(socket.assigns.activities, offset, limit)

    {:noreply,
     assign(socket,
       selected_activity: nil,
       paged_activities: paged_activities,
       paging: %{
         offset: offset,
         limit: limit,
         total: socket.assigns.total_count
       }
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <%= for script <- @additional_scripts do %>
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}>
      </script>
    <% end %>
    <div class="container mt-4">
      <div class="card mb-3">
        <div class="card-body">
          <p class="card-text">
            This activity bank selection needs to select <strong>{@selection.count}</strong>
            {if @selection.count > 1, do: "activities", else: "activity"} from the follwing bank of
            <strong>{@total_count}</strong> {if @total_count > 1 do
              "activities"
            else
              "activity"
            end},
            with {if @count_disabled == 0 do
              "no"
            else
              @count_disabled
            end} {if @count_disabled == 1 do
              "activity"
            else
              "activities"
            end} currently excluded.
          </p>

          <p class="card-text mt-4">
            <%= if @can_disable? do %>
              The activities in the bank are listed below. You can select an activity to see its details and exclude it by unchecking it.
            <% else %>
              <span class="alert-warning p-2 rounded-sm">
                You cannot disable any more activities, as the number of available activities is already at the selection count.
              </span>
            <% end %>
          </p>
        </div>
      </div>

      <div class="flex">
        <div class="basis-1/3">
          <table>
            <thead>
              <tr>
                <th>Activity</th>
              </tr>
            </thead>
            <tbody>
              <%= for activity <- @paged_activities do %>
                <tr
                  class={"#{if @selected_activity && @selected_activity.resource_id == activity.resource_id, do: "bg-indigo-100 dark:bg-gray-700", else: ""}"}
                  phx-click="select_activity"
                  phx-value-activity_id={activity.resource_id}
                  style="cursor: pointer;"
                >
                  <td>
                    <input
                      type="checkbox"
                      disabled={
                        !@can_disable? and !MapSet.member?(@blacklisted_ids, activity.resource_id)
                      }
                      checked={!MapSet.member?(@blacklisted_ids, activity.resource_id)}
                      id={"blacklist-checkbox-#{activity.resource_id}"}
                      phx-hook="CheckboxListener"
                      phx-value-change="toggle_blacklist"
                      phx-value-activity_id={activity.resource_id}
                    />
                    {activity.stem}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>

          <Paging.render
            id="paging"
            offset={@paging.offset}
            limit={@paging.limit}
            total_count={@paging.total}
            click="paged"
          />
        </div>
        <div class="basis-2/3 m-2">
          <%= if @selected_activity do %>
            <div class="rendered-activity" id={@selected_activity.resource_id |> Integer.to_string()}>
              {raw(@rendered_activity)}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_selection_and_activities(section, page_slug, selection_id) do
    # Get the published revision for the page
    case DeliveryResolver.from_revision_slug(section.slug, page_slug) do
      nil ->
        {:error, "Page not found"}

      revision ->
        # Parse the content to find the selection
        case find_selection_in_content(revision.content, selection_id) do
          nil ->
            {:error, "Selection not found"}

          selection_json ->
            # Parse the selection
            case Selection.parse(selection_json) do
              {:ok, selection} ->
                # Get all activities that match the selection logic
                publication_id =
                  Oli.Publishing.get_publication_id_for_resource(
                    section.slug,
                    revision.resource_id
                  )

                # Populate the bank activities
                activity_type_id = ResourceType.id_for_activity()

                bank_entries =
                  from(r in Oli.Resources.Revision,
                    join: pr in Oli.Publishing.PublishedResource,
                    on: pr.revision_id == r.id,
                    where: pr.publication_id == ^publication_id,
                    where: r.deleted == false,
                    where: r.resource_type_id == ^activity_type_id,
                    where: r.scope == :banked,
                    select: %{
                      resource_id: pr.resource_id,
                      tags: r.tags,
                      objectives: r.objectives,
                      activity_type_id: r.activity_type_id
                    }
                  )
                  |> Repo.all()
                  |> Enum.map(&BankEntry.from_map/1)

                source = %Source{
                  section_slug: section.slug,
                  publication_id: publication_id,
                  bank: bank_entries,
                  blacklisted_activity_ids: []
                }

                original_selection = selection
                selection = %{selection | count: length(bank_entries)}

                # Use fulfill_from_bank to get matching activities
                {bank_entries_matched, _count} = Selection.fulfill_from_bank(selection, source)

                # Now fetch the full revisions for the matched activities
                activity_ids = Enum.map(bank_entries_matched, & &1.resource_id)

                entry_by_id =
                  Enum.into(bank_entries_matched, %{}, fn be -> {be.resource_id, be} end)

                activities =
                  if length(activity_ids) > 0 do
                    DeliveryResolver.from_resource_id(section.slug, activity_ids)
                    |> Enum.map(fn revision ->
                      # Add the BankEntry data to the revision for display
                      bank_entry = Map.get(entry_by_id, revision.resource_id)

                      revision =
                        Map.merge(revision, %{
                          tags: bank_entry.tags,
                          objectives: bank_entry.objectives,
                          activity_type_id: bank_entry.activity_type_id,
                          transformed_model: revision.content
                        })

                      Map.put(revision, :stem, get_activity_stem(revision))
                    end)
                  else
                    []
                  end

                {:ok, original_selection, activities, revision}

              {:error, reason} ->
                {:error, reason}
            end
        end
    end
  end

  defp find_selection_in_content(%{"model" => model}, selection_id) do
    find_selection_in_model(model, selection_id)
  end

  defp find_selection_in_content(_, _), do: nil

  defp find_selection_in_model(model, selection_id) when is_list(model) do
    Enum.find_value(model, fn item ->
      find_selection_in_item(item, selection_id)
    end)
  end

  defp find_selection_in_model(_, _), do: nil

  defp find_selection_in_item(%{"type" => "selection", "id" => id} = selection, selection_id)
       when id == selection_id do
    selection
  end

  defp find_selection_in_item(%{"type" => "group", "children" => children}, selection_id) do
    find_selection_in_model(children, selection_id)
  end

  defp find_selection_in_item(
         %{"type" => "activity-reference", "children" => children},
         selection_id
       ) do
    find_selection_in_model(children, selection_id)
  end

  defp find_selection_in_item(_, _), do: nil

  defp render_activity(activity, assigns) do
    activity_type = Map.get(assigns.activity_types_map, activity.activity_type_id)

    if activity_type do
      tag = activity_type.authoring_element
      model = Jason.encode!(activity.transformed_model)

      """
      <#{tag}
        model='#{model}'
        editmode="false"
        projectSlug="#{assigns.section.slug}">
      </#{tag}>
      """
    else
      "<div>Unable to render activity</div>"
    end
  end

  defp get_activity_stem(activity) do
    case activity.transformed_model do
      %{"stem" => %{"content" => content}} ->
        extract_text_from_content(content) |> truncate(100)

      %{"authoring" => %{"previewText" => preview}} when is_binary(preview) ->
        preview

      _ ->
        "No preview available"
    end
  end

  defp extract_text_from_content(content) when is_list(content) do
    content
    |> Enum.map(&extract_text_from_item/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp extract_text_from_content(_), do: ""

  defp extract_text_from_item(%{"type" => "p", "children" => children}) do
    extract_text_from_content(children)
  end

  defp extract_text_from_item(%{"text" => text}) when is_binary(text), do: text
  defp extract_text_from_item(_), do: ""

  defp truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp set_breadcrumbs(section, revision) do
    [
      Breadcrumb.new(%{
        full_title: revision.title,
        link: Routes.page_delivery_path(OliWeb.Endpoint, :page, section.slug, revision.slug)
      }),
      Breadcrumb.new(%{
        full_title: "Review Activities",
        link: nil
      })
    ]
  end
end
