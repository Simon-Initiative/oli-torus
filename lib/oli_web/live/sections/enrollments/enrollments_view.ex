defmodule OliWeb.Sections.EnrollmentsViewLive do
  use OliWeb, :surface_view

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext
  alias Surface.Components.Link
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Paywall

  alias Phoenix.LiveView.JS

  @limit 25
  @default_options %EnrollmentBrowseOptions{
    is_student: true,
    is_instructor: false,
    text_search: nil
  }

  data breadcrumbs, :any
  data title, :string, default: "Enrollments"
  data section, :any, default: nil

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any
  data add_enrollments_step, :atom, default: :step_1
  data add_enrollments_selected_role, :atom, default: :instructor
  data add_enrollments_emails, :list, default: []
  data add_enrollments_users_not_found, :list, default: []

  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Enrollments",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        ctx = SessionContext.init(socket, session) |> Map.put(:is_enrollment_page, true)

        options =
          if !is_nil(Map.get(ctx, :author)),
            do: Map.put(@default_options, :is_instructor, true),
            else: @default_options

        %{total_count: total_count, table_model: table_model} =
          enrollment_assigns(%{
            section: section,
            context: ctx,
            options: options
          })

        {:ok,
         assign(socket,
           ctx: ctx,
           changeset: Sections.change_section(section),
           breadcrumbs: set_breadcrumbs(type, section),
           is_admin: type == :admin,
           section: section,
           total_count: total_count,
           table_model: table_model,
           options: options,
           offset: 0,
           add_enrollments_step: :step_1,
           add_enrollments_selected_role: :instructor,
           add_enrollments_emails: [],
           add_enrollments_users_not_found: []
         )}
    end
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = Map.put(socket.assigns.options, :text_search, get_param(params, "text_search", ""))

    %{total_count: total_count, table_model: table_model} =
      enrollment_assigns(%{
        section: socket.assigns.section,
        context: socket.assigns.ctx |> Map.put(:is_enrollment_page, true),
        options: options,
        table_model: table_model,
        offset: offset
      })

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="container mx-auto">
      {#if @is_admin}
        <.live_component
          module={OliWeb.Components.LiveModal}
          id="my_cool_modal"
          title="Add enrollments"
          on_confirm={
            case @add_enrollments_step do
              :step_1 -> JS.push("add_enrollments_go_to_step_2")
              :step_2 -> JS.push("add_enrollments_go_to_step_3")
              :step_3 -> nil # Add enrollments and send invitations
            end
          }
          on_confirm_label={if @add_enrollments_step == :step_3, do: "Confirm", else: "Next"}
          on_cancel={if @add_enrollments_step == :step_1, do: nil, else: JS.push("add_enrollments_go_to_step_1")}
          on_confirm_disabled={if length(@add_enrollments_emails) == 0, do: true, else: false}
          on_cancel_label={if @add_enrollments_step == :step_1, do: nil, else: "Back"}
        >
          <.add_enrollments
            add_enrollments_emails={@add_enrollments_emails}
            add_enrollments_step={@add_enrollments_step}
            add_enrollments_selected_role={@add_enrollments_selected_role}
            add_enrollments_users_not_found={@add_enrollments_users_not_found}
            section_slug={@section.slug}
          />
        </.live_component>
      {/if}


      <div class="flex justify-between">
        <TextSearch id="text-search"/>

        {#if @is_admin}
          <Link
            label="Download as .CSV"
            to={Routes.page_delivery_path(OliWeb.Endpoint, :export_enrollments, @section.slug)}
            class="btn btn-outline-primary"
            method={:post} />

            <button phx-click="open" phx-target="#my_cool_modal" class="torus-button primary">
              Add Enrollments
            </button>
        {/if}
      </div>

      <div class="mb-3"/>

      <PagedTable
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>
    </div>
    """
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  #### Add enrollments modal related stuff ####
  def add_enrollments(%{add_enrollments_step: :step_1} = assigns) do
    ~H"""
      <div class="px-4">
        <p class="mb-2">
          Please write the email addresses of the users you want to invite to the course.
        </p>
        <OliWeb.Components.EmailList.render
          id="enrollments_email_list"
          users_list={@add_enrollments_emails}
          on_update="add_enrollments_update_list"
          on_remove="add_enrollments_remove_from_list"
        />
        <label class="flex flex-col mt-4 w-40 ml-auto">
          <small class="torus-small uppercase">Role</small>
          <form class="w-full" phx-change="add_enrollments_change_selected_role">
            <select name="role" class="torus-select w-full">
              <option selected={:instructor == @add_enrollments_selected_role} value={:instructor}>Instructor</option>
              <option selected={:student == @add_enrollments_selected_role} value={:student}>Student</option>
            </select>
          </form>
        </label>
      </div>
    """
  end

  def add_enrollments(%{add_enrollments_step: :step_2} = assigns) do
    ~H"""
      <div class="px-4">
        <p>
          The following emails don't exist in the database. If you still want to proceed, an email will be sent and they
          will become enrolled once they sign up. Please, review them and click on "Next" to continue.
        </p>
        <div>
          <li class="list-none mt-4 max-h-80 overflow-y-scroll">
            <%= for user <- @add_enrollments_users_not_found do %>
              <ul class="odd:bg-gray-200 even:bg-gray-100 p-2 first:rounded-t last:rounded-b">
                <div class="flex items-center justify-between">
                  <p><%= user %></p>
                  <button phx-click="add_enrollments_remove_from_list" phx-value-user={user} class="torus-button error">Remove</button>
                </div>
              </ul>
            <% end %>
          </li>
        </div>
      </div>
    """
  end

  def add_enrollments(%{add_enrollments_step: :step_3} = assigns) do
    ~H"""
      <div class="px-4">
        <p>
          Are you sure you want to enroll
          <%= "#{if length(@add_enrollments_emails) == 1, do: "one user", else: "#{length(@add_enrollments_emails)} users"}" %>
          ?
        </p>
      </div>
    """
  end

  def handle_event("add_enrollments_go_to_step_1", _, socket) do
    {:noreply, assign(socket, :add_enrollments_step, :step_1)}
  end

  def handle_event("add_enrollments_go_to_step_2", _, socket) do
    users = socket.assigns.add_enrollments_emails
    existing_users = Oli.Accounts.get_users_by_email(users) |> Enum.map(& &1.email)
    add_enrollments_users_not_found = users -- existing_users

    case length(add_enrollments_users_not_found) do
      0 ->
        {:noreply,
         assign(socket, %{
           add_enrollments_step: :step_3
         })}

      _ ->
        {:noreply,
         assign(socket, %{
           add_enrollments_step: :step_2,
           add_enrollments_users_not_found: add_enrollments_users_not_found
         })}
    end
  end

  def handle_event("add_enrollments_go_to_step_3", _, socket) do
    {:noreply,
     assign(socket, %{
       add_enrollments_step: :step_3
     })}
  end

  def handle_event("add_enrollments_change_selected_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, :add_enrollments_selected_role, String.to_existing_atom(role))}
  end

  def handle_event("add_enrollments_update_list", %{"value" => list}, socket)
      when is_list(list) do
    add_enrollments_emails = socket.assigns.add_enrollments_emails

    socket =
      if length(list) != 0 do
        add_enrollments_emails = Enum.concat(add_enrollments_emails, list) |> Enum.uniq()

        assign(socket, %{
          add_enrollments_emails: add_enrollments_emails
        })
      end

    {:noreply, socket}
  end

  def handle_event("add_enrollments_update_list", %{"value" => value}, socket) do
    add_enrollments_emails = socket.assigns.add_enrollments_emails

    socket =
      if String.length(value) != 0 && !Enum.member?(add_enrollments_emails, value) do
        add_enrollments_emails = add_enrollments_emails ++ [String.downcase(value)]

        assign(socket, %{
          add_enrollments_emails: add_enrollments_emails
        })
      end

    {:noreply, socket}
  end

  def handle_event("add_enrollments_remove_from_list", %{"user" => user}, socket) do
    add_enrollments_emails = Enum.filter(socket.assigns.add_enrollments_emails, &(&1 != user))

    add_enrollments_users_not_found =
      Enum.filter(socket.assigns.add_enrollments_users_not_found, &(&1 != user))

    step =
      cond do
        length(add_enrollments_emails) == 0 ->
          :step_1

        socket.assigns.add_enrollments_step == :step_2 and
            length(add_enrollments_users_not_found) == 0 ->
          :step_1

        true ->
          socket.assigns.add_enrollments_step
      end

    {:noreply,
     assign(socket, %{
       add_enrollments_emails: add_enrollments_emails,
       add_enrollments_users_not_found: add_enrollments_users_not_found,
       add_enrollments_step: step
     })}
  end

  #### End of enrollments modal related stuff ####

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def enrollment_assigns(
        %{
          section: section,
          context: ctx,
          options: options
        } = assigns
      ) do
    %{offset: offset, direction: direction, field: field} =
      case assigns[:table_model] do
        nil ->
          %{offset: assigns[:offset] || 0, direction: :asc, field: :name}

        table_model ->
          %{
            offset: assigns[:offset] || 0,
            direction: table_model.sort_order,
            field: table_model.sort_by_spec.name
          }
      end

    enrollments =
      Sections.browse_enrollments_with_context_roles(
        section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: direction, field: field},
        options
      )
      |> add_students_progress(section.id, nil)
      |> add_payment_status(section)

    total_count = determine_total(enrollments)

    {:ok, table_model} =
      case assigns[:table_model] do
        nil -> EnrollmentsTableModel.new(enrollments, section, ctx)
        table_model -> {:ok, Map.put(table_model, :rows, enrollments)}
      end

    %{total_count: total_count, table_model: table_model}
  end

  def enrollment_assigns(socket), do: enrollment_assigns(socket.assigns)

  defp add_students_progress(users, section_id, container_id) do
    users_progress = Metrics.progress_for(section_id, Enum.map(users, & &1.id), container_id)

    Enum.map(users, fn user ->
      Map.merge(user, %{progress: Map.get(users_progress, user.id)})
    end)
  end

  defp add_payment_status(users, section) do
    Enum.map(users, fn user ->
      Map.merge(user, %{
        payment_status:
          Paywall.summarize_access(
            user,
            section,
            user.context_role_id,
            user.enrollment,
            user.payment
          ).reason
      })
    end)
  end
end
