defmodule OliWeb.PublisherLive.NewView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, :live}

  alias Oli.Inventories
  alias Oli.Inventories.Publisher
  alias OliWeb.Common.{Breadcrumb, FormContainer, Params}
  alias OliWeb.PublisherLive.{Form, IndexView}
  alias OliWeb.Router.Helpers, as: Routes

  data(title, :string, default: "New Publisher")
  data(publisher, :changeset, default: Inventories.change_publisher(%Publisher{}))
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
        <Form changeset={@publisher} save="save" display_labels={false}/>
      </FormContainer>
    """
  end

  def handle_event("save", %{"publisher" => params}, socket) do
    socket = clear_flash(socket)

    case Inventories.create_publisher(Params.trim(params)) do
      {:ok, _publisher} ->
        {:noreply,
         socket
         |> put_flash(:info, "Publisher successfully created.")
         |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Publisher couldn't be created. Please check the errors below."
          )

        {:noreply, assign(socket, publisher: changeset)}
    end
  end
end
