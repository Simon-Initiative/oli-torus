defmodule OliWeb.Workspaces.CourseAuthor.Activities.ActivityReviewLive do
  use OliWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project

    {:ok,
     assign(socket,
       resource_slug: project.slug,
       resource_title: project.title,
       scripts: Oli.Activities.get_activity_scripts()
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-8">
      <%= for script <- @scripts do %>
        <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/#{script}")}>
        </script>
      <% end %>

      <small>Enter your local path for the SVN source</small>
      <input type="text" id="local" />

      <hr />

      <h3 id="title"></h3>
      <h4 id="slug"></h4>
      <div id="history"></div>
      <div id="svn"></div>
      <div id="vscode"></div>
      <div id="reference"></div>

      <div
        id="container"
        style="padding: 20px; border: 2px inset rgba(28,110,164,0.17); border-radius: 12px; margin-top: 30px;"
      >
      </div>

      <script>
        const bc = new BroadcastChannel('activity_selected');
        bc.onmessage = (event) => {
        document.getElementById('container').innerHTML = event.data.rendered;
        document.getElementById('title').innerHTML = event.data.title;
        document.getElementById('slug').innerHTML = event.data.slug;
        document.getElementById('svn').innerHTML =`View SVN: <a href="${event.data.svn_path}" target="editor">${event.data.svn_path}</a>`;

        const root = document.getElementById('local').value;
        document.getElementById('vscode').innerHTML =`View in VSCode: <a href="vscode://file/${root}/${event.data.svn_relative_path}" target="editor">vscode://file/${root}/${event.data.svn_relative_path}</a>`;

        document.getElementById('history').innerHTML =`Edit History: <a href="${event.data.history}" target="editor">${event.data.history}</a>`;
        document.getElementById('reference').innerHTML =
        event.data.reference === null
        ? ""
        : `Edit Page: <a href="${event.data.reference}" target="editor">${event.data.reference}</a>`;

        }
      </script>
    </div>
    """
  end
end
