defmodule OliWeb.Curriculum.Container do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Course
  alias OliWeb.Curriculum.Entry
  alias OliWeb.Curriculum.Settings
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias Phoenix.PubSub

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))

    {:ok, assign(socket,
      pages: ContainerEditor.list_all_pages(project),
      title: "Curriculum",
      changeset: Resources.change_revision(%Revision{}),
      project: project,
      author: author,
      selected: nil)
    }
  end

  def render(assigns) do

    ~L"""
    <div style="margin: 20px;">

      <div class="container">
        <div class="row">
          <div class="col-12 col-md-8">

            <div class="list-group">
              <%= for {page, index} <- Enum.with_index(@pages) do %>
              <%= live_component @socket, Entry, selected: page == @selected, page: page, index: index, project: @project %>
              <% end %>
            </div>

            <div class="dropdown mt-5">
              <button class="btn btn-secondary dropdown-toggle" type="button"
                id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                Add new
              </button>
              <div class="dropdown-menu" aria-labelledby="dropdownMenuButton">
                <a class="dropdown-item" href="#" phx-click="add" phx-value-type="Unscored">Ungraded Practice Page</a>
                <a class="dropdown-item" href="#" phx-click="add" phx-value-type="Scored">Graded Assessment</a>
              </div>
            </div>

          </div>

          <div class="col-12 col-md-4">
            <%= if @selected != nil do %>
            <%= live_component @socket, Settings, page: @selected, changeset: @changeset %>
            <% end %>
          </div>
        </div>

      </div>

    </div>
    """
  end

  def handle_event("select", %{ "slug" => slug}, socket) do
    selected = Enum.find(socket.assigns.pages, fn r -> r.slug == slug end)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("save", params, socket) do

    socket = case ContainerEditor.edit_page(socket.assigns.project, socket.assigns.selected.slug, params) do
      {:ok, page} -> replace_page_revision(socket, page)
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit page")
    end

    {:noreply, socket}
  end
  
  def handle_event("key", params, socket) do

    socket = case ContainerEditor.edit_page(socket.assigns.project, socket.assigns.selected.slug, params) do
      {:ok, page} -> replace_page_revision(socket, page)
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit page")
    end

    {:noreply, socket}
  end

  def handle_event("delete", _, socket) do

    socket = case ContainerEditor.remove_child(socket.assigns.project, socket.assigns.author, socket.assigns.selected.slug) do
      {:ok, _} -> remove_selected(socket, socket.assigns.selected)
      {:error, _} -> socket
      |> put_flash(:error, "Could not remove page")
    end

    {:noreply, socket}
  end

  def handle_event("add", %{ "type" => type}, socket) do

    attrs = %{
      objectives: %{ "attached" => []},
      children: [],
      content: %{ "model" => []},
      title: if type == "Scored" do "New Assessment" else "New Page" end,
      graded: type == "Scored",
      max_attempts: if type == "Scored" do 5 else 0 end,
      recommended_attempts: if type == "Scored" do 5 else 0 end,
      scoring_strategy_id: ScoringStrategy.get_id_by_type("best"),
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page")
    }

    socket = case ContainerEditor.add_new(attrs, socket.assigns.author, socket.assigns.project) do

      {:ok, _} ->
        assign(socket, :pages, ContainerEditor.list_all_pages(socket.assigns.project))
        |> put_flash(:info, "Page created")

      {:error, %Ecto.Changeset{} = _changeset} ->
        socket
        |> put_flash(:error, "Could not create page")
    end

    {:noreply, socket}
  end


  defp replace_page_revision(socket, revision) do
    index = Enum.find_index(socket.assigns.pages, fn p -> p.resource_id == revision.resource_id end)
    pages = List.replace_at(socket.assigns.pages, index, revision)

    assign(socket, :pages, pages)
    |> assign(:selected, revision)
  end

  defp remove_selected(socket, revision) do
    index = Enum.find_index(socket.assigns.pages, fn p -> p.resource_id == revision.resource_id end)
    pages = List.delete_at(socket.assigns.pages, index)

    selected = cond do
      length(pages) == 0 -> nil
      length(pages) == index -> Enum.at(pages, index - 1)
      true -> Enum.at(pages, index)
    end

    assign(socket, :pages, pages)
    |> assign(:selected, selected)
  end

  def handle_info({:updated, revision}, socket) do

    id = revision.id

    revisions = case socket.assigns.revisions do
      [] -> [revision]
      [%{id: ^id} | rest] -> [revision] ++ rest
      list -> [revision] ++ list
    end

    selected = Enum.find(revisions, fn r -> r.id == socket.assigns.selected.id end)

    {:noreply, assign(socket, selected: selected, revisions: revisions)}
  end


end
