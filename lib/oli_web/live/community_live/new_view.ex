defmodule OliWeb.CommunityLive.NewView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Groups
  alias Oli.Groups.Community
  alias OliWeb.Common.{Breadcrumb, FormContainer, Params}
  alias OliWeb.CommunityLive.{Form, IndexView}
  alias OliWeb.Router.Helpers, as: Routes

  data(title, :string, default: "New Community")
  data(community, :changeset, default: Groups.change_community(%Community{}))
  data(breadcrumbs, :list)

  def breadcrumb() do
    IndexView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "New",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, _, socket) do
    {:ok,
     assign(socket,
       breadcrumbs: breadcrumb()
     )}
  end

  def render(assigns) do
    ~F"""
      <FormContainer title={@title}>
        <Form changeset={@community} save="save" display_labels={false}/>
      </FormContainer>
    """
  end

  def handle_event("save", %{"community" => params}, socket) do
    socket = clear_flash(socket)

    case Groups.create_community(Params.trim(params)) do
      {:ok, _community} ->
        {:noreply,
         socket
         |> put_flash(:info, "Community successfully created.")
         |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Community couldn't be created. Please check the errors below."
          )

        {:noreply, assign(socket, community: changeset)}
    end
  end
end
