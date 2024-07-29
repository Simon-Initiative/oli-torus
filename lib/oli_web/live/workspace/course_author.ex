defmodule OliWeb.Workspace.CourseAuthor do
  use OliWeb, :live_view

  alias OliWeb.Backgrounds
  alias OliWeb.Common.Params
  alias OliWeb.Icons

  @default_params %{
    sidebar_expanded: true
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, %{assigns: %{current_author: current_author}} = socket)
      when not is_nil(current_author) do
    {:ok,
     assign(socket,
       active_workspace: :course_author,
       header_enabled?: true,
       footer_enabled?: true
     )}
  end

  def mount(_params, _session, socket) do
    # no current author case...
    {:ok,
     assign(socket,
       current_author: nil,
       active_workspace: :course_author,
       header_enabled?: false,
       footer_enabled?: false
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, params: decode_params(params))}
  end

  @impl Phoenix.LiveView

  def render(%{current_author: nil} = assigns) do
    ~H"""
    <div class="flex justify-center items-center min-h-screen">
      <div class="absolute h-full w-full top-0 left-0">
        <Backgrounds.course_author_workspace_sign_in />
      </div>
      <div class="z-20 flex justify-center gap-2 lg:gap-12 xl:gap-32 px-6 sm:px-0">
        <div class="w-1/4 lg:w-1/2 flex items-start justify-center">
          <div class="w-96 flex-col justify-start items-start gap-0 lg:gap-3.5 inline-flex">
            <div class="text-left lg:text-3xl xl:text-4xl">
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
                  <OliWeb.Icons.writing_pencil
                    class="w-7 h-6 lg:w-[36px] lg:h-[36px]"
                    stroke_class="stroke-white"
                  />
                </div>
                <div class="w-40 lg:text-center text-white lg:text-3xl xl:text-4xl font-bold font-['Open Sans'] whitespace-nowrap">
                  Course Author
                </div>
              </div>
            </div>
            <div class="lg:mt-6 text-white lg:text-lg xl:text-xl font-normal leading-normal">
              Create, deliver, and continuously improve course materials.
            </div>
          </div>
        </div>
        <div class="lg:w-1/2 flex items-center justify-center">
          <div class="w-[360px] lg:w-96 bg-neutral-700 rounded-md">
            <div class="text-center text-white text-xl font-normal font-['Open Sans'] leading-7 py-8">
              Course Author Sign In
            </div>
            <%!-- <%= for link <- OliWeb.Pow.PowHelpers.provider_links(@socket), do: raw(link) %> --%>
            <div class="my-4 text-center text-white text-base font-normal font-['Open Sans'] leading-snug">
              OR
            </div>
            <%= form_for :user, Routes.session_path(@socket, :signin, type: :author, after_sign_in_target: :course_author_workspace), [as: :user], fn f -> %>
              <div class="flex flex-col gap-y-2">
                <div class="w-80 h-11 m-auto form-label-group border-none">
                  <%= email_input(f, Pow.Ecto.Schema.user_id_field(@socket),
                    class:
                      "form-control placeholder:text-zinc-300 !pl-6 h-11 !bg-stone-900 !rounded-md !border !border-zinc-300 !text-zinc-300 text-base font-normal font-['Open Sans'] leading-snug",
                    placeholder: "Email",
                    required: true,
                    autofocus: true
                  ) %>
                  <%= error_tag(f, Pow.Ecto.Schema.user_id_field(@socket)) %>
                </div>
                <div class="w-80 h-11 m-auto form-label-group border-none">
                  <%= password_input(f, :password,
                    class:
                      "form-control placeholder:text-zinc-300 !pl-6 h-11 !bg-stone-900 !rounded-md !border !border-zinc-300 !text-zinc-300 text-base font-normal font-['Open Sans'] leading-snug",
                    placeholder: "Password",
                    required: true
                  ) %>
                  <%= error_tag(f, :password) %>
                </div>
              </div>
              <div class="mb-4 d-flex flex-row justify-between px-8 pb-2 pt-6">
                <%= unless Application.fetch_env!(:oli, :always_use_persistent_login_sessions) do %>
                  <div class="flex items-center gap-x-2 custom-control custom-checkbox">
                    <%= checkbox(f, :persistent_session,
                      class: "w-4 h-4 !border !border-white",
                      style: "background-color: #171717"
                    ) %>
                    <%= label(f, :persistent_session, "Remember me",
                      class:
                        "text-center text-white text-base font-normal font-['Open Sans'] leading-snug"
                    ) %>
                  </div>
                <% else %>
                  <div></div>
                <% end %>
                <div class="custom-control">
                  <%= link("Forgot password?",
                    to: Routes.pow_reset_password_reset_password_path(@socket, :new),
                    tabindex: "1",
                    class:
                      "text-center text-[#4ca6ff] text-base font-bold font-['Open Sans'] leading-snug"
                  ) %>
                </div>
              </div>

              <div class="flex justify-center">
                <%= submit("Sign In",
                  class:
                    "w-80 h-11 bg-[#0062f2] mx-auto text-white text-xl font-normal leading-7 rounded-md btn btn-md btn-block mb-16 mt-2"
                ) %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="dark:bg-[#0F0D0F] bg-[#F3F4F8]">
      <div class="relative flex items-center h-[247px]">
        <div class="absolute top-0 h-full w-full">
          <Backgrounds.instructor_dashboard_header />
        </div>
        <div class="flex-col justify-start items-start gap-[15px] z-10 px-[63px] font-['Open Sans']">
          <div class="flex flex-row items-center gap-3">
            <Icons.growing_bars
              stroke_class="stroke-[#353740] dark:stroke-white"
              class="w-[36px] h-[36px]"
            />
            <h1 class="text-[#353740] dark:text-white text-[32px] font-bold leading-normal">
              Course Author
            </h1>
          </div>
          <h2 class="text-[#353740] dark:text-white text-base font-normal leading-normal">
            This is a placeholder for ticket MER-3320
          </h2>
        </div>
      </div>

      <div class="flex flex-col items-start mt-[40px] gap-9 py-[60px] px-[63px]">
        <div class="flex flex-col gap-4">
          <h3 class="dark:text-violet-100 text-xl font-bold font-['Open Sans'] leading-normal whitespace-nowrap">
            Some title
          </h3>
          <div class="dark:text-violet-100 text-base font-normal font-['Inter'] leading-normal">
            some text
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp decode_params(params) do
    %{
      sidebar_expanded:
        Params.get_boolean_param(params, "sidebar_expanded", @default_params.sidebar_expanded)
    }
  end
end
