defmodule OliWeb.Admin.Institutions.IndexLive do
  use OliWeb, :live_view
  require Logger

  import OliWeb.DelegatedEvents

  alias Oli.Institutions
  alias Oli.Predefined
  alias Oli.Repo.Paging
  alias Oli.Slack

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.{Params, PagingParams, StripedPagedTable}
  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Modal
  alias OliWeb.Admin.Institutions.{InstitutionsTableModel, PendingRegistrationsTableModel}
  alias OliWeb.Common.Table.SortableTableModel

  @limit 20

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_params, _session, socket) do
    # Initialize with default pagination
    {institutions, institutions_total_count} =
      Institutions.list_institutions_paged(%Paging{offset: 0, limit: @limit})

    {pending_registrations, pending_registrations_total_count} =
      Institutions.list_pending_registrations_paged(%Paging{offset: 0, limit: @limit})

    {:ok, institutions_table_model} =
      InstitutionsTableModel.new(institutions, socket.assigns.ctx)

    {:ok, pending_registrations_table_model} =
      PendingRegistrationsTableModel.new(pending_registrations, socket.assigns.ctx)

    # Get all institutions for the dropdown (not paginated)
    all_institutions = Institutions.list_institutions()

    socket =
      assign(
        socket,
        institutions: institutions,
        institutions_list: [
          {"New institution", nil} | Enum.map(all_institutions, &{&1.name, &1.id})
        ],
        pending_registrations: pending_registrations,
        institutions_table_model: institutions_table_model,
        pending_registrations_table_model: pending_registrations_table_model,
        institutions_offset: 0,
        institutions_limit: @limit,
        institutions_total_count: institutions_total_count,
        pending_registrations_offset: 0,
        pending_registrations_limit: @limit,
        pending_registrations_total_count: pending_registrations_total_count,
        breadcrumbs: root_breadcrumbs(),
        country_codes: Predefined.country_codes(),
        registration_changeset: nil,
        institution_id: nil,
        form_disabled?: false,
        active_tab: :institutions_tab
      )

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    # Parse pagination params for institutions table
    institutions_offset =
      Params.get_int_param(
        params,
        "institutions_offset",
        socket.assigns[:institutions_offset] || 0
      )

    institutions_limit =
      Params.get_int_param(
        params,
        "institutions_limit",
        socket.assigns[:institutions_limit] || @limit
      )

    # Parse pagination params for pending registrations table
    pending_registrations_offset =
      Params.get_int_param(
        params,
        "pending_registrations_offset",
        socket.assigns[:pending_registrations_offset] || 0
      )

    pending_registrations_limit =
      Params.get_int_param(
        params,
        "pending_registrations_limit",
        socket.assigns[:pending_registrations_limit] || @limit
      )

    # Parse active tab
    active_tab =
      case params["active_tab"] do
        "pending_registrations_tab" -> :pending_registrations_tab
        _ -> :institutions_tab
      end

    # Load data for both tables (we need both for dropdown and badge count)
    socket =
      socket
      |> load_institutions_data(institutions_offset, institutions_limit, params)
      |> load_pending_registrations_data(
        pending_registrations_offset,
        pending_registrations_limit,
        params
      )
      |> assign(active_tab: active_tab)

    {:noreply, socket}
  end

  defp load_institutions_data(socket, offset, limit, params) do
    {institutions, total_count} =
      Institutions.list_institutions_paged(%Paging{offset: offset, limit: limit})

    {:ok, table_model} =
      InstitutionsTableModel.new(institutions, socket.assigns.ctx)

    # Update table model with sort params from URL
    table_model = SortableTableModel.update_from_params(table_model, params)

    # Get all institutions for dropdown
    all_institutions = Institutions.list_institutions()

    assign(socket,
      institutions: institutions,
      institutions_list: [
        {"New institution", nil} | Enum.map(all_institutions, &{&1.name, &1.id})
      ],
      institutions_table_model: table_model,
      institutions_offset: offset,
      institutions_limit: limit,
      institutions_total_count: total_count
    )
  end

  defp load_pending_registrations_data(socket, offset, limit, params) do
    {pending_registrations, total_count} =
      Institutions.list_pending_registrations_paged(%Paging{offset: offset, limit: limit})

    {:ok, table_model} =
      PendingRegistrationsTableModel.new(pending_registrations, socket.assigns.ctx)

    # Update table model with sort params from URL
    table_model = SortableTableModel.update_from_params(table_model, params)

    assign(socket,
      pending_registrations: pending_registrations,
      pending_registrations_table_model: table_model,
      pending_registrations_offset: offset,
      pending_registrations_limit: limit,
      pending_registrations_total_count: total_count
    )
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <div class="flex justify-start items-center gap-2.5" role="tablist">
        <div
          phx-click="change_active_tab"
          phx-value-tab="institutions_tab"
          class={[
            "cursor-pointer pr-2.5 border-r border-Border-border-input",
            "#{if @active_tab == :institutions_tab, do: "text-Text-text-button text-2xl font-bold leading-8", else: "text-Text-text-high text-lg font-semibold leading-6"}"
          ]}
          id="institutions_tab"
          role="tab"
          aria-controls="institutions"
          aria-selected={"#{@active_tab == :institutions_tab}"}
        >
          Institutions
        </div>

        <div
          phx-click="change_active_tab"
          phx-value-tab="pending_registrations_tab"
          class={[
            "cursor-pointer",
            "#{if @active_tab == :pending_registrations_tab, do: "text-Text-text-button text-2xl font-bold leading-8", else: "text-Text-text-high text-lg font-semibold leading-6"}"
          ]}
          id="pending_registrations_tab"
          role="tab"
          aria-controls="pending_registrations"
          aria-selected={"#{@active_tab == :pending_registrations_tab}"}
        >
          <span>Pending Registrations</span>
          <div
            :if={@pending_registrations_total_count > 0}
            class="ml-2.5 px-2 py-1 bg-Fill-Buttons-fill-primary rounded-[999px] shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] inline-flex justify-center items-center gap-2 overflow-hidden"
          >
            <div class="flex justify-center items-center">
              <div class="text-center justify-center text-Text-text-white text-xs font-semibold leading-3">
                {@pending_registrations_total_count}
              </div>
            </div>
          </div>
        </div>
        <.link
          :if={@active_tab == :institutions_tab}
          navigate={Routes.institution_path(OliWeb.Endpoint, :new)}
          class="ml-auto px-4 py-2 bg-Fill-Buttons-fill-primary hover:bg-Fill-Buttons-fill-primary-hover hover:no-underline rounded-md shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] inline-flex justify-center items-center gap-2 overflow-hidden"
        >
          <div class="pr-2 flex justify-center items-center gap-2">
            <Icons.plus class="w-4 h-4" path_class="stroke-Text-text-white" />
            <div class="text-center justify-center text-Text-text-white text-base font-semibold leading-6">
              New Institution
            </div>
          </div>
        </.link>
      </div>
      <div>
        <div
          :if={@active_tab == :institutions_tab}
          id="institutions"
          role="tabpanel"
          aria-labelledby="institutions_tab"
          class="flex flex-col gap-2"
        >
          <OliWeb.Common.SearchInput.render
            id="institutions_search_input"
            name="text_search"
            text=""
            class="w-[400px] mt-6"
          />
          <StripedPagedTable.render
            table_model={@institutions_table_model}
            total_count={@institutions_total_count}
            offset={@institutions_offset}
            limit={@institutions_limit}
            sort="institutions_paged_table_sort"
            page_change="institutions_paged_table_page_change"
            limit_change="institutions_paged_table_limit_change"
            additional_table_class=""
            no_records_message="There are no registered institutions"
          />
        </div>
        <div
          :if={@active_tab == :pending_registrations_tab}
          id="pending_registrations"
          role="tabpanel"
          aria-labelledby="pending_registrations_tab"
        >
          <StripedPagedTable.render
            table_model={@pending_registrations_table_model}
            total_count={@pending_registrations_total_count}
            offset={@pending_registrations_offset}
            limit={@pending_registrations_limit}
            sort="pending_registrations_paged_table_sort"
            page_change="pending_registrations_paged_table_page_change"
            limit_change="pending_registrations_paged_table_limit_change"
            additional_table_class=""
            no_records_message="There are no pending registrations"
          />
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
          Are you sure you want to decline this request from "{@registration_changeset.name}"?
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
                    label_position={:responsive}
                    required
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    readonly={@form_disabled?}
                    field={@registration_changeset[:institution_url]}
                    label="Institution URL"
                    label_position={:responsive}
                    required
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    readonly={@form_disabled?}
                    field={@registration_changeset[:institution_email]}
                    label="Contact Email"
                    label_position={:responsive}
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
                    label_position={:responsive}
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
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:client_id]}
                    label="Client ID"
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:deployment_id]}
                    label="Deployment ID"
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:key_set_url]}
                    label="Keyset URL"
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:auth_token_url]}
                    label="Auth Token URL"
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:auth_login_url]}
                    label="Auth Login URL"
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:auth_server]}
                    label="Auth Server URL"
                    label_position={:responsive}
                    readonly
                  />
                  <.input
                    variant="outlined"
                    class="read-only:bg-gray-100"
                    field={@registration_changeset[:line_items_service_domain]}
                    label="Line items service domain"
                    label_position={:responsive}
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
    active_tab = String.to_existing_atom(tab)
    patch_with(socket, %{active_tab: Atom.to_string(active_tab)})
  end

  def handle_event("institutions_paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    current_sort_by = socket.assigns.institutions_table_model.sort_by_spec.name
    current_sort_order = socket.assigns.institutions_table_model.sort_order
    new_sort_by = String.to_existing_atom(sort_by_str)

    sort_order =
      if new_sort_by == current_sort_by, do: toggle_sort_order(current_sort_order), else: :asc

    # Use the event_suffix pattern for param names
    patch_with(socket, %{
      "sort_by_institutions" => Atom.to_string(new_sort_by),
      "sort_order_institutions" => Atom.to_string(sort_order)
    })
  end

  def handle_event("pending_registrations_paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    current_sort_by = socket.assigns.pending_registrations_table_model.sort_by_spec.name
    current_sort_order = socket.assigns.pending_registrations_table_model.sort_order
    new_sort_by = String.to_existing_atom(sort_by_str)

    sort_order =
      if new_sort_by == current_sort_by, do: toggle_sort_order(current_sort_order), else: :asc

    # Use the event_suffix pattern for param names
    patch_with(socket, %{
      "sort_by_pending_registrations" => Atom.to_string(new_sort_by),
      "sort_order_pending_registrations" => Atom.to_string(sort_order)
    })
  end

  def handle_event(
        "institutions_paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    patch_with(socket, %{"institutions_limit" => limit, "institutions_offset" => offset})
  end

  def handle_event("institutions_paged_table_limit_change", params, socket) do
    new_limit = Params.get_int_param(params, "limit", @limit)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.institutions_offset,
        new_limit,
        socket.assigns.institutions_total_count
      )

    patch_with(socket, %{"institutions_limit" => new_limit, "institutions_offset" => new_offset})
  end

  def handle_event(
        "pending_registrations_paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    patch_with(socket, %{
      "pending_registrations_limit" => limit,
      "pending_registrations_offset" => offset
    })
  end

  def handle_event("pending_registrations_paged_table_limit_change", params, socket) do
    new_limit = Params.get_int_param(params, "limit", @limit)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.pending_registrations_offset,
        new_limit,
        socket.assigns.pending_registrations_total_count
      )

    patch_with(socket, %{
      "pending_registrations_limit" => new_limit,
      "pending_registrations_offset" => new_offset
    })
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([&StripedPagedTable.handle_delegated/4])
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
    # Get all institutions to find the matching one (not just paginated list)
    all_institutions = Institutions.list_institutions()
    institution = Enum.find(all_institutions, &(&1.id == institution_id))

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

    # Get all institutions to find matching one (not just paginated list)
    all_institutions = Institutions.list_institutions()

    matching_institution =
      Enum.find(
        all_institutions,
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

            # Reload institutions with current pagination
            {updated_institutions, institutions_total_count} =
              Institutions.list_institutions_paged(%Paging{
                offset: socket.assigns.institutions_offset,
                limit: socket.assigns.institutions_limit
              })

            # Reload pending registrations with current pagination
            {updated_pending_registrations, pending_registrations_total_count} =
              Institutions.list_pending_registrations_paged(%Paging{
                offset: socket.assigns.pending_registrations_offset,
                limit: socket.assigns.pending_registrations_limit
              })

            {:ok, updated_institutions_table_model} =
              InstitutionsTableModel.new(updated_institutions, socket.assigns.ctx)

            {:ok, updated_pending_registrations_table_model} =
              PendingRegistrationsTableModel.new(
                updated_pending_registrations,
                socket.assigns.ctx
              )

            # Get all institutions for dropdown
            all_institutions = Institutions.list_institutions()

            socket
            |> assign(
              pending_registrations: updated_pending_registrations,
              institutions: updated_institutions,
              institutions_list: [
                {"New institution", nil} | Enum.map(all_institutions, &{&1.name, &1.id})
              ],
              institutions_table_model: updated_institutions_table_model,
              pending_registrations_table_model: updated_pending_registrations_table_model,
              institutions_total_count: institutions_total_count,
              pending_registrations_total_count: pending_registrations_total_count
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

    # Reload pending registrations with current pagination
    {updated_pending_registrations, pending_registrations_total_count} =
      Institutions.list_pending_registrations_paged(%Paging{
        offset: socket.assigns.pending_registrations_offset,
        limit: socket.assigns.pending_registrations_limit
      })

    {:ok, updated_pending_registrations_table_model} =
      PendingRegistrationsTableModel.new(updated_pending_registrations, socket.assigns.ctx)

    socket =
      socket
      |> assign(
        pending_registrations: updated_pending_registrations,
        pending_registrations_table_model: updated_pending_registrations_table_model,
        pending_registrations_total_count: pending_registrations_total_count
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

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, Map.merge(current_params(socket), changes)),
       replace: true
     )}
  end

  defp current_params(%Phoenix.LiveView.Socket{} = socket), do: current_params(socket.assigns)

  defp current_params(assigns) do
    base = %{
      "institutions_offset" => assigns[:institutions_offset] || 0,
      "institutions_limit" => assigns[:institutions_limit] || @limit,
      "pending_registrations_offset" => assigns[:pending_registrations_offset] || 0,
      "pending_registrations_limit" => assigns[:pending_registrations_limit] || @limit,
      "active_tab" => (assigns[:active_tab] || :institutions_tab) |> Atom.to_string()
    }

    # Add sort params using event_suffix pattern
    institutions_params =
      if assigns[:institutions_table_model] do
        SortableTableModel.to_params(assigns.institutions_table_model)
      else
        %{}
      end

    pending_params =
      if assigns[:pending_registrations_table_model] do
        SortableTableModel.to_params(assigns.pending_registrations_table_model)
      else
        %{}
      end

    base
    |> Map.merge(institutions_params)
    |> Map.merge(pending_params)
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  # handle the case where the creation of a new institution was required (when institution_id == "")
  defp approve_pending_registration("", pending_registration),
    do: Institutions.approve_pending_registration_as_new_institution(pending_registration)

  defp approve_pending_registration(_, pending_registration),
    do: Institutions.approve_pending_registration(pending_registration)

  defp root_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Institutions",
          link: ~p"/admin/institutions"
        })
      ]
  end
end
