defmodule OliWeb.Sections.EnrollmentsView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions, SectionInvite}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  alias OliWeb.Sections.Mount
  use OliWeb.Common.Modal
  alias OliWeb.Sections.InviteStudentsModal
  alias Oli.Delivery.Sections.SectionInvites
  import Oli.Utils.Time

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

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
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
        %{total_count: total_count, table_model: table_model} = enrollment_assigns(section)

        {:ok,
         assign(socket,
           changeset: Sections.change_section(section),
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           total_count: total_count,
           table_model: table_model,
           options: @default_options,
           modal: nil
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

    options = %EnrollmentBrowseOptions{
      text_search: get_param(params, "text_search", ""),
      is_student: true,
      is_instructor: false
    }

    enrollments =
      Sections.browse_enrollments(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, enrollments)
    total_count = determine_total(enrollments)

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
    <div>
    <div id="invite-students-popup"></div>
      {#if !is_nil(@modal)}
        {render_modal(assigns)}
      {/if}

      <div class="d-flex justify-content-between">
        <TextSearch id="text-search"/>
        <button class="btn btn-primary" :on-click="InviteStudentsModal.show">Invite Students</button>
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

  def handle_event("InviteStudentsModal.show", _params, socket) do
    section = socket.assigns.section

    {:ok, section_invite} = SectionInvites.create_default_section_invite(section.id)

    {:noreply,
     assign(socket,
       modal: %{
         component: InviteStudentsModal,
         assigns: %{
           section: section,
           section_invite: section_invite,
           show_invite_settings: false,
           date_expires_options: SectionInvites.expire_after_options(now(), section)
         }
       }
     )}
  end

  # TODO: Change this to "suspend" rather than removing the enrollment,
  # and introduce separate view for suspended students. Also remove from non-independent learner mode.
  # (Why do we want to keep enrollments if they're removed from course instead of re-enrolling?)
  def handle_event("unenroll", %{"id" => user_id}, socket) do
    section = socket.assigns.section

    case Sections.unenroll_learner(user_id, section.id) do
      {:ok, _} ->
        %{total_count: total_count, table_model: table_model} = enrollment_assigns(section)

        {:noreply, assign(socket, total_count: total_count, table_model: table_model)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_link_settings", _, socket) do
    modal_assigns = socket.assigns.modal.assigns

    {:noreply,
     assign(socket,
       modal: %{
         component: InviteStudentsModal,
         assigns:
           modal_assigns
           |> Map.put(:show_invite_settings, true)
           |> Map.put(:section_invite, SectionInvite.changeset(modal_assigns.section_invite))
       }
     )}
  end

  def handle_event("update_section_invite", _params, socket) do
    modal_assigns = socket.assigns.modal.assigns
    # pull out params and assign to changeset

    {:noreply,
     assign(socket,
       modal: %{
         component: InviteStudentsModal,
         assigns:
           modal_assigns
           |> Map.put(:section_invite, SectionInvite.changeset(modal_assigns.section_invite))
       }
     )}
  end

  def handle_event("generate_section_invite", _, socket) do
    modal_assigns = socket.assigns.modal.assigns
    {:ok, section_invite} = SectionInvites.create_section_invite(modal_assigns.section_invite)

    {:noreply,
     assign(socket,
       modal: %{
         component: InviteStudentsModal,
         assigns: Map.put(socket.assigns.modal.assigns, :section_invite, section_invite)
       }
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def enrollment_assigns(section) do
    enrollments =
      Sections.browse_enrollments(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )

    total_count = determine_total(enrollments)

    {:ok, table_model} = EnrollmentsTableModel.new(enrollments, section)

    %{total_count: total_count, table_model: table_model}
  end
end
