defmodule OliWeb.AuthorLoginLive do
  use OliWeb, :live_view

  import OliWeb.Icons
  import OliWeb.Backgrounds
  import Oli.VendorProperties

  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-180px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-180px)] w-full top-0 left-0">
        <.author_sign_in />
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
            <div class="w-auto h-11 justify-start items-end gap-1 inline-flex">
              <div class="justify-start items-end gap-x-3 flex">
                <div class="grow shrink basis-0 self-start py-1 justify-center items-center flex">
                  <.pencil_writing />
                </div>
                <div class="w-full h-11 text-center text-white text-4xl font-bold font-['Open Sans']">
                  Course Author
                </div>
              </div>
            </div>
            <div class="lg:mt-6 text-white text-xl font-normal leading-normal">
              Create, deliver, and continuously improve course materials.
            </div>
          </div>
        </div>

        <div class="w-full lg:w-1/2 flex items-center justify-center dark">
          <Components.Auth.log_in_form
            title="Course Author Sign In"
            form={@form}
            action={~p"/authors/log_in"}
            registration_link={~p"/authors/register"}
            reset_password_link={~p"/authors/reset_password"}
            provider_links={[]}
          />
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "author")

    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
