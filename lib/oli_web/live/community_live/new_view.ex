defmodule OliWeb.CommunityLive.NewView do
  use OliWeb, :live_view

  alias Oli.Groups
  alias Oli.Groups.Community
  alias OliWeb.Common.{Breadcrumb, FormContainer, Params}
  alias OliWeb.CommunityLive.{Form, IndexView}
  alias OliWeb.Router.Helpers, as: Routes

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
       breadcrumbs: breadcrumb(),
       title: "New Community",
       form: to_form(Groups.change_community(%Community{}))
     )}
  end

  def render(assigns) do
    ~H"""
    <FormContainer.render title={@title}>
      <Form.render form={@form} save="save" display_labels={false} />
    </FormContainer.render>
    """
  end

  def handle_event("save", %{"community" => params}, socket) do
    socket = clear_flash(socket)

    case Groups.create_community(Params.trim(params)) do
      {:ok, _community} ->
        {:noreply,
         socket
         |> put_flash(:info, "Community successfully created.")
         |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, IndexView))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Community couldn't be created. Please check the errors below."
          )

        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
