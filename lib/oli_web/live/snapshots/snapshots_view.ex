defmodule OliWeb.Snapshots.SnapshotsView do
  use OliWeb, :live_view

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Delivery.Snapshots.Snapshot
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Snapshot Records",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        missing = get_missing(section) |> IO.inspect()
        count_missing = Enum.count(missing)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           missing: missing,
           count_missing: count_missing
         )}
    end
  end

  attr :missing, :any, default: []
  attr :section, :any, default: nil
  attr :result, :any, default: nil

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <%= if @count_missing > 0 do %>
        <p>There seems to be <%= @count_missing %> snapshot records.</p>

        <%= if is_nil(@result) do %>
          <button class="btn btn-primary" phx-click="run">Generate Snapshots</button>
        <% else %>
          <%= if @result == :success do %>
            <p><strong>Success!</strong></p>
          <% else %>
            <p><strong>Error!</strong></p>
            <%= Kernel.inspect(@result) %>
          <% end %>
        <% end %>
      <% else %>
        <p>There seems to be no missing snapshot records.</p>
      <% end %>
    </div>
    """
  end

  defp get_missing(section) do
    section_id = section.id

    all_guids =
      from(pa in PartAttempt,
        join: aa in ActivityAttempt,
        on: pa.activity_attempt_id == aa.id,
        join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        join: a in ResourceAccess,
        on: ra.resource_access_id == a.id,
        where: a.section_id == ^section_id and pa.lifecycle_state == :evaluated,
        select: pa.attempt_guid
      )
      |> Repo.all()
      |> MapSet.new()

    all_snapshots =
      from(s in Snapshot,
        join: pa in PartAttempt,
        on: pa.id == s.part_attempt_id,
        where: s.section_id == ^section_id,
        select: pa.attempt_guid
      )
      |> Repo.all()
      |> MapSet.new()

    MapSet.difference(all_guids, all_snapshots) |> MapSet.to_list()
  end

  def handle_event("run", _, socket) do
    case Oli.Delivery.Snapshots.Worker.perform_now(
           socket.assigns.missing,
           socket.assigns.section.slug
         ) do
      {:ok, _} -> {:noreply, assign(socket, missing: [], count_missing: 0, result: :success)}
      {:error, e} -> {:noreply, assign(socket, result: e)}
      e -> {:noreply, assign(socket, result: e)}
    end
  end
end
