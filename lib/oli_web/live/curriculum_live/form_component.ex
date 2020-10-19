defmodule OliWeb.Curriculum.FormComponent do
  use OliWeb, :live_component
  alias Oli.Authoring.Editing.ContainerEditor

  alias Oli.TestX

  @impl true
  def update(%{test_xx: test_xx} = assigns, socket) do
    changeset = TestX.change_test_xx(test_xx)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"test_xx" => test_xx_params}, socket) do
    changeset =
      socket.assigns.test_xx
      |> TestX.change_test_xx(test_xx_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"revision" => revision_params}, socket) do
    save_revision(socket, socket.assigns.action, revision_params)
  end

  defp save_revision(socket, :edit, revision_params) do
    case ContainerEditor.edit_page(socket.assigns.project, socket.assigns.revision.slug, revision_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Settings saved")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
