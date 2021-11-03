defmodule OliWeb.CommunityLive.New do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Groups
  alias Oli.Groups.Community
  alias OliWeb.Common.{Breadcrumb, FormContainerComponent}
  alias OliWeb.CommunityLive.Index
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, ErrorTag, Field, Label, TextArea, TextInput}

  data title, :string, default: "New Community"
  data community, :changeset, default: Community.changeset(%Community{})
  data breadcrumbs, :any

  def breadcrumb() do
    Index.breadcrumb() ++
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
      <FormContainerComponent title={@title}>
        <Form for={@community} submit="save">
          <Field name={:name} class="form-group">
            <TextInput class="form-control" opts={placeholder: "Name"}/>
            <ErrorTag class="text-danger"/>
          </Field>

          <Field name={:description} class="form-group">
            <TextArea class="form-control" rows="4" opts={placeholder: "Description"}/>
          </Field>

          <Field name={:key_contact} class="form-group">
            <TextInput class="form-control" opts={placeholder: "Key Contact"}/>
          </Field>

          <Field name={:global_access} class="form-check">
            <Checkbox class="form-check-input"/>
            <Label class="form-check-label" text="Access to Global Project or Products"/>
          </Field>

          <button class="btn btn-md btn-primary btn-block mt-3" type="submit">Create</button>
        </Form>
      </FormContainerComponent>
    """
  end

  def handle_event("save", %{"community" => params}, socket) do
    case Groups.create_community(params) do
      {:ok, _community} ->
        socket = put_flash(socket, :info, "Community succesfully created.")
        {:noreply, assign(socket, community: Community.changeset(%Community{}))}

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
