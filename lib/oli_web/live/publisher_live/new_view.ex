defmodule OliWeb.PublisherLive.NewView do
  use OliWeb, :live_view

  alias Oli.Inventories
  alias Oli.Inventories.Publisher
  alias OliWeb.Common.{Breadcrumb, FormContainer, Params}
  alias OliWeb.PublisherLive.{Form, IndexView}
  alias OliWeb.Router.Helpers, as: Routes

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

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

  attr(:title, :string, default: "New Publisher")
  attr(:publisher, :any, default: Inventories.change_publisher(%Publisher{}))
  attr(:breadcrumbs, :list)

  def render(assigns) do
    ~H"""
    <FormContainer.render title={@title}>
      <Form.render changeset={@publisher} save="save" display_labels={false} />
    </FormContainer.render>
    """
  end

  def handle_event("save", %{"publisher" => params}, socket) do
    socket = clear_flash(socket)

    case Inventories.create_publisher(Params.trim(params)) do
      {:ok, _publisher} ->
        {:noreply,
         socket
         |> put_flash(:info, "Publisher successfully created.")
         |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, IndexView))}

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
