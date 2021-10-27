defmodule OliWeb.CommunityLive.Show do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Groups
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.CommunityLive.{FormComponent, Index}
  alias OliWeb.Router.Helpers, as: Routes

  data(title, :string, default: "Edit Community")
  data(community, :struct)
  data(changeset, :changeset)
  data(breadcrumbs, :list)

  def breadcrumb(community_id) do
    Index.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Overview",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, community_id)
        })
      ]
  end

  def mount(%{"community_id" => community_id}, _session, socket) do
    socket =
      case Groups.get_community(community_id) do
        nil ->
          socket
          |> put_flash(:info, "That community does not exist.")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, Index))

        community ->
          changeset = Groups.change_community(community)

          assign(socket,
            community: community,
            changeset: changeset,
            breadcrumbs: breadcrumb(community_id)
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
      <div id="community-overview" class="overview container">
        <div class="row py-5 border-bottom">
          <div class="col-md-4">
            <h4>Details</h4>
            <div class="text-muted">Main community fields that will be shown to system admins and community admins.</div>
          </div>
          <div class="col-md-8">
            <FormComponent changeset={@changeset} save="save"/>
          </div>
        </div>
      </div>
    """
  end

  def handle_event("save", %{"community" => params}, socket) do
    case Groups.update_community(socket.assigns.community, params) do
      {:ok, community} ->
        socket = put_flash(socket, :info, "Community successfully updated.")

        {:noreply,
         assign(socket, community: community, changeset: Groups.change_community(community))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Community couldn't be updated. Please check the errors below."
          )

        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
