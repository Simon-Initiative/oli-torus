defmodule OliWeb.Admin.ExternalTools.DetailsView do
  use OliWeb, :live_view

  require Logger

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Lti.{PlatformInstances, PlatformExternalTools}
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Admin.ExternalTools.Form
  alias OliWeb.Icons
  alias OliWeb.Components.Modal
  alias OliWeb.Components.DesignTokens.Primitives.{Button, RadioGroup}

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @grants_per_page 20
  @search_results_shown 10

  @modal_confirm_class "h-8 w-fit px-5 py-3 text-white hover:no-underline rounded-md justify-center items-center gap-2 inline-flex bg-[#0062F2] hover:bg-[#0075EB] dark:bg-[#0062F2] dark:hover:bg-[#0D70FF]"
  @modal_cancel_class "h-8 px-3 !py-1 bg-white text-[#006cd9] border border-blue-500 rounded-md
                     hover:bg-[#0062F2] hover:text-white
                     dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                     dark:hover:bg-[#0062F2] dark:hover:text-white dark:hover:border-[#0062F2]"

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
          link: ~p"/admin/external_tools"
        })
      ] ++ [Breadcrumb.new(%{full_title: "LTI 1.3 External Tool Details"})]
  end

  @impl Phoenix.LiveView
  def mount(%{"platform_instance_id" => platform_instance_id}, _session, socket) do
    case PlatformExternalTools.get_platform_instance_with_deployment(platform_instance_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "The LTI Tool you are trying to view does not exist.")
         |> redirect(to: ~p"/admin/external_tools")}

      {platform_instance, deployment} ->
        changeset = PlatformExternalTools.change_platform_instance(platform_instance)

        {:ok,
         socket
         |> assign(
           breadcrumbs: set_breadcrumbs(),
           form: to_form(changeset, as: :tool_form),
           platform_instance: platform_instance,
           custom_flash: nil,
           edit_mode: false,
           deployment: deployment,
           confirming_private: false,
           availability_rev: 0,
           granted_query: "",
           granted_offset: 0,
           granted_sort_order: :asc,
           project_query: "",
           search_results: [],
           more_results?: false
         )
         |> load_granted_projects()
         |> assign_search_results()}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-end mx-12 mt-4">
      <.toggle_status_modal
        tool_name={@platform_instance.name}
        action={:disable}
        id="disable_tool_modal"
      />
      <.toggle_status_modal
        tool_name={@platform_instance.name}
        action={:delete}
        id="delete_tool_modal"
      />
      <.make_private_modal :if={@confirming_private} tool_name={@platform_instance.name} />
      {render_custom_flash(@custom_flash)}
      <div class="w-full inline-flex flex-col justify-start items-start gap-3">
        <div class="w-full flex flex-row justify-between items-center">
          <div class="justify-center text-2xl font-normal leading-9">
            {@platform_instance.name}
          </div>
          <div :if={!@edit_mode and @deployment.status != :deleted} class="flex flex-row gap-2">
            <.button
              phx-click="toggle_edit_mode"
              class="px-3 !py-1 bg-white text-[#006cd9] border border-blue-500 rounded-md
                   hover:bg-[#006cd9] hover:text-white
                   dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
                   dark:hover:bg-[#0056ad] dark:hover:text-white dark:hover:border-[#0056ad]"
            >
              Edit Details
            </.button>
            <.button
              role="delete tool"
              phx-click={Modal.show_modal("delete_tool_modal")}
              class="px-3 !py-1 bg-white text-red-600 border border-red-500 rounded-md
                     hover:bg-red-600 hover:text-white
                     dark:bg-gray-800 dark:text-red-400 dark:border-red-400
                     dark:hover:bg-red-700 dark:hover:text-white dark:hover:border-red-700"
            >
              Delete Tool
            </.button>
          </div>
        </div>
        <div
          :if={@deployment.status != :deleted}
          class="w-full flex-row flex justify-start text-lg font-normal"
        >
          <text>
            Enable tool for project and course section use
          </text>
          <.toggle_switch
            id="toggle_tool_switch"
            role="toggle_tool_switch"
            class="ml-4 flex items-center h-9"
            checked={@deployment.status == :enabled}
            with_confirmation={true}
            on_toggle={
              if(@deployment.status == :enabled,
                do: Modal.show_modal("disable_tool_modal"),
                else: "toggle_tool_status"
              )
            }
          />
        </div>

        <div class="w-full flex-row flex justify-start text-lg font-normal">
          <text>
            Enable deep linking for this tool
          </text>
          <.toggle_switch
            id="toggle_deep_linking_switch"
            role="toggle_deep_linking_switch"
            class="ml-4 flex items-center h-9"
            checked={@deployment.deep_linking_enabled}
            on_toggle="toggle_deep_linking_enabled"
          />
        </div>

        <div :if={@deployment.status != :deleted} class="w-full flex flex-col gap-1">
          <form id="availability_form" phx-change="change_availability" phx-auto-recover="ignore">
            <RadioGroup.radio_group
              id={"availability-#{@availability_rev}"}
              name="availability"
              legend="Availability"
              aria-describedby="availability_help"
              options={[%{value: :public, label: "Public"}, %{value: :private, label: "Private"}]}
              value={if @confirming_private, do: :private, else: @deployment.availability}
              orientation={:horizontal}
              class="flex items-center gap-6"
              legend_class="float-left text-lg leading-9"
            />
          </form>
          <p id="availability_help" class="text-sm text-Text-text-low">
            {availability_help(@deployment.availability)}
          </p>
        </div>

        <.granted_projects
          :if={@deployment.status != :deleted and @deployment.availability == :private}
          granted_projects={@granted_projects}
          granted_table={@granted_table}
          granted_total={@granted_total}
          granted_query={@granted_query}
          granted_offset={@granted_offset}
          project_query={@project_query}
          results_table={@results_table}
          search_results={@search_results}
          more_results?={@more_results?}
        />
      </div>
      <Form.tool_form form={@form} action={:update} edit_mode={@edit_mode} />
    </div>
    """
  end

  attr :tool_name, :string, required: true
  attr :action, :atom, required: true
  attr :id, :string, required: true

  defp toggle_status_modal(assigns) do
    ~H"""
    <Modal.modal
      id={@id}
      class="!w-1/2"
      header_class="flex items-start justify-between p-6 border-b border-gray-300"
      confirm_class={modal_confirm_class()}
      cancel_class={modal_cancel_class()}
      on_confirm={
        JS.push(push_action(@action))
        |> Modal.hide_modal(@id)
      }
    >
      <:title>{stringify_action(@action)} {@tool_name}?</:title>
      <.modal_message action={@action} />
      <:cancel>Cancel</:cancel>
      <:confirm>{stringify_action(@action)} Tool</:confirm>
    </Modal.modal>
    """
  end

  defp modal_confirm_class, do: @modal_confirm_class
  defp modal_cancel_class, do: @modal_cancel_class

  attr :tool_name, :string, required: true

  defp make_private_modal(assigns) do
    ~H"""
    <Modal.modal
      id="make_private_modal"
      show={true}
      class="max-w-xl"
      header_class="flex items-start justify-between p-6 border-b border-gray-300"
      confirm_class={modal_confirm_class()}
      cancel_class={modal_cancel_class() <> " !px-3"}
      on_cancel={JS.push("cancel_private")}
      on_confirm={JS.push("confirm_private") |> Modal.hide_modal("make_private_modal")}
    >
      <:title>Make {@tool_name} private?</:title>
      <div class="text-base font-medium">
        Only the projects you grant access to will be able to add this tool. Projects that already added it keep it, and their existing activities keep launching.
      </div>
      <:cancel>Cancel</:cancel>
      <:confirm>Make Private</:confirm>
    </Modal.modal>
    """
  end

  defp availability_help(:private),
    do:
      "Only the projects below can add this tool. Projects that already added it are not affected."

  defp availability_help(:public), do: "Any project can add this tool."

  attr :granted_projects, :list, required: true
  attr :granted_table, :map, required: true
  attr :granted_total, :integer, required: true
  attr :granted_query, :string, required: true
  attr :granted_offset, :integer, required: true
  attr :project_query, :string, required: true
  attr :results_table, :map, required: true
  attr :search_results, :list, required: true
  attr :more_results?, :boolean, required: true

  defp granted_projects(assigns) do
    ~H"""
    <div id="tool_grants" class="w-full max-w-[760px] flex flex-col gap-6 mt-2">
      <div class="flex flex-col gap-2">
        <h3 class="text-lg font-normal">
          Projects with access{if @granted_projects != [], do: " (#{length(@granted_projects)})"}
        </h3>
        <%= if @granted_projects == [] do %>
          <p id="no_grants" class="text-base text-Text-text-low">
            No project can add this tool yet.
          </p>
        <% else %>
          <div class="w-full max-w-[420px] [&_[data-search-bar-state]]:w-full">
            <Filter.render
              id="granted_filter"
              apply_icon={true}
              change="filter_grants"
              apply="filter_grants"
              reset="reset_grants_filter"
              clear_id="reset_grants_filter"
              query={@granted_query}
              placeholder="Filter by title or ID"
              aria_label="Filter projects with access"
              debounce="300"
            />
          </div>
          <div id="granted_projects_table">
            <Listing.render
              filter={@granted_query}
              table_model={@granted_table}
              total_count={@granted_total}
              offset={@granted_offset}
              limit={grants_per_page()}
              sort="sort_grants"
              page_change="page_grants"
              show_bottom_paging={false}
              additional_table_class=""
              empty_state_text="No project with access matches this filter."
            />
          </div>
        <% end %>
      </div>

      <div id="grant_search" class="flex flex-col gap-2">
        <p class="text-base font-normal">Grant access to a project</p>
        <div class="w-full max-w-[420px] [&_[data-search-bar-state]]:w-full">
          <Filter.render
            id="project_search"
            apply_icon={true}
            change="search_projects"
            apply="search_projects"
            reset="clear_project_search"
            clear_id="clear_project_search"
            query={@project_query}
            placeholder="Search active projects by title or ID"
            aria_label="Search projects to grant access"
            debounce="300"
          />
        </div>
        <p :if={@more_results?} id="more_results_notice" class="text-sm text-Text-text-low">
          Showing the first {search_results_shown()} matches. Type more to narrow the search.
        </p>
        <div :if={@search_results != []} id="search_results_table">
          <Table.render model={@results_table} sort="sort_grants" additional_table_class="" />
        </div>
        <p
          :if={@search_results == [] and String.trim(@project_query) != ""}
          id="no_search_results"
          class="text-sm text-Text-text-low"
        >
          No matching projects.
        </p>
      </div>
    </div>
    """
  end

  defp grants_per_page, do: @grants_per_page
  defp search_results_shown, do: @search_results_shown

  def render_project(assigns, project, spec),
    do: OliWeb.Projects.TableModel.custom_render(assigns, project, spec)

  def render_project_action(assigns, project, %ColumnSpec{name: action}) do
    assigns =
      Map.merge(assigns, %{
        project: project,
        event: if(action == :remove, do: "revoke_project", else: "grant_project"),
        label: if(action == :remove, do: "Remove", else: "Grant access")
      })

    ~H"""
    <Button.button
      variant={:secondary}
      size={:sm}
      phx-click={@event}
      phx-value-id={@project.id}
      aria-label={"#{@label} for #{@project.title} (#{@project.slug})"}
    >
      {@label}
    </Button.button>
    """
  end

  defp stringify_action(:disable), do: "Disable"
  defp stringify_action(:delete), do: "Delete"

  defp push_action(:delete), do: "delete_tool"
  defp push_action(:disable), do: "toggle_tool_status"

  attr :action, :atom, required: true

  defp modal_message(%{action: :disable} = assigns) do
    ~H"""
    <div class="text-base font-medium">
      Disabling this tool will disable its functionality across projects, templates, active course sections. Course authors and instructors will be notified of this change on the affected pages. Functionality will be fully restored if the tool is re-enabled.
    </div>
    """
  end

  defp modal_message(%{action: :delete} = assigns) do
    ~H"""
    <div class="text-base font-medium">
      Deleting this tool will disable its functionality across projects, templates, and course sections and
      <span class="font-bold">permanently delete the tool from the system.</span>
      Course authors and instructors will be notified of this change on the affected pages.
    </div>
    """
  end

  def handle_event("validate", %{"tool_form" => params}, socket) do
    changeset =
      %PlatformInstance{}
      |> PlatformInstances.change_platform_instance(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, as: :tool_form))
     |> assign(:custom_flash, nil)}
  end

  def handle_event("update_tool", %{"tool_form" => params}, socket) do
    case PlatformExternalTools.update_lti_external_tool_activity(
           socket.assigns.platform_instance.id,
           params
         ) do
      {:ok, %{updated_platform_instance: platform_instance}} ->
        new_changeset = PlatformExternalTools.change_platform_instance(platform_instance)

        {:noreply,
         socket
         |> assign(form: to_form(new_changeset, as: :tool_form))
         |> assign(edit_mode: false)
         |> assign(:custom_flash, %{
           type: :success,
           message: "You have successfully updated the LTI 1.3 External Tool."
         })}

      {:error, _, %Ecto.Changeset{} = changeset, _} ->
        {flash_type, flash_message} =
          if Enum.any?(changeset.errors, fn
               {:client_id, {"has already been taken", _}} -> true
               _ -> false
             end) do
            {:duplicate, "The client ID already exists and must be unique."}
          else
            {:error, "One or more of the required fields is missing; please check your input."}
          end

        {:noreply,
         socket
         |> assign(form: to_form(changeset, as: :tool_form))
         |> assign(:custom_flash, %{
           type: flash_type,
           message: flash_message
         })}

      {:error, _, {:not_found}, _} ->
        {:noreply,
         socket
         |> assign(:custom_flash, %{
           type: :not_found,
           message: "This platform instance no longer exists or couldn’t be found."
         })}
    end
  end

  def handle_event("clear-custom-flash", _params, socket) do
    {:noreply, assign(socket, custom_flash: nil)}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_mode, !socket.assigns.edit_mode)}
  end

  def handle_event("toggle_tool_status", _params, socket) do
    new_status =
      case socket.assigns.deployment.status do
        :enabled -> :disabled
        :disabled -> :enabled
      end

    case PlatformExternalTools.update_lti_external_tool_activity_deployment(
           socket.assigns.deployment,
           %{"status" => new_status}
         ) do
      {:ok, deployment} ->
        {:noreply,
         socket
         |> assign(deployment: deployment)
         |> assign(:custom_flash, %{
           type: :success,
           message:
             "You have successfully #{Atom.to_string(new_status)} the LTI 1.3 External Tool."
         })}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:custom_flash, %{
           type: :error,
           message: "There was an error updating the status of the LTI 1.3 External Tool."
         })}
    end
  end

  def handle_event("toggle_deep_linking_enabled", _params, socket) do
    new_value = !socket.assigns.deployment.deep_linking_enabled

    case PlatformExternalTools.update_lti_external_tool_activity_deployment(
           socket.assigns.deployment,
           %{"deep_linking_enabled" => new_value}
         ) do
      {:ok, deployment} ->
        {:noreply,
         socket
         |> assign(deployment: deployment)
         |> assign(:custom_flash, %{
           type: :success,
           message:
             "You have successfully #{if new_value, do: "enabled", else: "disabled"} deep linking for the LTI 1.3 External Tool."
         })}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:custom_flash, %{
           type: :error,
           message:
             "There was an error updating the deep linking setting of the LTI 1.3 External Tool."
         })}
    end
  end

  def handle_event("delete_tool", _params, socket) do
    case PlatformExternalTools.soft_delete_activity_deployment_and_platform_instance(
           socket.assigns.deployment
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "LTI 1.3 External tool deleted successfully.")
         |> push_navigate(to: ~p"/admin/external_tools")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error deleting external tool.")}
    end
  end

  def handle_event("change_availability", %{"availability" => availability}, socket) do
    case {availability, socket.assigns.deployment.availability} do
      {"private", :public} ->
        {:noreply, assign(socket, confirming_private: true)}

      {"public", :private} ->
        socket |> authorized(&save_availability(&1, :public)) |> redraw_if_unsaved()

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_private", _params, socket) do
    {:noreply, assign(socket, confirming_private: false)}
  end

  def handle_event("confirm_private", _params, socket) do
    socket
    |> assign(confirming_private: false)
    |> authorized(&save_availability(&1, :private))
  end

  def handle_event("filter_grants", %{"value" => query}, socket) do
    authorized(socket, fn socket ->
      {:noreply,
       socket |> assign(granted_query: query, granted_offset: 0) |> assign_granted_table()}
    end)
  end

  def handle_event("reset_grants_filter", _params, socket) do
    authorized(socket, fn socket ->
      {:noreply, socket |> assign(granted_query: "", granted_offset: 0) |> assign_granted_table()}
    end)
  end

  def handle_event("page_grants", %{"offset" => offset}, socket) do
    authorized(socket, fn socket ->
      case Integer.parse(offset) do
        {offset, ""} ->
          {:noreply, socket |> assign(granted_offset: offset) |> assign_granted_table()}

        _ ->
          {:noreply, socket}
      end
    end)
  end

  def handle_event("sort_grants", _params, socket) do
    authorized(socket, fn socket ->
      order = if socket.assigns.granted_sort_order == :asc, do: :desc, else: :asc

      {:noreply,
       socket |> assign(granted_sort_order: order, granted_offset: 0) |> assign_granted_table()}
    end)
  end

  def handle_event("search_projects", %{"value" => query}, socket) do
    authorized(socket, fn socket ->
      {:noreply, socket |> assign(project_query: query) |> assign_search_results()}
    end)
  end

  def handle_event("clear_project_search", _params, socket) do
    authorized(socket, fn socket ->
      {:noreply, socket |> assign(project_query: "") |> assign_search_results()}
    end)
  end

  def handle_event("grant_project", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {project_id, ""} -> authorized(socket, &grant_project(&1, project_id))
      _ -> {:noreply, socket}
    end
  end

  def handle_event("revoke_project", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {project_id, ""} -> authorized(socket, &revoke_project(&1, project_id))
      _ -> {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket) do
    # Catch-all for UI-only events from functional components
    # that don't need handling (like dropdown toggles)
    Logger.warning("Unhandled event in DetailsView: #{inspect(event)}, #{inspect(params)}")
    {:noreply, socket}
  end

  defp authorized(socket, action) do
    with %Author{} = author <- Accounts.get_author(socket.assigns.current_author.id),
         true <- Accounts.at_least_account_admin?(author) do
      action.(socket)
    else
      _ ->
        {:noreply,
         assign(socket, :custom_flash, %{
           type: :unauthorized,
           message: "Only account administrators can view or change who can use this tool."
         })}
    end
  end

  # The browser already shows Public checked. When it was not saved, the server's HTML is unchanged and
  # LiveView leaves the radios alone, so new input ids make it render them again from the stored value.
  defp redraw_if_unsaved(
         {:noreply, %{assigns: %{deployment: %{availability: :private}}} = socket}
       ),
       do: {:noreply, update(socket, :availability_rev, &(&1 + 1))}

  defp redraw_if_unsaved(result), do: result

  defp save_availability(socket, availability) do
    case PlatformExternalTools.set_availability(socket.assigns.deployment, availability) do
      {:ok, deployment} ->
        {:noreply,
         socket
         |> assign(deployment: deployment)
         |> assign(:custom_flash, %{
           type: :success,
           message: "You have successfully made the LTI 1.3 External Tool #{availability}."
         })}

      {:error, _} ->
        {:noreply,
         assign(socket, :custom_flash, %{
           type: :failed,
           message: "There was an error updating the availability of the LTI 1.3 External Tool."
         })}
    end
  end

  defp grant_project(socket, project_id) do
    title = project_title(socket.assigns.search_results, project_id)

    case PlatformExternalTools.grant_project(socket.assigns.deployment, project_id) do
      {:ok, _grant} ->
        {:noreply,
         socket
         |> load_granted_projects()
         |> assign_search_results()
         |> assign(:custom_flash, %{
           type: :success,
           message: "You have successfully granted access to #{title}."
         })}

      {:error, :project_not_active} ->
        {:noreply,
         socket
         |> assign_search_results()
         |> assign(:custom_flash, %{
           type: :failed,
           message: "#{title} is no longer active, so it can't be granted access."
         })}

      {:error, _} ->
        {:noreply,
         assign(socket, :custom_flash, %{
           type: :failed,
           message: "There was an error granting access to #{title}."
         })}
    end
  end

  defp revoke_project(socket, project_id) do
    title = project_title(socket.assigns.granted_projects, project_id)
    :ok = PlatformExternalTools.revoke_project(socket.assigns.deployment, project_id)

    {:noreply,
     socket
     |> load_granted_projects()
     |> assign_search_results()
     |> assign(:custom_flash, %{
       type: :success,
       message: "You have successfully removed access for #{title}."
     })}
  end

  defp project_title(projects, project_id) do
    case Enum.find(projects, &(&1.id == project_id)) do
      nil -> "the project"
      project -> project.title
    end
  end

  defp load_granted_projects(socket) do
    socket
    |> assign(
      :granted_projects,
      PlatformExternalTools.list_granted_projects(socket.assigns.deployment)
    )
    |> assign_granted_table()
  end

  defp assign_granted_table(socket) do
    %{granted_projects: projects, granted_query: query, granted_sort_order: order} =
      socket.assigns

    matching = filter_projects(projects, query)
    total = length(matching)
    offset = last_page_offset(socket.assigns.granted_offset, total)
    [title_spec | _] = columns = project_columns(:remove)

    {:ok, table} =
      SortableTableModel.new(
        rows: matching,
        column_specs: columns,
        event_suffix: "",
        id_field: ["granted", :id],
        sort_by_spec: title_spec,
        sort_order: order,
        data: %{ctx: socket.assigns.ctx, search_term: String.trim(query)}
      )

    assign(socket,
      granted_table: %{table | rows: Enum.slice(table.rows, offset, @grants_per_page)},
      granted_total: total,
      granted_offset: offset
    )
  end

  defp filter_projects(projects, query) do
    case query |> String.trim() |> String.downcase() do
      "" ->
        projects

      text ->
        Enum.filter(projects, fn project ->
          String.contains?(String.downcase(project.title), text) or
            String.contains?(String.downcase(project.slug), text)
        end)
    end
  end

  # After a removal empties the last page, show the page before it.
  defp last_page_offset(offset, total) when offset > 0 and offset >= total,
    do: max(div(total - 1, @grants_per_page) * @grants_per_page, 0)

  defp last_page_offset(offset, _total), do: offset

  defp assign_search_results(socket) do
    text = String.trim(socket.assigns.project_query)

    found =
      case text do
        "" ->
          []

        text ->
          PlatformExternalTools.search_projects_to_grant(
            socket.assigns.deployment,
            text,
            @search_results_shown + 1
          )
      end

    results = Enum.take(found, @search_results_shown)

    {:ok, table} =
      SortableTableModel.new(
        rows: results,
        column_specs: project_columns(:grant),
        event_suffix: "",
        id_field: ["result", :id],
        data: %{ctx: socket.assigns.ctx, search_term: text}
      )

    assign(socket,
      search_results: results,
      more_results?: length(found) > @search_results_shown,
      results_table: table
    )
  end

  # Search results are the first matches of possibly many, so they are not sortable. Both tables
  # prefix their row ids, because a grant removed elsewhere can show one project in both at once.
  defp project_columns(action) do
    [
      %ColumnSpec{
        name: :title,
        label: "Project",
        render_fn: &__MODULE__.render_project/3,
        sortable: action == :remove
      },
      %ColumnSpec{
        name: action,
        label: "Action",
        render_fn: &__MODULE__.render_project_action/3,
        sortable: false,
        th_class: "text-center",
        td_class: "text-center"
      }
    ]
  end

  defp render_custom_flash(nil), do: nil

  defp render_custom_flash(%{type: type, message: message}) do
    {bg_class, text_color, label} =
      case type do
        :success -> {"bg-[#F2F9FF]", "#1b67b2", "Success!"}
        :error -> {"bg-[#FEEBED]", "#ce2c31", "Missing Fields"}
        :duplicate -> {"bg-[#FEEBED]", "#ce2c31", "ID Already Exists"}
        :not_found -> {"bg-[#FEEBED]", "#ce2c31", "Record Not Found"}
        :unauthorized -> {"bg-[#FEEBED]", "#ce2c31", "Not Authorized"}
        :failed -> {"bg-[#FEEBED]", "#ce2c31", "Not Saved"}
      end

    assigns = %{
      bg_class: bg_class,
      text_color: text_color,
      label: label,
      type: type,
      message: message
    }

    ~H"""
    <div id="flash" class={"#{@bg_class} px-6 py-4 rounded-md relative mb-8"}>
      <div class="flex items-start justify-between gap-4">
        <div class="flex items-center gap-2 font-semibold">
          <%= case @type do %>
            <% :success -> %>
              <Icons.check stroke_class="stroke-blue-600" />
            <% t when t in [:error, :duplicate, :not_found, :unauthorized, :failed] -> %>
              <Icons.alert />
          <% end %>
          <span class={"text-[#{@text_color}] text-base font-semibold"}>
            {@label}
          </span>
        </div>
        <button
          phx-click="clear-custom-flash"
          class={"text-sm hover:opacity-70 text-[#{@text_color}]"}
        >
          ✕
        </button>
      </div>
      <p class="mt-1 text-[#353740] text-sm font-normal">{@message}</p>
    </div>
    """
  end
end
