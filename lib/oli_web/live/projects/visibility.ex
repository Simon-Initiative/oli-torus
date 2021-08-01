defmodule OliWeb.Projects.VisibilityLive do
  use Phoenix.LiveView
  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias Oli.Institutions
  alias Oli.Publishing
  use Phoenix.HTML

  def mount(
        _params,
        %{
          "project_slug" => project_slug
        },
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)
    project_visibilities = Publishing.get_all_project_visibilities(project.id)

    {:ok,
     assign(socket,
       project: project,
       project_visibilities: project_visibilities,
       user_emails: [],
       institution_names: [],
       tab: :users
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="col-md-4">
        <h4>Publishing Visibility</h4>
        <small>Control who can create course sections for this project once it is published.</small>
      </div>
      <div class="col-md-8">
        <form phx-change="option" id="visibility_option">
          <div class="form-check form-switch">
            <div class="form-group">
              <%= label class: "form-check-label" do %>
                <%= radio_button :visibility, :option, "authors", class: "form-check-input", checked: @project.visibility == :authors or is_nil(@project.visibility) %>
                <p>Project authors (default)</p>
                <small>Only authors added as collaborators to this project</small>
              <% end %>
            </div>
            <div class="form-group">
              <%= label class: "form-check-label" do %>
                <%= radio_button :visibility, :option, "global", class: "form-check-input", checked: @project.visibility == :global %>
                <p>Open</p>
                <small>Any user who links their account to Proton as an instructor</small>
              <% end %>
            </div>
            <div class="form-group">
              <%= label class: "form-check-label" do %>
                <%= radio_button :visibility, :option, "selected", class: "form-check-input", checked:  @project.visibility == :selected %>
                <p>Restricted</p>
                <small>Only these users or institutions...</small>
              <% end %>
            </div>
          </div>
        </form>
        <%= if @project.visibility == :selected do %>
        <div class="row">
          <div class="col-sm-8">
            <ul class="nav nav-tabs">
              <li class="nav-item">
                <a phx-click="users_tab" class="nav-link <%= if  @tab == :users, do: "active" %>"
                                    data-toggle="tab" href="#users">Users</a>
              </li>
              <li class="nav-item">
                <a phx-click="institutions_tab" class="nav-link <%= if  @tab == :institutions, do: "active" %>"
                                    data-toggle="tab" href="#institutions">Institutions</a>
              </li>
            </ul>
            <!-- Tab panes -->
            <div class="tab-content">
              <div id="users" class="container tab-pane <%= if  @tab == :users, do: "active", else: "fade" %>">
                <div class="card">
                  <div>
                    <form phx-change="search" class="form-inline form-grow">
                      <%= text_input :search_field, :query, placeholder: "Search for users by email here",
                                class: "form-control form-control-sm mb-2 mb-sm-0 title container-fluid flex-fill",
                                autofocus: true, "phx-debounce": "300" %>
                      <%= hidden_input :search_field, :entity, value: "instructors" %>
                    </form>
                  </div>
                  <div class="row justify-content-center">
                    <%= if !Enum.empty?(@user_emails) do %>
                      <div class="flex-fill">
                        <p>Select from the list below and submit</p>
                        <form phx-submit="selected_email" id="user_submit">
                          <%= multiple_select :multi, :emails, @user_emails, class: "form-control w-100" %>
                          <%= submit "Submit", class: "btn btn-primary" %>
                        </form>
                      </div>
                    <% end %>
                    <div class="flex-fill">
                      <ul class="list-group list-group-flush">
                        <%= for v <- @project_visibilities do %>
                          <%= if v.author != nil do %>
                            <li class="list-group-item">
                              <div class="d-flex">
                                <div class="flex-fill"><%= v.author.email %>
                                </div>
                                <div>
                                  <button id="delete_<%= v.visibility.id %>"
                                                phx-click="delete_visibility"
                                                phx-value-id="<%= v.visibility.id %>" data-backdrop="static"
                                                data-keyboard="false" class="ml-1 btn btn-sm btn-danger">
                                    <i class="fas fa-trash-alt fa-lg"></i>
                                  </button></div>
                              </div>
                            </li>
                          <% end %>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
              <div id="institutions"
                                class="container tab-pane <%= if  @tab == :institutions, do: "active", else: "fade" %>">
                <div class="card">
                  <div>
                    <form phx-change="search" class="form-inline form-grow">
                      <%= text_input :search_field, :query, placeholder: "Search for institutions by name here",
                                class: "form-control form-control-sm mb-2 mb-sm-0 title container-fluid flex-fill",
                                autofocus: true, "phx-debounce": "300" %>
                      <%= hidden_input :search_field, :entity, value: "institution" %>
                    </form>
                  </div>
                  <div class="row justify-content-center">
                    <%= if !Enum.empty?(@institution_names) do %>
                      <div class="flex-fill">
                        <p>Select from the list below and submit</p>
                        <form phx-submit="selected_institution" id="institutions_submit">
                          <%= multiple_select :multi, :institutions, @institution_names , class: "form-control w-100" %>
                          <%= submit "Submit", class: "btn btn-primary" %>
                        </form>
                      </div>
                    <% end %>
                    <div class="flex-fill">
                      <ul class="list-group list-group-flush">
                        <%= for v <- @project_visibilities do %>
                          <%= if v.institution != nil do %>
                            <li class="list-group-item">
                              <div class="d-flex">
                                <div class="flex-fill"><%= v.institution.name %></div>
                                <div>
                                  <button id="delete_<%= v.visibility.id %>"
                                                phx-click="delete_visibility"
                                                phx-value-id="<%= v.visibility.id %>" data-backdrop="static"
                                                data-keyboard="false" class="ml-1 btn btn-sm btn-danger">
                                    <i class="fas fa-trash-alt fa-lg"></i>
                                  </button></div>
                              </div>
                            </li>
                          <% end %>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      </div>
    </div>
    """
  end

  def handle_event("search", %{"search_field" => %{"entity" => entity, "query" => query}}, socket) do
    case entity do
      "instructors" ->
        list =
          if String.length(query) > 1 do
            Accounts.search_authors_matching(query)
          else
            []
          end

        list = Enum.map(list, fn a -> {a.email, a.id} end) |> Enum.sort_by(& &1)

        list =
          list
          |> Enum.filter(fn e ->
            {_, id} = e

            f =
              Enum.find(socket.assigns.project_visibilities, fn x ->
                x.author != nil && x.author.id == id
              end)

            if f == nil do
              true
            else
              false
            end
          end)

        {:noreply, assign(socket, :user_emails, list)}

      "institution" ->
        list =
          if String.length(query) > 1 do
            Institutions.search_institutions_matching(query)
          else
            []
          end

        list = Enum.map(list, fn a -> {a.name, a.id} end) |> Enum.sort_by(& &1)

        list =
          list
          |> Enum.filter(fn e ->
            {_, id} = e

            f =
              Enum.find(socket.assigns.project_visibilities, fn x ->
                x.institution != nil && x.institution.id == id
              end)

            if f == nil do
              true
            else
              false
            end
          end)

        {:noreply, assign(socket, :institution_names, list)}
    end
  end

  def handle_event("option", %{"visibility" => %{"option" => option}}, socket) do
    {:ok, project} = Course.update_project(socket.assigns.project, %{visibility: option})
    {:noreply, assign(socket, :project, project)}
  end

  def handle_event("selected_email", %{"multi" => %{"emails" => emails}}, socket) do
    emails
    |> Enum.each(fn e ->
      {id, _} = Integer.parse(e)

      f =
        Enum.find(socket.assigns.project_visibilities, fn x ->
          x.author != nil && x.author.id == id
        end)

      if f == nil do
        Publishing.insert_visibility(%{project_id: socket.assigns.project.id, author_id: id})
      end
    end)

    project_visibilities = Publishing.get_all_project_visibilities(socket.assigns.project.id)
    {:noreply, assign(socket, project_visibilities: project_visibilities, user_emails: [])}
  end

  def handle_event(
        "selected_institution",
        %{"multi" => %{"institutions" => institutions}},
        socket
      ) do
    institutions
    |> Enum.each(fn e ->
      {id, _} = Integer.parse(e)

      f =
        Enum.find(socket.assigns.project_visibilities, fn x ->
          x.institution != nil && x.institution.id == id
        end)

      if f == nil do
        Publishing.insert_visibility(%{project_id: socket.assigns.project.id, institution_id: id})
      end
    end)

    project_visibilities = Publishing.get_all_project_visibilities(socket.assigns.project.id)
    {:noreply, assign(socket, project_visibilities: project_visibilities, institution_names: [])}
  end

  def handle_event("users_tab", _option, socket) do
    {:noreply, assign(socket, :tab, :users)}
  end

  def handle_event("institutions_tab", _option, socket) do
    {:noreply, assign(socket, :tab, :institutions)}
  end

  def handle_event("delete_visibility", %{"id" => visibility_id}, socket) do
    {id, _} = Integer.parse(visibility_id)

    v =
      Enum.find(socket.assigns.project_visibilities, fn x ->
        x.visibility != nil && x.visibility.id == id
      end)

    if v != nil do
      Publishing.remove_visibility(v.visibility)
    end

    project_visibilities = Publishing.get_all_project_visibilities(socket.assigns.project.id)
    {:noreply, assign(socket, project_visibilities: project_visibilities)}
  end
end
