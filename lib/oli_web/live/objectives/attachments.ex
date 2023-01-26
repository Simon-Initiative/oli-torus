defmodule OliWeb.ObjectivesLive.Attachments do
  use Surface.LiveComponent

  alias OliWeb.Router.Helpers, as: Routes

  data resources_locked, :list, default: []
  data resources_not_locked, :list, default: []

  prop project, :any, required: true
  prop attachment_summary, :any, required: true
  prop locked_by, :any
  prop parent_pages, :list

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

  def render(assigns) do
    ~F"""
    <div id={@id}>
      {#if length(@resources_not_locked) == 0 and length(@resources_locked) == 0}
        <p class="mb-4">Are you sure you want to delete this objective? This action cannot be undone.</p>
      {/if}

      {#if length(@resources_not_locked) > 0}
        <p class="mb-4">Proceeding will automatically remove this objective from the following resources:</p>

        <table class="table table-sm table-bordered">
          <thead class="thead-dark">
            <tr>
              <th>Title</th>
              <th>Resource Type</th>
            </tr>
          </thead>
          <tbody>
            {#for r <- @resources_not_locked}
              <tr>
                <td><a href={link_route(@project.slug, @parent_pages, r.resource_id, r.slug)} target="_blank">{r.title}</a></td>
                <td>{get_type(r)}</td>
              </tr>
            {/for}
          </tbody>
        </table>
      {/if}

      {#if length(@resources_locked) > 0}
        <p class="mb-4">Deleting this objective is <strong>blocked</strong> because the following resources that have this objective
          attached to it are currently being edited:</p>

        <table class="table table-sm table-bordered">
          <thead class="thead-dark">
            <tr>
              <th>Title</th>
              <th>Resource Type</th>
              <th>Edited By</th>
            </tr>
          </thead>
          <tbody>
            {#for r <- @resources_locked}
              <tr>
                <td>
                  <a href={link_route(@project.slug, @parent_pages, r.resource_id, r.slug)} target="_blank">{r.title}</a>
                </td>
                <td>{get_type(r)}</td>
                <td>{locked_by_email(@parent_pages, @locked_by, r.resource_id)}</td>
              </tr>
            {/for}
          </tbody>
        </table>
      {/if}
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
