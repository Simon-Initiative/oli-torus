defmodule OliWeb.UserLoginLive do
  use OliWeb, :live_view

  import OliWeb.Icons
  import OliWeb.Backgrounds
  import Oli.VendorProperties

  # Renders the instructor-specific sign in page.
  @impl Phoenix.LiveView
  def render(%{live_action: :instructor_new} = assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.instructor_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full lg:w-1/2 flex items-start lg:pt-10 justify-center">
          <div class="w-96 flex-col justify-start items-start gap-3.5 inline-flex">
            <div class="text-left">
              <span class="text-white text-4xl font-normal font-['Open Sans'] leading-10">
                Welcome to
              </span>
              <span class="text-white text-4xl font-bold font-['Open Sans'] leading-10">
                <%= product_short_name() %>
              </span>
            </div>
            <div class="w-48 h-11 justify-start items-end gap-1 inline-flex">
              <div class="justify-start items-end gap-px flex">
                <div class="grow shrink basis-0 self-start px-1 py-2 justify-center items-center flex">
                  <.bar_chart class="stroke-white" />
                </div>
                <div class="w-40 h-11 text-center text-white text-4xl font-bold font-['Open Sans']">
                  Instructor
                </div>
              </div>
            </div>
            <div class="lg:mt-6 text-white text-xl font-normal leading-normal">
              Gain insights into student engagement, progress, and learning patterns.
            </div>
          </div>
        </div>

        <div class="w-full lg:w-1/2 flex items-center justify-center dark">
          <Components.Auth.login_form
            title="Instructor Sign In"
            form={@form}
            action={~p"/users/log_in?#{[request_path: ~p"/workspaces/instructor"]}"}
            registration_link={~p"/users/register"}
            reset_password_link={~p"/users/reset_password"}
            authentication_providers={@authentication_providers}
            auth_provider_path_fn={&~p"/users/auth/#{&1}/new"}
          />
        </div>
      </div>
    </div>
    """
  end

  # Renders the default sign in page.
  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.student_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <Components.Auth.login_form
            title="Sign In"
            form={@form}
            action={~p"/users/log_in"}
            registration_link={~p"/users/register"}
            reset_password_link={~p"/users/reset_password"}
            authentication_providers={@authentication_providers}
            auth_provider_path_fn={&~p"/users/auth/#{&1}/new"}
            from_invitation_link?={@from_invitation_link?}
            section={@section}
          />
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_, session, socket) do
    title = session["title"] || brand_name()

    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    authentication_providers =
      Oli.AssentAuth.UserAssentAuth.authentication_providers() |> Keyword.keys()

    {:ok,
     assign(socket,
       title: title,
       form: form,
       authentication_providers: authentication_providers,
       from_invitation_link?: false,
       section: nil
     ), temporary_assigns: [form: form]}
  end

  @impl Phoenix.LiveView
  def handle_params(unsigned_params, _uri, socket) do
    from_invitation_link? = unsigned_params["from_invitation_link?"] == "true"
    section = unsigned_params["section"]

    {:noreply, assign(socket, from_invitation_link?: from_invitation_link?, section: section)}
  end
end
