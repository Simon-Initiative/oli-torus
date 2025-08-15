defmodule OliWeb.Attempt.AttemptLive do
  import Ecto.Query, warn: false
  alias Oli.Repo

  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.SortableTable.Table
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias Oli.Delivery.Attempts.PageLifecycle.Broadcaster
  alias OliWeb.Attempt.TableModel
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}

  def set_breadcrumbs(type, section, guid) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section, guid)
  end

  def breadcrumb(previous, section, guid) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Debug Attempt",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug, guid)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug, "attempt_guid" => attempt_guid}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        Broadcaster.subscribe_to_attempt(attempt_guid)

        attempts =
          get_attempts(attempt_guid)
          |> Enum.map(fn a -> Map.put(a, :updated, false) end)

        {:ok, model} = TableModel.new(attempts)
        model = Map.put(model, :rows, attempts)

        {:ok,
         assign(socket,
           attempt_guid: attempt_guid,
           breadcrumbs: set_breadcrumbs(type, section, attempt_guid),
           table_model: model,
           total_count: Enum.count(attempts),
           updates: [],
           section: section,
           attempts: attempts,
           selected: nil,
           content: nil
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: row;">
      <div style="flex-grow: 4;">
        <Table.render model={@table_model} select="select" sort="sort" />
      </div>
      <div style="display: flex; flex-direction: column;">
        <table :if={@selected}>
          <tr>
            <th>Part id</th>
            <th>Attempt#</th>
            <th>State</th>
            <th>Score</th>
            <th>Out of</th>
          </tr>
          <%= for p <- @selected.part_attempts do %>
            <tr>
              <td>{p.part_id}</td>
              <td>{p.attempt_number}</td>
              <td>{p.lifecycle_state}</td>
              <td>{p.score}</td>
              <td>{p.out_of}</td>
            </tr>
          <% end %>
        </table>
        <div style="margin-top: 30px; background: #DDDDDD;">
          <code>
            <pre :if={@content}>
              <%= Jason.encode!(assigns.content, pretty: true) %>
            </pre>
          </code>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("select", %{"id" => id} = _p, socket) do
    {id, _} = Integer.parse(id)

    attempt = Core.get_activity_attempt_by(id: id)

    content =
      case attempt.transformed_model do
        nil -> attempt.revision.content
        _ -> attempt.transformed_model
      end

    table_model = Map.put(socket.assigns.table_model, :selected, id)

    {:noreply,
     assign(socket,
       table_model: table_model,
       content: content,
       selected: Enum.find(socket.assigns.attempts, fn a -> a.id == id end)
     )}
  end

  def handle_info({_, guid}, socket) do
    attempts =
      get_attempts(socket.assigns.attempt_guid)
      |> Enum.map(fn a ->
        case a.attempt_guid do
          ^guid -> Map.put(a, :updated, true)
          _ -> Map.put(a, :updated, false)
        end
      end)

    {:ok, table_model} = TableModel.new(attempts)
    table_model = Map.put(table_model, :rows, attempts)

    {:noreply,
     assign(socket,
       table_model: table_model,
       total_count: Enum.count(attempts)
     )}
  end

  defp get_attempts(resource_attempt_guid) do
    Repo.all(
      from(aa in ActivityAttempt,
        left_join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        left_join: r in Oli.Resources.Revision,
        on: aa.revision_id == r.id,
        where: ra.attempt_guid == ^resource_attempt_guid,
        select_merge: %{
          activity_title: r.title
        },
        preload: [:part_attempts],
        order_by: [:resource_id, :attempt_number]
      )
    )
  end
end
