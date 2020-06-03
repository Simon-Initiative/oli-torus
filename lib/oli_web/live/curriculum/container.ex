defmodule OliWeb.Curriculum.Container do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Course
  alias OliWeb.Curriculum.Entry
  alias OliWeb.Curriculum.Settings
  alias Oli.Resources.ScoringStrategy
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias Phoenix.PubSub

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))

    {:ok, assign(socket,
      pages: ContainerEditor.list_all_pages(project),
      title: "Curriculum",
      project: project,
      author: author,
      selected: nil)
    }
  end

  def render(assigns) do

    ~L"""
    <div style="margin: 20px;">

      <div>
        <button class="btn btn-primary m-2" phx-click="add" phx-value-type="Unscored">Add Page</button>
        <button class="btn btn-primary" phx-click="add" phx-value-type="Scored">Add Assessment</button>
      </div>

      <div class="container">
        <div class="row">
          <div class="col-12 col-md-8">
            <p>
              <small>Drag to change the order that content will be presented to students</small>
            </p>

            <div class="list-group">
              <%= for {page, index} <- Enum.with_index(@pages) do %>
              <%= live_component @socket, Entry, selected: page == @selected, page: page, index: index, project: @project %>
              <% end %>
            </div>
          </div>

          <div class="col-12 col-md-4">
            <%= if @selected != nil do %>
            <%= live_component @socket, Settings, page: @selected %>
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
