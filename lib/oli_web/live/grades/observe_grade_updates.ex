defmodule OliWeb.Grades.ObserveGradeUpdatesView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Common.{Breadcrumb, PagedTable}
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias Oli.Delivery.Attempts.PageLifecycle.Broadcaster
  alias OliWeb.Grades.ObserveTableModel

  @retain_count 15

  data retain_count, :integer, default: @retain_count
  data breadcrumbs, :any
  data title, :string, default: "Observe Grade Updates"
  data section, :any, default: nil
  data table_model, :any, default: []
  data updates, :list, default: []
  data total_count, :integer, default: 0

  @spec set_breadcrumbs(:admin | :user, atom | %{:slug => any, optional(any) => any}) :: [...]
  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Observe Grade Updates",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        Broadcaster.subscribe_to_lms_grade_update(section.id)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           table_model: ObserveTableModel.new([]),
           updates: [],
           section: section
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div>
      <PagedTable
        filter={""}
        table_model={@table_model}
        total_count={@total_count}
        offset={0}
        limit={@retain_count}/>
    </div>
    """
  end

  def handle_info({:lms_grade_update_result, payload}, socket) do
    %Oli.Delivery.Attempts.PageLifecycle.GradeUpdatePayload{
      resource_access_id: resource_access_id,
      job: %{attempt: attempt},
      status: status,
      details: details
    } = payload

    # Maintain a FIFO queue of the most recent status changes of grade update jobs

    resource_access = Core.get_resource_access(resource_access_id)

    {_, updates} =
      [
        %{
          status: status,
          details: details,
          attempt: attempt,
          user: resource_access.user.email,
          title:
            Oli.Publishing.DeliveryResolver.from_resource_id(
              resource_access.section.slug,
              resource_access.resource_id
            ).title
        }
        | socket.assigns.updates
      ]
      |> List.pop_at(@retain_count)

    {:ok, table_model} = ObserveTableModel.new(updates)

    {:noreply,
     assign(socket,
       table_model: table_model,
       total_count: Enum.count(updates)
     )}
  end
end
