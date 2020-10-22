defmodule OliWeb.Curriculum.Settings do
  use OliWeb, :live_component
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources
  alias OliWeb.Curriculum.EntryLive

  @impl true
  def update(%{revision: revision} = assigns, socket) do
    changeset = Resources.change_revision(revision)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"revision" => revision_params}, socket) do
    changeset =
      socket.assigns.revision
      |> Resources.change_revision(revision_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"revision" => revision_params}, socket) do
    save_revision(socket, socket.assigns.action, revision_params)
  end

  def handle_event("delete", %{"slug" => slug}, socket) do
    case ContainerEditor.remove_child(
           socket.assigns.project,
           socket.assigns.author,
           slug
         ) do
      {:ok, _} ->
        {:noreply, push_patch(socket, to: socket.assigns.return_to)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove page")}
    end
  end

  defp save_revision(socket, :edit, revision_params) do
    case ContainerEditor.edit_page(
           socket.assigns.project,
           socket.assigns.revision.slug,
           revision_params
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Settings saved")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp is_disabled(changeset, revision) do
    if !is_nil(changeset.changes[:graded]) do
      !changeset.changes[:graded]
    else
      !revision.graded
    end
  end
end
