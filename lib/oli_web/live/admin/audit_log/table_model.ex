defmodule OliWeb.Admin.AuditLog.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Auditing.LogEvent
  alias OliWeb.Common.FormatDateTime

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(events, ctx) do
    SortableTableModel.new(
      rows: events,
      column_specs: [
        %ColumnSpec{
          name: :inserted_at,
          label: "Timestamp",
          render_fn: &__MODULE__.render_timestamp_column/3
        },
        %ColumnSpec{
          name: :event_type,
          label: "Event Type",
          render_fn: &__MODULE__.render_event_type_column/3
        },
        %ColumnSpec{
          name: :actor,
          label: "Actor",
          render_fn: &__MODULE__.render_actor_column/3
        },
        %ColumnSpec{
          name: :resource,
          label: "Resource",
          render_fn: &__MODULE__.render_resource_column/3
        },
        %ColumnSpec{
          name: :details,
          label: "Details",
          render_fn: &__MODULE__.render_details_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_timestamp_column(assigns, %{inserted_at: inserted_at}, _) do
    assigns = Map.put(assigns, :inserted_at, inserted_at)

    ~H"""
    <div class="text-sm">
      <div class="font-medium text-gray-900 dark:text-gray-100">
        {FormatDateTime.format_datetime(
          @inserted_at,
          show_timezone: true
        )}
      </div>
    </div>
    """
  end

  def render_event_type_column(assigns, event, _) do
    type_class = get_event_type_class(event.event_type)
    description = LogEvent.event_description(event)

    assigns =
      Map.merge(assigns, %{
        event_type: event.event_type,
        type_class: type_class,
        description: description
      })

    ~H"""
    <div>
      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@type_class}"}>
        {@event_type}
      </span>
    </div>
    """
  end

  @doc """
  Displays the acting admin's identity as recorded when an author role changed.
  """
  def render_actor_column(assigns, %{event_type: :author_role_changed} = event, _) do
    assigns = Map.put(assigns, :event, event)

    ~H"""
    <div>
      <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, @event.author_id)}>
        {@event.details["actor_name"]}
      </a>
      <div class="text-xs text-gray-500 dark:text-gray-400">{@event.details["actor_email"]}</div>
    </div>
    """
  end

  def render_actor_column(assigns, event, _) do
    actor_name = LogEvent.actor_name(event)

    actor_type =
      if event.user_id, do: "User", else: if(event.author_id, do: "Author", else: "System")

    assigns =
      Map.merge(assigns, %{
        event: event,
        actor_name: actor_name,
        actor_type: actor_type
      })

    ~H"""
    <div>
      <div class="text-xs text-gray-500 dark:text-gray-400">
        {@actor_type}
        <%= if @event.user_id do %>
          <a
            href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, @event.user_id)}
            class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
          >
            {@actor_name}
          </a>
        <% else %>
          <%= if @event.author_id do %>
            <a
              href={
                Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, @event.author_id)
              }
              class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
            >
              {@actor_name}
            </a>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Displays the affected author for role changes, or the event's project or section.
  """
  def render_resource_column(assigns, %{event_type: :author_role_changed} = event, _) do
    assigns = Map.put(assigns, :event, event)

    ~H"""
    <div>
      <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, @event.resource_id)}>
        {@event.details["author_name"]}
      </a>
      <div class="text-xs text-gray-500 dark:text-gray-400">{@event.details["author_email"]}</div>
    </div>
    """
  end

  def render_resource_column(assigns, event, _) do
    assigns = Map.put(assigns, :event, event)

    ~H"""
    <div>
      <%= cond do %>
        <% @event.project_id && @event.resource -> %>
          <a
            href={
              Routes.live_path(
                OliWeb.Endpoint,
                OliWeb.Workspaces.CourseAuthor.OverviewLive,
                @event.resource.slug
              )
            }
            class="text-blue-600 hover:text-blue-800 text-sm"
          >
            {@event.resource.slug}
          </a>
          <div class="text-xs text-gray-500 dark:text-gray-400">Project</div>
        <% @event.section_id && @event.resource -> %>
          <a
            href={
              Routes.live_path(
                OliWeb.Endpoint,
                OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                @event.resource.slug,
                :overview
              )
            }
            class="text-blue-600 hover:text-blue-800 text-sm"
          >
            {@event.resource.slug}
          </a>
          <div class="text-xs text-gray-500 dark:text-gray-400">Section</div>
        <% true -> %>
          <span class="text-gray-400 dark:text-gray-500 text-sm">—</span>
      <% end %>
    </div>
    """
  end

  @doc """
  Displays audit details with the explicit transition for author role changes.
  """
  def render_details_column(assigns, event, _) do
    details = event.details
    formatted_details = format_details(details)

    assigns =
      assigns
      |> Map.put(:formatted_details, formatted_details)
      |> Map.put(
        :transition,
        case event.event_type do
          :author_role_changed -> LogEvent.event_description(event)
          _ -> nil
        end
      )

    ~H"""
    <div class="max-w-xs">
      <div :if={@transition} class="text-sm font-medium">{@transition}</div>
      <button
        phx-click="show_details"
        phx-value-details={Jason.encode!(@formatted_details)}
        class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
      >
        View Details
      </button>
      <div class="text-xs text-gray-500 dark:text-gray-400 truncate">
        {details_preview(@formatted_details)}
      </div>
    </div>
    """
  end

  defp get_event_type_class(event_type) do
    case event_type do
      t when t in [:user_deleted, :author_deleted] ->
        "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"

      t when t in [:section_created] ->
        "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"

      t when t in [:project_published] ->
        "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"

      _ ->
        "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    end
  end

  defp format_details(details) when is_map(details) do
    details
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new(fn {k, v} -> {k, format_value(v)} end)
  end

  defp format_details(_), do: %{}

  defp format_value(value) when is_map(value), do: Jason.encode!(value, pretty: true)
  defp format_value(value) when is_list(value), do: Jason.encode!(value, pretty: true)
  defp format_value(value), do: to_string(value)

  defp details_preview(details) when map_size(details) == 0, do: "No additional details"

  defp details_preview(details) do
    details
    |> Enum.take(2)
    |> Enum.map(fn {k, _v} -> k end)
    |> Enum.join(", ")
    |> Kernel.<>("...")
  end
end
