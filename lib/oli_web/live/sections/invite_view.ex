defmodule OliWeb.Sections.InviteView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Delivery.Sections.SectionInvites
  alias OliWeb.Sections.Invites.Invitation
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  import Oli.Utils.Time

  data breadcrumbs, :any
  data title, :string, default: "Invite Students"
  data section, :any, default: nil

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Invite Students",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           invitations: SectionInvites.list_section_invites(section.id)
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div>

      <div class="mb-5">
        Create new invite link expiring after:
        <div class="btn-group" role="group">
          <button type="button" class="btn btn-secondary" :on-click="new" phx-value-option="one_day">One day</button>
          <button type="button" class="btn btn-secondary" :on-click="new" phx-value-option="one_week">One week</button>
          <button type="button" class="btn btn-secondary" :on-click="new" phx-value-option="section_start">Section start</button>
          <button type="button" class="btn btn-secondary" :on-click="new" phx-value-option="section_end">Section end</button>
        </div>
      </div>


    {#if length(@invitations) > 0}
      <div class="list-group">
      {#for invitation <- @invitations}
        <Invitation invitation={invitation} delete="delete"/>
      {/for}
      </div>
    {/if}
    </div>
    """
  end

  def handle_event("new", %{"option" => option}, socket) do
    socket =
      case SectionInvites.create_section_invite(%{
             section_id: socket.assigns.section.id,
             date_expires: SectionInvites.expire_after(now(), String.to_existing_atom(option))
           }) do
        {:ok, _} -> put_flash(socket, :info, "Invitation deleted")
        _ -> put_flash(socket, :error, "Could not create invitation")
      end

    {:noreply,
     assign(socket,
       invitations: SectionInvites.list_section_invites(socket.assigns.section.id)
     )}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {int_id, _} = Integer.parse(id)

    socket =
      case Enum.find(socket.assigns.invitations, fn i -> i.id == int_id end) do
        nil ->
          socket

        invite ->
          case Oli.Repo.delete(invite) do
            {:ok, _} -> put_flash(socket, :info, "Invitation deleted")
            _ -> put_flash(socket, :error, "Could not delete invitation")
          end
      end

    {:noreply,
     assign(socket,
       invitations: SectionInvites.list_section_invites(socket.assigns.section.id)
     )}
  end
end
