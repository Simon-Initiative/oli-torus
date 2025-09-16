defmodule OliWeb.ObjectivesLive.Attachments do
  use OliWeb, :live_component

  alias OliWeb.Router.Helpers, as: Routes

  def update(
        %{
          attachment_summary: %{
            attachments: {pages, activities},
            locked_by: locked_by,
            parent_pages: parent_pages
          }
        } = assigns,
        socket
      ) do
    all = pages ++ activities

    is_locked? = fn id ->
      case Map.get(parent_pages, id) do
        nil -> Map.get(locked_by, id) != nil
        %{id: parent_id} -> Map.get(locked_by, parent_id) != nil
      end
    end

    {:ok,
     assign(socket,
       id: assigns.id,
       project: assigns.project,
       parent_pages: parent_pages,
       locked_by: locked_by,
       resources_locked: Enum.filter(all, fn r -> is_locked?.(r.resource_id) end),
       resources_not_locked: Enum.filter(all, fn r -> !is_locked?.(r.resource_id) end)
     )}
  end

  attr(:resources_locked, :list, default: [])
  attr(:resources_not_locked, :list, default: [])
  attr(:id, :string)
  attr(:project, :any, required: true)
  attr(:attachment_summary, :any, required: true)
  attr(:locked_by, :any)
  attr(:parent_pages, :list)

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%= if length(@resources_not_locked) == 0 and length(@resources_locked) == 0 do %>
        <p class="mb-4">
          Are you sure you want to delete this objective? This action cannot be undone.
        </p>
      <% end %>

      <%= if length(@resources_not_locked) > 0 do %>
        <p class="mb-4">
          Proceeding will automatically remove this objective from the following resources:
        </p>

        <table class="table table-sm table-bordered">
          <thead class="thead-dark">
            <tr>
              <th>Title</th>
              <th>Resource Type</th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @resources_not_locked do %>
              <tr>
                <td>
                  <a
                    href={link_route(@project.slug, @parent_pages, r.resource_id, r.slug)}
                    target="_blank"
                  >
                    {r.title}
                  </a>
                </td>
                <td>{get_type(r)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>

      <%= if length(@resources_locked) > 0 do %>
        <p class="mb-4">
          Deleting this objective is <strong>blocked</strong>
          because the following resources that have this objective
          attached to it are currently being edited:
        </p>

        <table class="table table-sm table-bordered">
          <thead class="thead-dark">
            <tr>
              <th>Title</th>
              <th>Resource Type</th>
              <th>Edited By</th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @resources_locked do %>
              <tr>
                <td>
                  <a
                    href={link_route(@project.slug, @parent_pages, r.resource_id, r.slug)}
                    target="_blank"
                  >
                    {r.title}
                  </a>
                </td>
                <td>{get_type(r)}</td>
                <td>{locked_by_email(@parent_pages, @locked_by, r.resource_id)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end

  defp locked_by_email(parent_pages, locked_by, id) do
    case Map.get(parent_pages, id) do
      nil -> Map.get(locked_by, id).author.email
      %{id: parent_id} -> Map.get(locked_by, parent_id).author.email
    end
  end

  defp get_type(r) do
    if Map.get(r, :part) == "attached" do
      "Page"
    else
      "Activity"
    end
  end

  # Helper to formulate link to edit a resource. It is intentional that
  # activities link to the parent page.  That is how the user will gain
  # a lock to be able to then edit an activity.
  defp link_route(project_slug, parent_pages, id, revision_slug) do
    case Map.get(parent_pages, id) do
      nil -> Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, revision_slug)
      %{slug: slug} -> Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, slug)
    end
  end
end
