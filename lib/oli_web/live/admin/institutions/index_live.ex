defmodule OliWeb.Admin.Institutions.IndexLive do
  use OliWeb, :live_view
  require Logger

  alias Oli.Institutions
  alias Oli.Predefined
  alias Oli.Slack

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Modal

  alias Phoenix.LiveView.JS

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_params, _session, socket) do
    institutions = Institutions.list_institutions()

    socket =
      assign(
        socket,
        institutions: institutions,
        institutions_list: [{"New institution", nil} | Enum.map(institutions, &{&1.name, &1.id})],
        pending_registrations: Institutions.list_pending_registrations(),
        breadcrumbs: root_breadcrumbs(),
        country_codes: Predefined.country_codes(),
        registration_changeset: nil,
        institution_id: nil,
        form_disabled?: false,
        active_tab: :institutions_tab
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <ul class="nav nav-tabs" role="tablist">
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
      <div>
        <div
          :if={@active_tab == :institutions_tab}
          id="institutions"
          role="tabpanel"
          aria-labelledby="institutions_tab"
          class="flex flex-col gap-2"
        >
          <%= link("New Institution",
            to: Routes.institution_path(OliWeb.Endpoint, :new),
            class: "btn btn-md btn-outline-primary self-end"
          ) %>

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
                <tr :for={institution <- @institutions}>
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
                <tr :for={pending_registration <- @pending_registrations}>
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
                          value: %{registration_id: pending_registration.id, action: "review"}
                        )
                        |> Modal.show_modal("review-registration-modal")
                      }
                    >
                      Review
                    </button>
                    <button
                      class="btn btn-sm btn-outline-danger ml-2"
                      phx-click={
                        JS.push("select_pending_registration",
                          value: %{registration_id: pending_registration.id, action: "decline"}
                        )
                        |> Modal.show_modal("decline-registration-modal")
                      }
                    >
                      Decline
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>
    </div>

    <Modal.modal class="w-5/6" id="decline-registration-modal">
      <:title>Decline Registration</:title>
      <div
        data-hide_modal={Modal.hide_modal("decline-registration-modal")}
        id="decline-registration-modal-trigger"
      />
      <div :if={@registration_changeset} class="contents">
        <p>
          Are you sure you want to decline this request from "<%= @registration_changeset.name %>"?
        </p>
        <div :if={@registration_changeset} class="flex justify-end border-0">
          <button
            phx-click={Modal.hide_modal("decline-registration-modal")}
            type="button"
            class="btn btn-secondary mr-2"
          >
            Cancel
          </button>
          <button
            phx-click="decline_registration"
            phx-value-registration_id={@registration_changeset.data.id}
            type="button"
            class="submit btn btn-danger"
          >
            Confirm
          </button>
        </div>
      </div>
    </Modal.modal>

    <Modal.modal class="w-5/6" id="review-registration-modal">
      <:title>Review Registration</:title>
      <div
        data-hide_modal={Modal.hide_modal("review-registration-modal")}
        id="review-registration-modal-trigger"
      />
      <div :if={@registration_changeset} class="contents">
        <div>
          <.form for={@registration_changeset} phx-submit="save_registration">
            <div class="box-form-container">
              <div class="flex flex-col md:flex-row gap-2 md:gap-4 justify-between">
                <div class="form-group flex-1">
                  <h6 class="mb-2">Institution Details</h6>

                  <.input
                    variant="outlined"
                    phx-change="select_existing_institution"
                    type="select"
                    options={@institutions_list}
                    field={@registration_changeset[:institution_id]}
                    value={@institution_id}
                    label="Select Institution"
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    readonly={@form_disabled?}
                    field={@registration_changeset[:name]}
                    label="Institution Name"
                    required
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    readonly={@form_disabled?}
                    field={@registration_changeset[:institution_url]}
                    label="Institution URL"
                    required
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    readonly={@form_disabled?}
                    field={@registration_changeset[:institution_email]}
                    label="Contact Email"
                    required
                  />
                  <.input
                    variant="outlined"
                    class="disabled:bg-gray-100"
                    disabled={@form_disabled?}
                    type="select"
                    options={@country_codes}
                    field={@registration_changeset[:country_code]}
                    label="Select Country"
                    required
                  />
                </div>

                <hr class="block md:hidden mb-6" />

                <div class="form-group flex-1">
                  <h6 class="mb-2">LTI 1.3 Configuration</h6>

                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:issuer]}
                    label="Issuer"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:client_id]}
                    label="Client ID"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:deployment_id]}
                    label="Deployment ID"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:key_set_url]}
                    label="Keyset URL"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:auth_token_url]}
                    label="Auth Token URL"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:auth_login_url]}
                    label="Auth Login URL"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:auth_server]}
                    label="Auth Server URL"
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:line_items_service_domain]}
                    label="Line items service domain"
                    readonly
                  />
                </div>
              </div>
            </div>

            <div class="flex justify-end border-0">
              <button
                phx-click={Modal.hide_modal("review-registration-modal")}
                type="button"
                class="btn btn-secondary mr-2"
              >
                Cancel
              </button>
              <button type="submit" class="submit btn btn-success">
                Approve
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Modal.modal>
    """
  end

  def handle_event("change_active_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle_event(
        "select_existing_institution",
        %{"registration" => %{"institution_id" => ""}},
        socket
      ) do
    registration_changeset =
      Enum.find(
        socket.assigns.pending_registrations,
        &(&1.id == socket.assigns.registration_changeset.data.id)
      )
      |> Oli.Institutions.change_pending_registration()
      |> to_form(as: "registration")

    {:noreply,
     assign(socket, registration_changeset: registration_changeset, form_disabled?: false)}
  end

  def handle_event(
        "select_existing_institution",
        %{"registration" => %{"institution_id" => institution_id}},
        socket
      ) do
    institution_id = String.to_integer(institution_id)
    institution = Enum.find(socket.assigns.institutions, &(&1.id == institution_id))

    registration_changeset =
      Enum.find(
        socket.assigns.pending_registrations,
        &(&1.id == socket.assigns.registration_changeset.data.id)
      )
      |> Map.merge(
        Map.take(institution, [:name, :institution_url, :institution_email, :country_code])
      )
      |> Oli.Institutions.change_pending_registration()
      |> to_form(as: "registration")

    {:noreply,
     assign(socket, registration_changeset: registration_changeset, form_disabled?: true)}
  end

  def handle_event(
        "select_pending_registration",
        %{"registration_id" => registration_id, "action" => "decline"},
        socket
      ) do
    selected_registration =
      Enum.find(
        socket.assigns.pending_registrations,
        &(&1.id == registration_id)
      )

    {:noreply,
     assign(
       socket,
       registration_changeset:
         selected_registration |> Oli.Institutions.change_pending_registration() |> to_form()
     )}
  end

  def handle_event(
        "select_pending_registration",
        %{"registration_id" => registration_id, "action" => "review"},
        socket
      ) do
    selected_registration =
      Enum.find(
        socket.assigns.pending_registrations,
        &(&1.id == registration_id)
      )

    matching_institution =
      Enum.find(
        socket.assigns.institutions,
        &(&1.institution_url == selected_registration.institution_url)
      )

    # If there's already an institution with that url, suggest it as the institution that will be
    # related to the registration
    {registration_changeset, institution_id} =
      if matching_institution do
        {selected_registration
         |> Map.merge(
           Map.take(matching_institution, [
             :name,
             :institution_url,
             :institution_email,
             :country_code
           ])
         )
         |> Oli.Institutions.change_pending_registration()
         |> to_form(as: "registration"), matching_institution.id}
      else
        {selected_registration
         |> Oli.Institutions.change_pending_registration()
         |> to_form(as: "registration"), nil}
      end

    {:noreply,
     assign(
       socket,
       registration_changeset: registration_changeset,
       institution_id: institution_id,
       form_disabled?: !is_nil(institution_id)
     )}
  end

  def handle_event("save_registration", %{"registration" => registration}, socket) do
    issuer = registration["issuer"]
    client_id = registration["client_id"]

    # handle the case where deployment_id is nil in the html form, causing this attr
    # to be and empty string
    deployment_id =
      case registration["deployment_id"] do
        "" -> nil
        deployment_id -> deployment_id
      end

    socket =
      case Institutions.get_pending_registration(issuer, client_id, deployment_id) do
        nil ->
          socket
          |> put_flash(
            :error,
            "Pending registration with issuer '#{issuer}', client_id '#{client_id}' and deployment_id '#{deployment_id}' does not exist"
          )

        pending_registration ->
          with {:ok, pending_registration} <-
                 Institutions.update_pending_registration(
                   pending_registration,
                   registration
                 ),
               {:ok, {institution, registration, _deployment}} <-
                 approve_pending_registration(
                   registration["institution_id"],
                   pending_registration
                 ) do
            registration_approved_email =
              Oli.Email.create_email(
                institution.institution_email,
                "Registration Approved",
                "registration_approved.html",
                %{institution: institution, registration: registration}
              )

            Oli.Mailer.deliver(registration_approved_email)

            # send a Slack notification regarding the new registration approval
            approving_admin = socket.assigns[:current_author]

            Slack.send(%{
              "username" => approving_admin.name,
              "icon_emoji" => ":robot_face:",
              "blocks" => [
                %{
                  "type" => "section",
                  "text" => %{
                    "type" => "mrkdwn",
                    "text" =>
                      "Registration request for *#{pending_registration.name}* has been approved."
                  }
                }
              ]
            })

            socket
            |> assign(
              pending_registrations:
                Enum.filter(
                  socket.assigns.pending_registrations,
                  &(&1.id != pending_registration.id)
                ),
              institutions: Institutions.list_institutions()
            )
            |> put_flash(:info, [
              "Registration for ",
              content_tag(:b, pending_registration.name),
              " approved"
            ])
          else
            error ->
              Logger.error("Failed to approve registration request", error)

              socket
              |> put_flash(
                :error,
                "Failed to approve registration. Please double check your entries and try again."
              )
          end
      end

    {:noreply,
     push_event(socket, "js-exec", %{
       to: "#review-registration-modal-trigger",
       attr: "data-hide_modal"
     })}
  end

  def handle_event("decline_registration", %{"registration_id" => registration_id}, socket) do
    registration_id = String.to_integer(registration_id)

    pending_registration =
      Enum.find(
        socket.assigns.pending_registrations,
        &(&1.id == registration_id)
      )

    {:ok, _pending_registration} = Institutions.delete_pending_registration(pending_registration)

    # send a Slack notification regarding the new registration approval
    approving_admin = socket.assigns[:current_author]

    Slack.send(%{
      "username" => approving_admin.name,
      "icon_emoji" => ":robot_face:",
      "blocks" => [
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" => "Registration for *#{pending_registration.name}* has been declined."
          }
        }
      ]
    })

    socket =
      socket
      |> assign(
        pending_registrations:
          Enum.filter(socket.assigns.pending_registrations, &(&1.id != pending_registration.id))
      )
      |> put_flash(:info, [
        "Registration for ",
        content_tag(:b, pending_registration.name),
        " declined"
      ])

    {:noreply,
     push_event(socket, "js-exec", %{
       to: "#decline-registration-modal-trigger",
       attr: "data-hide_modal"
     })}
  end

  # handle the case where the creation of a new institution was required (when institution_id == "")
  defp approve_pending_registration("", pending_registration),
    do: Institutions.approve_pending_registration_as_new_institution(pending_registration)

  defp approve_pending_registration(_, pending_registration),
    do: Institutions.approve_pending_registration(pending_registration)

  defp root_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Institutions",
          link: ~p"/admin/institutions"
        })
      ]
  end
end
