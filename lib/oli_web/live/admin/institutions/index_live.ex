defmodule OliWeb.Admin.Institutions.IndexLive do
  use OliWeb, :live_view

  alias Oli.Institutions
  alias Oli.Predefined
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  def mount(_params, session, socket) do
    institutions = Institutions.list_institutions()

    socket =
      assign(
        socket,
        institutions: institutions,
        pending_registrations: Institutions.list_pending_registrations(),
        breadcrumbs: root_breadcrumbs(),
        country_codes: Predefined.country_codes(),
        lti_config_defaults: Predefined.lti_config_defaults(),
        world_universities_and_domains: Predefined.world_universities_and_domains(),
        ctx: OliWeb.Common.SessionContext.init(socket, session),
        selected_pending_registration: nil,
        active_tab: :institutions_tab
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <ul class="nav nav-tabs mb-3" id="institutions_tab" role="tablist">
        <li class="nav-item">
          <b
            phx-click="change_active_tab"
            phx-value-tab="institutions_tab"
            class={["nav-link", "#{if @active_tab == :institutions_tab, do: "active"}"]}
            id="institutions_tab"
            role="tab"
            aria-controls="institutions"
            aria-selected={"#{@active_tab == :institutions_tab}"}
          >
            Institutions
          </b>
        </li>
        <li class="nav-item">
          <b
            phx-click="change_active_tab"
            phx-value-tab="pending_registrations_tab"
            class={["nav-link", "#{if @active_tab == :pending_registrations_tab, do: "active"}"]}
            id="pending_registrations_tab"
            role="tab"
            aria-controls="pending_registrations"
            aria-selected={"#{@active_tab == :pending_registrations_tab}"}
          >
            Pending Registrations
            <%= case Enum.count(@pending_registrations) do %>
              <% 0 -> %>
                <span class="badge badge-pill badge-secondary">0</span>
              <% count -> %>
                <span class="badge badge-pill badge-primary"><%= count %></span>
            <% end %>
          </b>
        </li>
      </ul>
      <div class="tab-content">
        <div
          :if={@active_tab == :institutions_tab}
          id="institutions"
          role="tabpanel"
          aria-labelledby="institutions_tab"
        >
          <div class="d-flex flex-row mb-2">
            <div class="flex-grow-1"></div>
            <div>
              <%= link("New Institution",
                to: Routes.institution_path(OliWeb.Endpoint, :new),
                class: "btn btn-md btn-outline-primary"
              ) %>
            </div>
          </div>

          <%= if Enum.count(@institutions) == 0 do %>
            <div class="my-5 text-center">
              There are no registered institutions
            </div>
          <% else %>
            <table class="table table-striped table-bordered">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Country Code</th>
                  <th>Email</th>
                  <th>URL</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for institution <- @institutions do %>
                  <tr>
                    <td>
                      <%= link(institution.name,
                        to:
                          Routes.live_path(
                            OliWeb.Endpoint,
                            OliWeb.Admin.Institutions.SectionsAndStudentsView,
                            institution.id,
                            :sections
                          )
                      ) %>
                    </td>
                    <td><%= institution.country_code %></td>
                    <td><%= institution.institution_email %></td>
                    <td><%= institution.institution_url %></td>

                    <td class="text-nowrap">
                      <%= link("Details",
                        to: Routes.institution_path(OliWeb.Endpoint, :show, institution),
                        class: "btn btn-sm btn-outline-primary"
                      ) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
        <div
          :if={@active_tab == :pending_registrations_tab}
          id="pending_registrations"
          role="tabpanel"
          aria-labelledby="pending_registrations_tab"
        >
          <%= if Enum.count(@pending_registrations) == 0 do %>
            <div class="my-5 text-center">
              There are no pending registrations
            </div>
          <% else %>
            <table class="table table-striped table-bordered">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>URL</th>
                  <th>Contact Email</th>
                  <th>When</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                <%= for pending_registration <- @pending_registrations do %>
                  <tr>
                    <td><%= pending_registration.name %></td>
                    <td><%= pending_registration.institution_url %></td>
                    <td><%= pending_registration.institution_email %></td>
                    <td>
                      <%= OliWeb.Common.Utils.render_date(pending_registration, :inserted_at, @ctx) %>
                    </td>

                    <td class="text-nowrap">
                      <button
                        class="btn btn-sm btn-outline-primary ml-2"
                        phx-click={
                          JS.push("select_pending_registration",
                            value: %{registration_id: pending_registration.id}
                          )
                          |> Modal.show_modal("review-registration-modal")
                        }
                      >
                        Review
                      </button>
                      <%= link("Decline",
                        to:
                          Routes.institution_path(
                            OliWeb.Endpoint,
                            :remove_registration,
                            pending_registration
                          ),
                        method: :delete,
                        data: [
                          confirm:
                            "Are you sure you want to decline this request from \"#{pending_registration.name}\"?"
                        ],
                        class: "btn btn-sm btn-outline-danger ml-2"
                      ) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>
    </div>

    <Modal.modal class="w-5/6" id="review-registration-modal">
      <:title>Review Registration</:title>
      <div :if={@selected_pending_registration}>
        <%= form_for Oli.Institutions.change_pending_registration(@selected_pending_registration), Routes.institution_path(OliWeb.Endpoint, :approve_registration), fn f -> %>
          <%= hidden_input(f, :id) %>
          <div class="box-form-container">
            <div class="grid grid-cols-12">
              <div class="form-group col-span-12 lg:col-span-6 lg:pr-3">
                <h6>Institution Details</h6>

                <div class="form-label-group">
                  <%= text_input(f, :name,
                    class:
                      "institution-name typeahead form-control " <>
                        error_class(f, :name, "is-invalid"),
                    placeholder: "Institution Name",
                    required: true
                  ) %>
                  <%= label(f, :name, "Institution Name", class: "control-label") %>
                  <%= error_tag(f, :name) %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :institution_url,
                    class:
                      "institution-url form-control " <>
                        error_class(f, :institution_url, "is-invalid"),
                    placeholder: "Institution URL",
                    required: true
                  ) %>
                  <%= label(f, :institution_url, "Institution URL") %>
                  <%= error_tag(f, :institution_url) %>
                </div>

                <div id="create-new-msg" class="mb-3 px-2" style="display: none">
                  <div class="text-success">
                    A <b>new</b> institution will be created for this registration.
                  </div>
                  <div class="text-dark">
                    To create a registration for an existing institution, the <b>Institution URL</b>
                    must match an existing institution.
                  </div>
                </div>

                <div id="use-existing-msg" class="mb-3 px-2" style="display: none">
                  <div class="text-primary">
                    An <b>existing</b> institution will be used for this registration:
                  </div>
                  <div class="my-2">
                    <input
                      type="text"
                      id="use-existing-name"
                      class="form-control text-primary"
                      readonly
                    />
                  </div>
                  <div class="text-dark">
                    To create a new institution for this registration, the <b>Institution URL</b>
                    must be different from an existing institution.
                  </div>
                </div>

                <div id="institution-details">
                  <div class="form-label-group">
                    <%= email_input(f, :institution_email,
                      class:
                        "email form-control " <>
                          error_class(f, :institution_email, "is-invalid"),
                      placeholder: "Contact Email",
                      required: true
                    ) %>
                    <%= label(f, :institution_email, "Contact Email", class: "control-label") %>
                    <%= error_tag(f, :institution_email) %>
                  </div>

                  <div class="form-label-group">
                    <%= select(f, :country_code, @country_codes,
                      prompt: "Select Country",
                      class: "form-control " <> error_class(f, :country_code, "is-invalid"),
                      required: true
                    ) %>
                    <%= error_tag(f, :country_code) %>
                  </div>
                </div>
              </div>

              <div class="form-group col-span-12 lg:col-span-5 lg:border-l lg:pl-3">
                <hr class="mb-4 lg:hidden border-top" />

                <h6>LTI 1.3 Configuration</h6>

                <div class="form-label-group">
                  <%= text_input(f, :issuer, class: "form-control ", readonly: true) %>
                  <%= label(f, :issuer, "Issuer", class: "control-label") %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :client_id, class: "form-control ", readonly: true) %>
                  <%= label(f, :client_id, "Client ID", class: "control-label") %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :deployment_id, class: "form-control ", readonly: true) %>
                  <%= label(f, :deployment_id, "Deployment ID", class: "control-label") %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :key_set_url,
                    class: "key_set_url form-control " <> error_class(f, :key_set_url, "is-invalid"),
                    placeholder: "Keyset URL",
                    required: true
                  ) %>
                  <%= label(f, :key_set_url, "Keyset URL", class: "control-label") %>
                  <%= error_tag(f, :key_set_url) %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :auth_token_url,
                    class:
                      "auth_token_url form-control " <>
                        error_class(f, :auth_token_url, "is-invalid"),
                    placeholder: "Auth Token URL",
                    required: true
                  ) %>
                  <%= label(f, :auth_token_url, "Auth Token URL", class: "control-label") %>
                  <%= error_tag(f, :auth_token_url) %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :auth_login_url,
                    class:
                      "auth_login_url form-control " <>
                        error_class(f, :auth_login_url, "is-invalid"),
                    placeholder: "Auth Login URL",
                    required: true
                  ) %>
                  <%= label(f, :auth_login_url, "Auth Login URL", class: "control-label") %>
                  <%= error_tag(f, :auth_login_url) %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :auth_server,
                    class: "auth_server form-control " <> error_class(f, :auth_server, "is-invalid"),
                    placeholder: "Auth Server URL",
                    required: true
                  ) %>
                  <%= label(f, :auth_server, "Auth Server URL", class: "control-label") %>
                  <%= error_tag(f, :auth_server) %>
                </div>

                <div class="form-label-group">
                  <%= text_input(f, :line_items_service_domain,
                    class:
                      "line_items_service_domain form-control " <>
                        error_class(f, :line_items_service_domain, "is-invalid"),
                    placeholder: "Line items service domain"
                  ) %>
                  <%= label(f, :line_items_service_domain, "Line items service domain",
                    class: "control-label"
                  ) %>
                  <%= error_tag(f, :line_items_service_domain) %>
                </div>
              </div>
            </div>
          </div>
          <div class="flex justify-end border-0">
            <button type="button" class="btn btn-secondary mr-2">
              Cancel
            </button>
            <%= submit("Approve", class: "submit btn btn-success") %>
          </div>
        <% end %>
      </div>
    </Modal.modal>
    """
  end

  def handle_event("change_active_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle_event("select_pending_registration", %{"registration_id" => registration_id}, socket) do
    {:noreply,
     assign(
       socket,
       :selected_pending_registration,
       Enum.find(
         socket.assigns.pending_registrations |> IO.inspect(),
         &(&1.id == registration_id)
       )
     )}
  end

  defp root_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Institutions",
          link: Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.Institutions.IndexLive)
        })
      ]
  end
end
