defmodule OliWeb.Projects.VisibilityLive do
  use Phoenix.LiveView
  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias Oli.Auditing.Context
  alias Oli.Institutions
  alias Oli.Publishing
  use Phoenix.HTML
  alias Phoenix.LiveView.JS

  def mount(
        _params,
        %{
          "project_slug" => project_slug,
          "current_author_id" => current_author_id
        },
        socket
      ) do
    project = Course.get_project_by_slug(project_slug)
    project_visibilities = Publishing.get_all_project_visibilities(project.id)
    current_author = Accounts.get_author!(current_author_id)
    is_admin? = Accounts.is_admin?(current_author)

    {:ok,
     assign(socket,
       project: project,
       project_visibilities: project_visibilities,
       user_emails: [],
       institution_names: [],
       tab: :users,
       is_admin: is_admin?,
       current_author: current_author,
       duplication_revert_count: 0,
       visibility_revert_count: 0
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-12 py-5 border-b dark:border-gray-700">
      <div class="md:col-span-4">
        <h4>Allow Duplication</h4>
        <div class="text-muted">
          Control whether other users can create duplicates of your projects for their own development.
        </div>
      </div>
      <div class="md:col-span-8">
        <form phx-change="duplication" id="duplication_option">
          <%!-- A new id after a failed save renders the inputs again from the saved state --%>
          <div
            class="form-check"
            id={"duplication_inputs-#{@duplication_revert_count}"}
            phx-mounted={@duplication_revert_count > 0 && JS.focus(to: "#dupe_check")}
          >
            <%= label class: "form-check-label" do %>
              {checkbox(:duplication, :allow_duplication,
                id: "dupe_check",
                checked: @project.allow_duplication
              )} Allow duplication by non-collaborators
            <% end %>
          </div>
        </form>
        <div class="alert alert-info mt-5" role="alert">
          <strong>Note:</strong>
          Edits made to duplicates created by other users will not affect your project in any way.
        </div>
      </div>
    </div>
    <div class="grid grid-cols-12 py-5 border-b dark:border-gray-700">
      <div class="md:col-span-4">
        <h4>Publishing Visibility</h4>
        <div class="text-muted">
          Control who can create course sections for this project once it is published.
        </div>
      </div>
      <div class="md:col-span-8">
        <%= if @is_admin do %>
          <form phx-change="option" id="visibility_option">
            <div
              class="form-check"
              id={"visibility_inputs-#{@visibility_revert_count}"}
              phx-mounted={
                @visibility_revert_count > 0 &&
                  JS.focus(to: "#visibility_inputs-#{@visibility_revert_count} input:checked")
              }
            >
              <div class="form-group mb-2">
                <%= label class: "form-check-label flex flex-row cursor-pointer" do %>
                  {radio_button(:visibility, :option, "authors",
                    class: "form-check-input",
                    checked: @project.visibility == :authors or is_nil(@project.visibility)
                  )}
                  <div class="block ml-2">
                    <div class="d-flex align-items-center">
                      <div>Project authors</div>
                      <span class="ml-2 badge badge-xs badge-pill badge-primary">default</span>
                    </div>
                    <small>
                      Only instructors with linked authoring accounts that are project collaborators
                    </small>
                  </div>
                <% end %>
              </div>
              <div class="form-group mb-2">
                <%= label class: "form-check-label flex flex-row cursor-pointer" do %>
                  {radio_button(:visibility, :option, "global",
                    class: "form-check-input",
                    checked: @project.visibility == :global
                  )}
                  <div class="block ml-2">
                    <div>Open</div>
                    <small>Any instructor</small>
                  </div>
                <% end %>
              </div>
              <div class="form-group mb-2">
                <%= label class: "form-check-label flex flex-row cursor-pointer" do %>
                  {radio_button(:visibility, :option, "selected",
                    class: "form-check-input",
                    checked: @project.visibility == :selected
                  )}
                  <div class="block ml-2">
                    <div>Restricted</div>
                    <small>
                      Only instructors with these linked authoring accounts or from these institutions...
                    </small>
                  </div>
                <% end %>
              </div>
            </div>
          </form>
          <%= if @project.visibility == :selected do %>
            <div class="grid grid-cols-12">
              <div class="sm:col-span-12">
                <ul class="nav nav-tabs">
                  <li class="nav-item">
                    <a
                      phx-click="users_tab"
                      class={"nav-link #{if  @tab == :users, do: "active"}"}
                      data-bs-toggle="tab"
                      href="#users"
                    >
                      Authors
                    </a>
                  </li>
                  <li class="nav-item">
                    <a
                      phx-click="institutions_tab"
                      class={"nav-link #{if  @tab == :institutions, do: "active"}"}
                      data-bs-toggle="tab"
                      href="#institutions"
                    >
                      Institutions
                    </a>
                  </li>
                </ul>
                <!-- Tab panes -->
                <div class="tab-content mt-2">
                  <div
                    id="users"
                    class={"container tab-pane pl-0 #{if  @tab == :users, do: "active", else: "fade"}"}
                  >
                    <div>
                      <form phx-change="instructor_search" class="form-inline form-grow">
                        {text_input(:instructor_search_field, :query,
                          placeholder: "Enter an author email here",
                          class: "form-control mb-2 mb-sm-0 title container-fluid flex-fill",
                          autofocus: true,
                          "phx-debounce": "300",
                          autocomplete: "off"
                        )}
                      </form>
                    </div>
                    <div class="grid grid-cols-12 justify-content-center">
                      <%= if !Enum.empty?(@user_emails) do %>
                        <div class="flex-fill">
                          <p>Select from the list below and submit</p>
                          <form phx-submit="selected_email" id="user_submit">
                            {multiple_select(:multi, :emails, @user_emails,
                              class: "form-control w-100"
                            )}
                            {submit("Submit", class: "btn btn-primary")}
                          </form>
                        </div>
                      <% end %>
                      <div class="flex-fill">
                        <ul class="list-group list-group-flush">
                          <%= for v <- @project_visibilities do %>
                            <%= if v.author != nil do %>
                              <li class="list-group-item">
                                <div class="d-flex">
                                  <div class="flex-fill">{v.author.email}</div>
                                  <div>
                                    <button
                                      id={"delete_#{v.visibility.id}"}
                                      phx-click="delete_visibility"
                                      phx-value-id={v.visibility.id}
                                      data-backdrop="static"
                                      data-keyboard="false"
                                      class="ml-1 btn btn-sm btn-danger"
                                    >
                                      <i class="fas fa-trash-alt fa-lg"></i>
                                    </button>
                                  </div>
                                </div>
                              </li>
                            <% end %>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
                  <div
                    id="institutions"
                    class={"container tab-pane pl-0 #{if  @tab == :institutions, do: "active", else: "fade"}"}
                  >
                    <div>
                      <form phx-change="institution_search" class="form-inline form-grow">
                        {text_input(:institution_search_field, :query,
                          placeholder: "Search for institutions by name here",
                          class: "form-control mb-2 mb-sm-0 title container-fluid flex-fill",
                          autofocus: true,
                          "phx-debounce": "300"
                        )}
                      </form>
                    </div>
                    <div class="grid grid-col-12 justify-content-start">
                      <%= if !Enum.empty?(@institution_names) do %>
                        <div class="flex-fill">
                          <p>Select from the list below and submit</p>
                          <form phx-submit="selected_institution" id="institutions_submit">
                            {multiple_select(:multi, :institutions, @institution_names,
                              class: "form-control w-100"
                            )}
                            {submit("Submit", class: "btn btn-primary")}
                          </form>
                        </div>
                      <% end %>
                      <div class="flex-fill">
                        <ul class="list-group list-group-flush">
                          <%= for v <- @project_visibilities do %>
                            <%= if v.institution != nil do %>
                              <li class="list-group-item">
                                <div class="d-flex">
                                  <div class="flex-fill">{v.institution.name}</div>
                                  <div>
                                    <button
                                      id={"delete_#{v.visibility.id}"}
                                      phx-click="delete_visibility"
                                      phx-value-id={v.visibility.id}
                                      data-backdrop="static"
                                      data-keyboard="false"
                                      class="ml-1 btn btn-sm btn-danger"
                                    >
                                      <i class="fas fa-trash-alt fa-lg"></i>
                                    </button>
                                  </div>
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
          <% end %>
        <% else %>
          <p class="mt-3">
            To make this content public in the Torus Course Builder for any instructor to use, please use the Support tool and send us a request.
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event(
        "institution_search",
        %{"institution_search_field" => %{"query" => query}},
        socket
      )
      when query not in [nil, ""] do
    # Only admins can search for institutions to add to visibility restrictions
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      list =
        Institutions.search_institutions_matching(query)
        |> Enum.reduce([], fn institution, acc ->
          {name, id} = {institution.name, institution.id}

          # Check if institution is already in project visibilities
          already_exists =
            Enum.any?(socket.assigns.project_visibilities, fn x ->
              x.institution != nil && x.institution.id == id
            end)

          if !already_exists do
            [{name, id} | acc]
          else
            acc
          end
        end)
        |> Enum.sort()

      {:noreply, assign(socket, :institution_names, list)}
    end
  end

  def handle_event("institution_search", _, socket) do
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :institution_names, [])}
    end
  end

  def handle_event(
        "instructor_search",
        %{"instructor_search_field" => %{"query" => query}},
        socket
      )
      when query not in [nil, ""] do
    # Only admins can search for authors to add to visibility restrictions
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      list =
        Accounts.search_authors_matching(query)
        |> Enum.reduce([], fn author, acc ->
          {email, id} = {author.email, author.id}

          # Check if author is already in project visibilities
          already_exists =
            Enum.any?(socket.assigns.project_visibilities, fn x ->
              x.author != nil && x.author.id == id
            end)

          if !already_exists do
            [{email, id} | acc]
          else
            acc
          end
        end)
        |> Enum.sort()

      {:noreply, assign(socket, :user_emails, list)}
    end
  end

  def handle_event("instructor_search", _, socket) do
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :user_emails, [])}
    end
  end

  def handle_event("option", %{"visibility" => %{"option" => option}}, socket) do
    # Only admins can change project visibility
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      update_setting(socket, %{visibility: option}, :visibility)
    end
  end

  def handle_event("duplication", %{"duplication" => %{"allow_duplication" => value}}, socket) do
    update_setting(socket, %{allow_duplication: value}, :allow_duplication)
  end

  def handle_event("selected_email", %{"multi" => %{"emails" => emails}}, socket) do
    # Only admins can add authors to visibility restrictions
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      grants = Enum.map(emails, fn e -> {:author, elem(Integer.parse(e), 0)} end)

      # The selection is kept when the grants could not be added
      case update_grants(socket, %{add: grants}) do
        {:ok, socket} -> {:noreply, assign(socket, user_emails: [])}
        {:error, socket} -> {:noreply, socket}
      end
    end
  end

  def handle_event(
        "selected_institution",
        %{"multi" => %{"institutions" => institutions}},
        socket
      ) do
    # Only admins can add institutions to visibility restrictions
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      grants = Enum.map(institutions, fn e -> {:institution, elem(Integer.parse(e), 0)} end)

      case update_grants(socket, %{add: grants}) do
        {:ok, socket} -> {:noreply, assign(socket, institution_names: [])}
        {:error, socket} -> {:noreply, socket}
      end
    end
  end

  def handle_event("users_tab", _option, socket) do
    # Only admins can switch between visibility restriction tabs
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :tab, :users)}
    end
  end

  def handle_event("institutions_tab", _option, socket) do
    # Only admins can switch between visibility restriction tabs
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :tab, :institutions)}
    end
  end

  def handle_event("delete_visibility", %{"id" => visibility_id}, socket) do
    # Only admins can remove visibility restrictions
    if !socket.assigns.is_admin do
      {:noreply, socket}
    else
      {id, _} = Integer.parse(visibility_id)

      grants =
        socket.assigns.project_visibilities
        |> Enum.filter(&(&1.visibility != nil && &1.visibility.id == id))
        |> Enum.map(&grant/1)

      {_status, socket} = update_grants(socket, %{remove: grants})
      {:noreply, socket}
    end
  end

  defp grant(%{visibility: %{author_id: id}}) when is_integer(id), do: {:author, id}
  defp grant(%{visibility: %{institution_id: id}}), do: {:institution, id}

  defp update_grants(socket, changes) do
    %{project: project, current_author: author} = socket.assigns
    context = Context.for_actor(author, source: :ui)

    {status, socket} =
      case Oli.Publishing.Audited.update_visibility_grants(context, project.id, changes) do
        {:ok, _grants} ->
          {:ok, socket}

        {:error, _reason} ->
          {:error, flash_error(socket, "The access list could not be updated.")}
      end

    {status,
     assign(socket, project_visibilities: Publishing.get_all_project_visibilities(project.id))}
  end

  defp update_setting(socket, attrs, field) do
    %{project: project, current_author: author} = socket.assigns
    context = Context.for_actor(author, source: :ui)

    case Oli.Authoring.Audited.update_project_settings(context, project.id, attrs, [field]) do
      {:ok, project} ->
        {:noreply, assign(socket, :project, project)}

      {:error, _reason} ->
        socket
        |> flash_error("The setting could not be saved.")
        |> update(revert_key(field), &(&1 + 1))
        |> then(&{:noreply, &1})
    end
  end

  # A failed save renders the control again from the saved value and gives it back the focus
  defp revert_key(:allow_duplication), do: :duplication_revert_count
  defp revert_key(:visibility), do: :visibility_revert_count

  # This view is rendered inside the project overview, which shows its flash messages
  defp flash_error(socket, message) do
    case socket.parent_pid do
      nil ->
        put_flash(socket, :error, message)

      parent ->
        send(parent, {:flash_message, {:error, message}})
        socket
    end
  end
end
