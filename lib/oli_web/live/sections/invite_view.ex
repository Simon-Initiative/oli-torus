defmodule OliWeb.Sections.InviteView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import Oli.Utils.Time

  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Delivery.Sections.SectionInvites
  alias OliWeb.Sections.Invites.Invitation
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Confirm
  alias OliWeb.Sections.Mount

  data breadcrumbs, :any
  data title, :string, default: "Invite Students"
  data section, :any, default: nil
  data show_confirm, :boolean, default: false
  data to_delete, :integer, default: nil

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
           delivery_breadcrumb: true,
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
          <button disabled={is_nil(@section.start_date)} type="button" class="btn btn-secondary" :on-click="new" phx-value-option="section_start">Section start</button>
          <button disabled={is_nil(@section.end_date)} type="button" class="btn btn-secondary" :on-click="new" phx-value-option="section_end">Section end</button>
        </div>
      </div>


    {#if length(@invitations) > 0}
      <div class="list-group">
      {#for invitation <- @invitations}
        <Invitation id={invitation.id} invitation={invitation} delete="request_delete"/>
      {/for}
      </div>
    {/if}

    {#if @show_confirm}
      <Confirm title="Confirm Deletion" id="dialog" ok="delete" cancel="cancel_modal">
        Are you sure that you wish to delete this course section invitation?
      </Confirm>
    {/if}
    </div>
    """
  end

  def handle_event("request_delete", %{"id" => id}, socket) do
    {int_id, _} = Integer.parse(id)
    {:noreply, assign(socket, show_confirm: true, to_delete: int_id)}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("_bsmodal.unmount", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("new", %{"option" => option}, socket) do
    socket = clear_flash(socket)

    socket =
      with true <- socket.assigns.section.registration_open,
           {:ok, invite} <-
             SectionInvites.create_section_invite(%{
               section_id: socket.assigns.section.id,
               date_expires:
                 SectionInvites.expire_after(
                   socket.assigns.section,
                   now(),
                   String.to_existing_atom(option)
                 )
             }) do
        put_flash(
          socket,
          :info,
          "Invitation created: #{Routes.delivery_url(OliWeb.Endpoint, :enroll_independent, invite.slug)}"
        )
      else
        false ->
          put_flash(
            socket,
            :error,
            "Could not create invitation because the registration for the section is not open"
          )

        _ ->
          put_flash(socket, :error, "Could not create invitation")
      end

    {:noreply,
     assign(socket,
       invitations: SectionInvites.list_section_invites(socket.assigns.section.id)
     )}
  end

  def handle_event("delete", _, socket) do
    socket =
      case Enum.find(socket.assigns.invitations, fn i -> i.id == socket.assigns.to_delete end) do
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
