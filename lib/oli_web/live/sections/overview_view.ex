defmodule OliWeb.Sections.OverviewView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, DeleteModalNoConfirmation}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, EnrollmentBrowseOptions}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.{Instructors, Mount, UnlinkSection}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Projects.RequiredSurvey
  alias OliWeb.Common.MonacoEditor
  alias Oli.Repo
  alias OliWeb.Components.Common

  def set_breadcrumbs(:admin, section) do
    OliWeb.Sections.SectionsView.set_breadcrumbs()
    |> breadcrumb(section)
  end

  def set_breadcrumbs(_, section) do
    breadcrumb([], section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: section.title,
          link:
            Routes.live_path(
              OliWeb.Endpoint,
              OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
              section.slug,
              :manage
            )
        })
      ]
  end

  def mount(params, session, socket) do
    section_slug =
      case params do
        :not_mounted_at_router -> Map.get(session, "section_slug")
        _ -> Map.get(params, "section_slug")
      end

    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, user, section} ->
        updates_count =
          Sections.check_for_available_publication_updates(section)
          |> Enum.count()

        show_required_section_config =
          if section.required_survey_resource_id != nil or
               Sections.get_base_project_survey(section.slug) do
            true
          else
            false
          end

        %{slug: revision_slug} = DeliveryResolver.root_container(section.slug)

        {:ok, collab_space_config} =
          Collaboration.get_collab_space_config_for_page_in_section(
            revision_slug,
            section.slug
          )

        %{base_project: base_project} = section |> Repo.preload(:base_project)

        {:ok,
         assign(socket,
           page_prompt_template: section.page_prompt_template,
           is_system_admin: type == :admin,
           is_lms_or_system_admin: Mount.is_lms_or_system_admin?(user, section),
           breadcrumbs: set_breadcrumbs(type, section),
           instructors: fetch_instructors(section),
           user: user,
           section: section,
           updates_count: updates_count,
           submission_count:
             Oli.Delivery.Attempts.ManualGrading.count_submitted_attempts(section),
           collab_space_config: collab_space_config,
           resource_slug: revision_slug,
           show_required_section_config: show_required_section_config,
           base_project: base_project
         )}
    end
  end

  defp fetch_instructors(section) do
    Sections.browse_enrollments(
      section,
      %Paging{offset: 0, limit: 50},
      %Sorting{direction: :asc, field: :name},
      %EnrollmentBrowseOptions{
        is_student: false,
        is_instructor: true,
        text_search: nil
      }
    )
  end

  attr(:user, :any)
  attr(:modal, :any, default: nil)
  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "Section Details")
  attr(:section, :any, default: nil)
  attr(:instructors, :list, default: [])
  attr(:updates_count, :integer)
  attr(:submission_count, :integer)
  attr(:section_has_student_data, :boolean)

  def render(assigns) do
    assigns = assign(assigns, deployment: assigns.section.lti_1p3_deployment)

    ~H"""
    <%= render_modal(assigns) %>
    <Groups.render>
      <Group.render label="Details" description="Overview of course section details">
        <ReadOnly.render label="Course Section ID" value={@section.slug} />
        <ReadOnly.render label="Title" value={@section.title} />
        <ReadOnly.render label="Course Section Type" value={type_to_string(@section)} />
        <ReadOnly.render label="URL" show_copy_btn={true} value={url(~p"/sections/#{@section.slug}")} />
        <%= unless is_nil(@deployment) do %>
          <ReadOnly.render
            label="Institution"
            type={if @is_system_admin, do: "link"}
            link_label={@deployment.institution.name}
            value={
              if @is_system_admin,
                do: Routes.institution_path(OliWeb.Endpoint, :show, @deployment.institution_id),
                else: @deployment.institution.name
            }
          />
        <% end %>
        <div class="flex flex-col form-group">
          <label>Base Project</label>
          <a href={
            Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, @base_project.slug)
          }>
            <%= @base_project.title %>
          </a>
        </div>
        <%= unless is_nil(@section.blueprint_id) do %>
          <div class="flex flex-col form-group">
            <label>Product</label>
            <a href={
              Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, @section.blueprint.slug)
            }>
              <%= @section.blueprint.title %>
            </a>
          </div>
        <% end %>
      </Group.render>
      <Group.render label="Instructors" description="Manage users with instructor level access">
        <Instructors.render users={@instructors} />
      </Group.render>
      <Group.render label="Curriculum" description="Manage content delivered to students">
        <ul class="link-list">
          <li>
            <a target="_blank" href={~p"/sections/#{@section.slug}/preview"} class="btn btn-link">
              <span>Preview Course as Instructor</span>
              <i class="fas fa-external-link-alt self-center ml-1" />
            </a>
          </li>
          <li>
            <a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, @section.slug)}
              class="btn btn-link"
            >
              Customize Content
            </a>
          </li>
          <li>
            <a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.ScheduleView, @section.slug)}
              class="btn btn-link"
            >
              Scheduling
            </a>
          </li>
          <li>
            <a
              disabled={@updates_count == 0}
              href={
                Routes.source_materials_path(
                  OliWeb.Endpoint,
                  OliWeb.Delivery.ManageSourceMaterials,
                  @section.slug
                )
              }
              class="btn btn-link"
            >
              Manage Source Materials
              <%= if @updates_count > 0 do %>
                <span class="badge badge-primary"><%= @updates_count %> available</span>
              <% end %>
            </a>
          </li>
        </ul>
      </Group.render>
      <Group.render label="Manage" description="Manage all aspects of course delivery">
        <ul class="link-list">
          <%= if @section.open_and_free do %>
            <li>
              <a
                href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.InviteView, @section.slug)}
                class="btn btn-link"
              >
                Invite Students
              </a>
            </li>
          <% end %>
          <li>
            <a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, @section.slug)}
              class="btn btn-link"
            >
              Edit Section Details
            </a>
          </li>
          <li>
            <a
              href={Routes.collab_spaces_index_path(OliWeb.Endpoint, :instructor, @section.slug)}
              class="btn btn-link"
            >
              Browse Collaborative Spaces
            </a>
          </li>
          <li>
            <a
              href={
                Routes.live_path(
                  OliWeb.Endpoint,
                  OliWeb.Sections.AssessmentSettings.SettingsLive,
                  @section.slug,
                  :settings,
                  :all
                )
              }
              class="btn btn-link"
            >
              Assessment Settings
            </a>
          </li>
          <li>
            <button
              type="button"
              class="btn btn-link text-danger action-button"
              phx-click="show_delete_modal"
            >
              Delete Section
            </button>
          </li>
        </ul>
      </Group.render>
      <Group.render
        label="Required Survey"
        description="Show a required to students who access the course for the first time"
      >
        <%= if @show_required_section_config do %>
          <%= live_component(RequiredSurvey, %{
            project: @section,
            enabled: @section.required_survey_resource_id,
            is_section: true,
            id: "section-required-survey-section"
          }) %>
        <% else %>
          <div class="flex items-center h-full ml-8">
            <p class="m-0">
              You are not allowed to have student surveys in this resource.<br />Please contact the admin to be granted with that permission.
            </p>
          </div>
        <% end %>
      </Group.render>
      <Group.render
        label="Collaboration Spaces"
        description="Manage the Collaborative Spaces within the course"
      >
        <div class="container mx-auto">
          <%= live_render(@socket, OliWeb.CollaborationLive.CollabSpaceConfigView,
            id: "collab_space_config",
            session: %{
              "collab_space_config" => @collab_space_config,
              "section_slug" => @section.slug,
              "resource_slug" => @resource_slug,
              "is_overview_render" => true,
              "is_delivery" => true
            }
          ) %>
        </div>
      </Group.render>
      <Group.render
        label="Grading"
        description="View and manage student grades and progress"
        is_last={not @is_lms_or_system_admin or @section.open_and_free}
      >
        <ul class="link-list">
          <li>
            <a
              href={
                Routes.live_path(
                  OliWeb.Endpoint,
                  OliWeb.ManualGrading.ManualGradingView,
                  @section.slug
                )
              }
              class="btn btn-link"
            >
              Score Manually Graded Activities
              <%= if @submission_count > 0 do %>
                <span class="badge badge-primary"><%= @submission_count %></span>
              <% end %>
            </a>
          </li>
          <li>
            <a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradebookView, @section.slug)}
              class="btn btn-link"
            >
              View all Grades
            </a>
          </li>
          <li>
            <a
              href={Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, @section.slug)}
              class="btn btn-link"
            >
              Download Gradebook as <code>.csv</code> file
            </a>
          </li>

          <%= if @is_system_admin do %>
            <li>
              <a
                href={
                  Routes.live_path(OliWeb.Endpoint, OliWeb.Snapshots.SnapshotsView, @section.slug)
                }
                class="btn btn-link"
              >
                Manage Snapshot Records
              </a>
            </li>
          <% end %>
          <%= if !@section.open_and_free do %>
            <li>
              <a
                href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, @section.slug)}
                class="btn btn-link"
              >
                Manage LMS Gradebook
              </a>
            </li>
            <li>
              <a
                href={
                  Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.FailedGradeSyncLive, @section.slug)
                }
                class="btn btn-link"
              >
                View Grades that failed to sync
              </a>
            </li>
            <%= if @is_lms_or_system_admin do %>
              <li>
                <a
                  href={
                    Routes.live_path(
                      OliWeb.Endpoint,
                      OliWeb.Grades.ObserveGradeUpdatesView,
                      @section.slug
                    )
                  }
                  class="btn btn-link"
                >
                  Observe grade updates in real-time
                </a>
              </li>
            <% end %>
            <li>
              <a
                href={
                  Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.BrowseUpdatesView, @section.slug)
                }
                class="btn btn-link"
              >
                Browse LMS Grade Update Log
              </a>
            </li>
          <% end %>
        </ul>
      </Group.render>

      <%= if @is_lms_or_system_admin and !@section.open_and_free do %>
        <Group.render
          label="LMS Admin"
          description="Administrator LMS Connection"
          is_last={!@is_system_admin}
        >
          <UnlinkSection.render unlink="unlink" section={@section} />
        </Group.render>
      <% end %>

      <div :if={@is_system_admin} class="border-t dark:border-gray-700">
        <Group.render
          label="Prompt Templates"
          description="Edit the GenAI prompt templates"
          is_last={true}
        >
          <div :if={assistant_enabled?(@section)}>
            <MonacoEditor.render
              id="attribute-monaco-editor"
              height="200px"
              language="text"
              on_change="monaco_editor_on_change"
              set_options="monaco_editor_set_options"
              set_value="monaco_editor_set_value"
              get_value="monaco_editor_get_value"
              validate_schema_uri=""
              default_value={
                if is_nil(@section.page_prompt_template) do
                  ""
                else
                  @section.page_prompt_template
                end
              }
              default_options={
                %{
                  "readOnly" => false,
                  "selectOnLineNumbers" => true,
                  "minimap" => %{"enabled" => false},
                  "scrollBeyondLastLine" => false,
                  "tabSize" => 2
                }
              }
              use_code_lenses={[]}
            />
            <button type="button" class="btn btn-primary action-button mt-4" phx-click="save_prompt">
              Save
            </button>
          </div>
          <div class="my-2">
            <.assistant_toggle_button section={@section} />
          </div>
        </Group.render>
      </div>
    </Groups.render>
    """
  end

  defp type_to_string(section) do
    case section.open_and_free do
      true -> "Direct Delivery"
      _ -> "LTI"
    end
  end

  def handle_event("monaco_editor_on_change", value, socket) do
    {:noreply, assign(socket, page_prompt_template: value)}
  end

  def handle_event("save_prompt", _, socket) do
    section = socket.assigns.section

    Oli.Delivery.Sections.update_section(section, %{
      page_prompt_template: socket.assigns.page_prompt_template
    })

    socket =
      socket
      |> put_flash(:info, "Prompt successfully saved")

    {:noreply, socket}
  end

  def handle_event("unlink", _, socket) do
    %{section: section} = socket.assigns

    {:ok, _deleted} = Oli.Delivery.Sections.soft_delete_section(section)

    {:noreply, push_redirect(socket, to: Routes.delivery_path(socket, :index))}
  end

  def handle_event("show_delete_modal", _params, socket) do
    section_has_student_data = Sections.has_student_data?(socket.assigns.section.slug)

    {message, action} =
      if section_has_student_data do
        {"""
           This section has student data and will be archived rather than deleted.
           Are you sure you want to archive it? You will no longer have access to the data. Archiving this section will make it so students can no longer access it.
         """, "Archive"}
      else
        {"""
           This action cannot be undone. Are you sure you want to delete this section?
         """, "Delete"}
      end

    modal_assigns = %{
      id: "delete_section_modal",
      description: message,
      entity_type: "section",
      entity_id: socket.assigns.section.id,
      delete_enabled: true,
      delete: "delete_section",
      modal_action: action
    }

    modal = fn assigns ->
      ~H"""
      <DeleteModalNoConfirmation.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(socket, modal,
       modal_assigns: modal_assigns,
       section_has_student_data: section_has_student_data
     )}
  end

  def handle_event("delete_section", _, socket) do
    socket = clear_flash(socket)

    socket =
      if socket.assigns.section_has_student_data ==
           Sections.has_student_data?(socket.assigns.section.slug) do
        {action_function, action} =
          if socket.assigns.section_has_student_data do
            {&Sections.update_section(&1, %{status: :archived}), "archived"}
          else
            {&Sections.delete_section/1, "deleted"}
          end

        case action_function.(socket.assigns.section) do
          {:ok, _section} ->
            is_admin = socket.assigns.is_system_admin

            redirect_path =
              if is_admin do
                Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)
              else
                ~p"/sections"
              end

            socket
            |> put_flash(:info, "Section successfully #{action}.")
            |> redirect(to: redirect_path)

          {:error, %Ecto.Changeset{}} ->
            put_flash(
              socket,
              :error,
              "Section couldn't be #{action}."
            )
        end
      else
        put_flash(
          socket,
          :error,
          "Section had student activity recently. It can now only be archived, please try again."
        )
      end

    {:noreply, socket |> hide_modal(modal_assigns: nil, section_has_student_data: nil)}
  end

  def handle_event("toggle_assistant", _, socket) do
    section = socket.assigns.section
    assistant_enabled = section.assistant_enabled

    {:ok, section} =
      Oli.Delivery.Sections.update_section(section, %{assistant_enabled: !assistant_enabled})

    socket =
      socket
      |> put_flash(:info, "Assistant settings updated successfully")

    {:noreply, assign(socket, section: section)}
  end

  attr :section, Section

  def assistant_toggle_button(assigns) do
    ~H"""
    <%= if assistant_enabled?(@section) do %>
      <.button variant={:warning} phx-click="toggle_assistant">
        Disable Assistant
      </.button>
    <% else %>
      <.button variant={:primary} phx-click="toggle_assistant">
        Enable Assistant
      </.button>
    <% end %>
    """
  end

  defp assistant_enabled?(section) do
    section.assistant_enabled
  end
end
