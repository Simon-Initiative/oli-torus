defmodule OliWeb.Delivery.Student.ReviewLive do
  use OliWeb, :live_view

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :init_context_state}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  import OliWeb.Delivery.Student.Utils,
    only: [page_header: 1, scripts: 1]

  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Delivery.Student.Utils

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section: {[:id, :slug, :title, :brand, :lti_1p3_deployment], %Sections.Section{}},
    current_user: {[:id, :name, :email], %User{}}
  }

  def mount(
        %{
          "revision_slug" => revision_slug,
          "attempt_guid" => attempt_guid
        },
        _session,
        %{assigns: %{current_user: user, section: section}} = socket
      ) do
    page_revision = Resolver.from_revision_slug(section.slug, revision_slug)

    page_context = PageContext.create_for_review(section.slug, attempt_guid, user, false)

    socket =
      if PageLifecycle.can_access_attempt?(attempt_guid, user, section) and
           review_allowed?(page_context) do
        socket
        |> assign(page_context: page_context)
        |> assign(page_revision: page_revision)
        |> assign_html_and_scripts()
        |> assign_objectives()
        |> slim_assigns()
      else
        socket
        |> put_flash(:error, "You are not allowed to review this attempt.")
        |> redirect(to: Utils.learn_live_path(section.slug))
      end

    if connected?(socket) do
      send(self(), :gc)
    end

    {:ok, socket,
     temporary_assigns: [
       scripts: [],
       html: [],
       page_context: %{},
       page_revision: %{},
       objectives: []
     ]}
  end

  def handle_info(:gc, socket) do
    :erlang.garbage_collect(socket.transport_pid)
    :erlang.garbage_collect(self())
    {:noreply, socket}
  end

  defp assign_objectives(socket) do
    %{page_context: %{page: page}, current_user: current_user, section: section} =
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

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  defp assign_html_and_scripts(socket) do
    socket
    |> assign(html: Utils.build_html(socket.assigns, :review))
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
