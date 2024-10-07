defmodule OliWeb.Delivery.Student.ReviewLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils, only: [page_header: 1]

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Delivery.Student.Utils

  require Logger

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[:id, :slug, :title, :brand, :lti_1p3_deployment, :customizations], %Sections.Section{}}
  }

  def mount(
        %{
          "attempt_guid" => attempt_guid
        } = params,
        session,
        %{assigns: %{section: section}} = socket
      ) do

    Logger.debug("ReviewLive mount")

    is_system_admin = Map.get(socket.assigns, :is_system_admin, false)
    current_user = Map.get(socket.assigns, :current_user)

    if connected?(socket) do

      Logger.debug("ReviewLive mount, connected")
      user = Oli.Delivery.Attempts.Core.get_user_from_attempt_guid(attempt_guid)

      Logger.debug("ReviewLive mount, got user")
      page_context = PageContext.create_for_review(section.slug, attempt_guid, user, false)

      Logger.debug("ReviewLive mount, created context")
      socket = assign(socket, page_context: page_context)

      socket =
        if Map.get(socket.assigns, :user_token) == nil do
          assign(socket, user_token: "")
        else
          socket
        end

      {:cont, socket} =
        OliWeb.LiveSessionPlugs.InitPage.on_mount(:init_context_state, params, session, socket)
      Logger.debug("ReviewLive mount, ran init_context_state")

      {:cont, socket} =
        OliWeb.LiveSessionPlugs.InitPage.on_mount(:previous_next_index, params, session, socket)
      Logger.debug("ReviewLive mount, ran previous_next_index")

      {:cont, socket} =
        OliWeb.LiveSessionPlugs.SetRequestPath.on_mount(:default, params, session, socket)
      Logger.debug("ReviewLive mount, ran SetRequestPath")

      socket = assign(socket, loaded: true)

      page_revision = page_context.page

      if (is_system_admin or
            PageLifecycle.can_access_attempt?(attempt_guid, current_user, section)) and
           review_allowed?(page_context) do
        socket =
          socket
          |> assign(page_context: page_context)
          |> assign(page_progress_state: page_context.progress_state)
          |> assign(page_revision: page_revision)
          |> assign_html_and_scripts()
          |> assign_objectives()
          |> slim_assigns()

        #script_sources =
        #  Enum.map(socket.assigns.scripts, fn script -> "/js/#{script}" end)

        #send(self(), :gc)

        {:ok, socket}

        # These temp assigns were disabled in MER-3672
        #  temporary_assigns: [
        #    scripts: [],
        #    html: [],
        #    page_context: %{},
        #    page_revision: %{},
        #    objectives: []
        #  ]}
      else
        Logger.debug("ReviewLive mount, did not have permission")

        {:ok,
         socket
         |> put_flash(:error, "You are not allowed to review this attempt.")
         |> redirect(to: Utils.learn_live_path(section.slug))}
      end
    else
      {:ok, assign(socket, loaded: false)}
    end
  end

  def handle_info(:gc, socket) do
    :erlang.garbage_collect(socket.transport_pid)
    :erlang.garbage_collect(self())
    {:noreply, socket}
  end

  defp assign_objectives(socket) do
    %{page_context: %{page: page, user: current_user}, section: section} =
      socket.assigns

    page_attached_objectives =
      Resolver.objectives_by_resource_ids(page.objectives["attached"], section.slug)

    student_proficiency_per_page_level_learning_objective =
      Metrics.proficiency_for_student_per_learning_objective(
        page_attached_objectives,
        current_user.id,
        section
      )

    objectives =
      page_attached_objectives
      |> Enum.map(fn rev ->
        %{
          resource_id: rev.resource_id,
          title: rev.title,
          proficiency:
            Map.get(
              student_proficiency_per_page_level_learning_objective,
              rev.resource_id,
              "Not enough data"
            )
        }
      end)

    assign(socket,
      objectives: objectives
    )
  end

  defp review_allowed?(page_context),
    do: page_context.effective_settings.review_submission == :allow

  def render(%{loaded: false} = assigns) do
    ~H"""
    <div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex flex-col items-center w-full">
        <div class="w-full h-[120px] lg:px-20 px-40 py-9 bg-blue-600 bg-opacity-10 flex flex-col justify-center items-center gap-2.5">
          <div class="px-3 py-1.5 rounded justify-start items-start gap-2.5 flex">
            <div class="dark:text-white text-sm font-bold uppercase tracking-wider">
              Review
            </div>
          </div>
        </div>
        <div class="w-full max-w-[1040px] px-[80px] pt-20 pb-10 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            index={@current_page["index"]}
            objectives={@objectives}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />
          <div id="eventIntercept" phx-update="ignore" class="content w-full" role="page_content">
            <%= raw(@html) %>
          </div>
          <.link
            href={
              Utils.lesson_live_path(@section.slug, @page_revision.slug, request_path: @request_path)
            }
            role="back_to_summary_link"
          >
            <div class="h-10 px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded shadow justify-center items-center gap-2.5 inline-flex">
              <div class="text-white text-sm font-normal leading-tight">
                Back to Summary Screen
              </div>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, scripts_loaded: true)}
  end

  defp assign_html_and_scripts(socket) do
    socket
    |> assign(html: Utils.build_html(socket.assigns, :review, is_liveview: true))
    |> assign(
      scripts: Utils.get_required_activity_scripts(socket.assigns.page_context.activities || [])
    )
  end

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end
end
