defmodule OliWeb.Workspaces.Student do
  use OliWeb, :live_view

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias OliWeb.Backgrounds
  alias OliWeb.Common.{Params, SearchInput}
  alias OliWeb.Common.SourceImage

  import Ecto.Query, warn: false
  import OliWeb.Components.Delivery.Layouts

  @default_params %{
    text_search: "",
    sidebar_expanded: true
  }

  @context_student_roles [
    Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
  ]

  def mount(_params, _session, %{assigns: %{is_admin: true}} = socket) do
    # admin case...
    {:ok, assign(socket, active_workspace: :student)}
  end

  @impl Phoenix.LiveView
  def mount(params, _session, %{assigns: %{current_user: current_user}} = socket)
      when not is_nil(current_user) do
    sections =
      current_user.id
      |> sections_where_user_is_student()
      |> add_instructors()
      |> add_sections_progress(current_user.id)

    {:ok,
     assign(socket,
       sections: sections,
       params: params,
       filtered_sections: sections,
       active_workspace: :student
     )}
  end

  def mount(_params, _session, socket) do
    # no current user case...

    authentication_providers =
      Oli.AssentAuth.UserAssentAuth.authentication_providers() |> Keyword.keys()

    {:ok,
     assign(socket,
       current_user: nil,
       active_workspace: :student,
       footer_enabled?: false,
       authentication_providers: authentication_providers
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, %{assigns: %{sections: sections}} = socket) do
    params = decode_params(params)

    {:noreply,
     assign(socket,
       filtered_sections: maybe_filter_by_text(sections, params.text_search),
       params: params
     )}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, params: decode_params(params))}
  end

  @impl Phoenix.LiveView

  def render(%{is_admin: true} = assigns) do
    ~H"""
    <div class="relative flex items-center h-[247px] w-full bg-gray-100 dark:bg-[#0B0C11]">
      <div
        class="absolute top-0 left-0 h-full w-full"
        style="background: linear-gradient(90deg, #D9D9D9 0%, rgba(217, 217, 217, 0.00) 100%);"
      />
      <h1 class="text-[64px] leading-[87px] tracking-[0.02px] pl-[100px] z-10">
        Hi, <span class="font-bold"><%= @ctx.author.given_name %></span>
      </h1>
    </div>
    <div class="flex flex-col items-start py-[60px] px-[100px]">
      <div class="flex mb-9 w-full">
        <h3 class="w-full text-xl dark:text-white">
          Student workspace with an admin account has not yet been developed.
          To use this workspace please logout and sign in with a student account
        </h3>
      </div>
    </div>
    """
  end

  def render(%{current_user: nil} = assigns) do
    ~H"""
    <div class="flex-1 flex justify-center items-center min-h-screen">
      <div class="absolute h-full w-full top-0 left-0">
        <Backgrounds.student_workspace_sign_in />
      </div>
      <div class="z-20 flex justify-center gap-2 lg:gap-12 xl:gap-32 px-6 sm:px-0">
        <div class="w-1/4 lg:w-1/2 flex items-start justify-center">
          <div class="w-96 flex-col justify-start items-start gap-0 lg:gap-3.5 inline-flex">
            <div class="text-left text-xl lg:text-3xl xl:text-4xl">
              <span class="text-white font-normal font-['Open Sans'] leading-10">
                Welcome to
              </span>
              <span class="text-white font-bold font-['Open Sans'] leading-10">
                <%= Oli.VendorProperties.product_short_name() %>
              </span>
            </div>
            <div class="w-48 h-11 justify-start items-center gap-1 inline-flex">
              <div class="justify-start items-center gap-2 lg:gap-px flex">
                <div class="grow shrink basis-0 self-start px-1 py-2 justify-center items-center flex">
                  <OliWeb.Icons.graduation_cap
                    class="w-7 h-6 lg:w-[39px] lg:h-[27px]"
                    stroke="stroke-white"
                  />
                </div>
                <div class="w-40 lg:text-center text-white lg:text-3xl xl:text-4xl font-bold font-['Open Sans']">
                  Student
                </div>
              </div>
            </div>
            <div class="lg:mt-6 text-white lg:text-lg xl:text-xl font-normal leading-normal">
              Easily access and participate in your enrolled courses
            </div>
          </div>
        </div>
        <div class="lg:w-1/2 flex items-center justify-center">
          <Components.Auth.login_form
            title="Student Sign In"
            form={to_form(%{}, as: "user")}
            action={~p"/users/log_in"}
            reset_password_link={~p"/users/reset_password"}
            authentication_providers={@authentication_providers}
            auth_provider_path_fn={&~p"/users/auth/#{&1}/new"}
          />
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="relative flex items-center min-h-[100px] md:min-h-[247px] w-full bg-gray-100 dark:bg-[#0B0C11]">
      <div
        class="absolute top-0 left-0 h-full w-full"
        style="background: linear-gradient(90deg, #D9D9D9 0%, rgba(217, 217, 217, 0.00) 100%);"
      />
      <h1 class="text-3xl md:text-[64px] leading-[87px] tracking-[0.02px] px-4 md:pl-[100px] z-10">
        Hi, <span class="font-bold"><%= user_given_name(@ctx) %></span>
      </h1>
    </div>
    <div class="flex flex-col items-start py-6 md:py-[60px] px-4 md:px-[100px]">
      <div class="flex flex-col md:flex-row mb-9 w-full">
        <h3 class="w-full py-2 md:py-0 text-xl md:text-[26px] md:leading-[32px] tracking-[0.02px] font-semibold dark:text-white">
          Courses available
        </h3>
        <div class="ml-auto flex items-center w-full justify-start md:justify-end gap-3">
          <.form for={%{}} phx-change="search_section" class="w-full max-w-[400px]">
            <SearchInput.render
              id="section_search_input"
              name="text_search"
              placeholder="Search by course or instructor name"
              text={@params.text_search}
            />
          </.form>
        </div>
      </div>

      <div class="flex w-full mb-10">
        <%= if length(@sections) == 0 do %>
          <p>You are not enrolled in any courses.</p>
        <% else %>
          <div class="flex flex-col w-full gap-3">
            <.course_card
              :for={{section, index} <- Enum.with_index(@filtered_sections)}
              index={index}
              section={section}
              params={@params}
            />
            <p :if={length(@filtered_sections) == 0} class="mt-4">
              No course found matching <strong>"<%= @params.text_search %>"</strong>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :index, :integer
  attr :section, :map
  attr :params, :map

  def course_card(assigns) do
    ~H"""
    <.link
      href={get_course_url(@section, @params.sidebar_expanded)}
      phx-click={JS.add_class("opacity-0", to: "#content")}
      phx-mounted={
        JS.transition(
          {"ease-out duration-300", "opacity-0 -translate-x-1/2", "opacity-100 translate-x-0"},
          time: if(@index < 6, do: 100 + @index * 20, else: 240)
        )
        |> JS.remove_class("opacity-100 translate-x-0")
      }
      class="opacity-0 relative flex items-center self-stretch md:h-[200px] w-full bg-cover py-4 md:py-12 px-6 md:px-24 text-white hover:text-white rounded-xl shadow-lg hover:no-underline transition-all hover:translate-x-3"
      style={"background-image: url('#{SourceImage.cover_image(@section)}');"}
    >
      <div class="top-0 left-0 rounded-xl absolute w-full h-full mix-blend-difference bg-[linear-gradient(180deg,rgba(0,0,0,0.00)_0%,rgba(0,0,0,0.80)_100%),linear-gradient(90deg,rgba(0,0,0,0.80)_0%,rgba(0,0,0,0.40)_100%)]" />
      <div class="top-0 left-0 rounded-xl absolute w-full h-full dark:bg-black/40" />
      <div class="top-0 left-0 rounded-xl absolute w-full h-full backdrop-blur-[30px] bg-[rgba(0,0,0,0.01)]" />
      <span
        :if={@section.progress == 100}
        role={"complete_badge_for_section_#{@section.id}"}
        class="absolute w-32 top-0 right-0 rounded-tr-xl rounded-bl-xl bg-[#0CAF61] uppercase py-2 text-center text-[12px] leading-[16px] tracking-[1.2px] font-bold"
      >
        Complete
      </span>
      <div class="z-10 flex w-full items-center">
        <div class="flex flex-col items-start gap-6">
          <h5 class="text-2xl md:text-[36px] md:leading-[49px] font-semibold drop-shadow-md">
            <%= @section.title %>
          </h5>
          <div
            class="flex flex-col md:flex-row drop-shadow-md"
            role={"progress_for_section_#{@section.id}"}
          >
            <h4 class="text-sm md:text-[16px] md:leading-[32px] tracking-[1.28px] uppercase mr-9">
              Course Progress
            </h4>
            <.progress_bar percent={@section.progress} show_percent={true} width="100px" />
          </div>
        </div>
        <i class="fa-solid fa-arrow-right ml-auto text-2xl p-[7px] drop-shadow-md"></i>
      </div>
    </.link>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("search_section", %{"text_search" => text_search}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/workspaces/student?#{%{socket.assigns.params | text_search: text_search}}"
     )}
  end

  defp add_instructors([]), do: []

  defp add_instructors(sections) do
    instructors_per_section = Sections.instructors_per_section(Enum.map(sections, & &1.id))

    sections
    |> Enum.map(fn section ->
      Map.merge(section, %{instructors: Map.get(instructors_per_section, section.id, [])})
    end)
  end

  defp add_sections_progress([], _user_id), do: []

  defp add_sections_progress(sections, user_id) do
    Enum.map(sections, fn section ->
      # we calculate the progress based on the number of completed pages
      # to match the logic used in the course progress compenent at OliWeb.Delivery.Student.IndexLive
      raw_completed_pages = Metrics.raw_completed_pages_for(section.id, user_id)
      completed_pages = Map.get(raw_completed_pages, user_id, 0)
      total_pages = Map.get(raw_completed_pages, :total_pages)

      progress =
        (completed_pages / if(total_pages == 0, do: 1, else: total_pages))
        |> Kernel.*(100)
        |> round()
        |> trunc()

      Map.merge(section, %{progress: progress})
    end)
  end

  defp maybe_filter_by_text(sections, nil), do: sections
  defp maybe_filter_by_text(sections, ""), do: sections

  defp maybe_filter_by_text(sections, text_search) do
    normalized_text_search = String.downcase(text_search)

    sections
    |> Enum.filter(fn section ->
      # searchs by course name or instructor name

      String.contains?(String.downcase(section.title), normalized_text_search) ||
        Enum.find(section.instructors, false, fn name ->
          String.contains?(
            String.downcase(name),
            normalized_text_search
          )
        end)
    end)
  end

  defp get_course_url(%{slug: slug}, sidebar_expanded),
    do: ~p"/sections/#{slug}?#{%{sidebar_expanded: sidebar_expanded}}"

  defp decode_params(params) do
    %{
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      sidebar_expanded:
        Params.get_boolean_param(params, "sidebar_expanded", @default_params.sidebar_expanded)
    }
  end

  defp sections_where_user_is_student(user_id) do
    Sections.get_open_and_free_active_sections_by_roles(user_id, @context_student_roles)
  end
end
