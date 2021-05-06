defmodule OliWeb.OpenAndFree.SectionForm do
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  import Phoenix.HTML.Link
  import Oli.Utils
  import OliWeb.ErrorHelpers
  alias Oli.Predefined
  alias Oli.Authoring.Course
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Branding

  @impl true
  def mount(_params, session, socket) do
    %{
      "changeset" => changeset,
      "action" => action,
      "submit_text" => submit_text,
      "cancel" => cancel
    } = session

    available_brands =
      Branding.list_brands()
      |> Enum.map(fn brand -> {brand.name, brand.id} end)

    socket =
      socket
      |> assign(:timezones, Predefined.timezones())
      |> assign(:available_brands, available_brands)
      |> assign(:action, action)
      |> assign(:submit_text, submit_text)
      |> assign(:cancel, cancel)
      |> assign(:changeset, changeset)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= form_for @changeset, @action, fn f -> %>
      <%= if @changeset.action do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <% end %>

      <%= if @action == Routes.open_and_free_path(@socket, :create) do %>
        <div id="projects-typeahead" class="form-label-group"
          phx-hook="ProjectsTypeahead"
          phx-update="ignore">
          <%= text_input f, :project_name, class: "project-name typeahead form-control " <> error_class(f, :project_id, "is-invalid"),
            placeholder: "Project", required: true, autofocus: focusHelper(f, :project_name, default: true), autocomplete: "off" %>
          <%= label f, :project_name, "Project", class: "control-label" %>
          <%= error_tag f, :project_id %>

          <%= hidden_input f, :project_slug, value: "" %>
        </div>
      <% end %>

      <div class="form-label-group">
        <%= text_input f, :title, class: "title form-control " <> error_class(f, :title, "is-invalid"),
          placeholder: "Title", required: true, autofocus: focusHelper(f, :title) %>
        <%= label f, :title, class: "control-label" %>
        <%= error_tag f, :title %>
      </div>

      <div class="form-row">
        <div class="form-label-group col-md-6">
          <%= text_input f, :start_date, class: "form-control " <> error_class(f, :start_date, "is-invalid"),
            autofocus: focusHelper(f, :start_date) %>
          <%= label f, :start_date, "Start Date", class: "control-label" %>
          <%= error_tag f, :start_date %>
        </div>
        <div class="form-label-group col-md-6">
          <%= text_input f, :end_date, class: "form-control " <> error_class(f, :end_date, "is-invalid"),
            autofocus: focusHelper(f, :end_date) %>
          <%= label f, :end_date, "End Date", class: "control-label" %>
          <%= error_tag f, :end_date %>
        </div>
      </div>

      <script>
        $(function() {
          $('#section_start_date, #section_end_date').datepicker({
            format: "yyyy-mm-dd",
            todayBtn: "linked",
            todayHighlight: true,
            orientation: "bottom",
          });
        });
      </script>

      <div class="text-secondary my-1">Time Zone</div>
      <div class="form-label-group">
        <%= select f, :time_zone, @timezones, prompt: "Select Timezone", class: "form-control " <> error_class(f, :time_zone, "is-invalid"),
          required: true, autofocus: focusHelper(f, :time_zone) %>
        <%= error_tag f, :time_zone %>
      </div>

      <div class="text-secondary my-2">Brand</div>
      <div class="form-label-group">
        <%= select f, :brand_id, @available_brands, prompt: "Select Brand", class: "form-control " <> error_class(f, :brand_id, "is-invalid"),
          autofocus: focusHelper(f, :brand_id) %>
        <%= error_tag f, :brand_id %>
      </div>

      <div class="form-row d-flex flex-row px-1 my-4">
        <div class="flex-grow-1 mr-2">
          Registration Availability
        </div>

        <div class="custom-control custom-switch" style="width: 88px;">
          <%= checkbox f, :registration_open, class: "custom-control-input" <> error_class(f, :registration_open, "is-invalid"), autofocus: focusHelper(f, :registration_open) %>
          <%= label f, :registration_open, "Open", class: "custom-control-label" %>
          <%= error_tag f, :registration_open %>
        </div>

        <script>
          $('#section_registration_open').change(function() {
            console.log(this)
            $('label[for="section_registration_open"]').text(this.checked ? 'Open' : 'Closed');
          });
        </script>
      </div>

      <div>
        <%= submit value_or(assigns[:submit_text], "Save"), class: "submit btn btn-md btn-primary btn-block" %>
        <%= if assigns[:cancel], do:
          link "Cancel", to: assigns[:cancel], class: "btn btn-md btn-outline-secondary btn-block mt-3"
        %>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    projects = Course.search_published_projects(search)

    {:noreply, push_event(socket, "projects", %{projects: projects})}
  end
end
