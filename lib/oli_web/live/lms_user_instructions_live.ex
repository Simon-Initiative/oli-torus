defmodule OliWeb.LmsUserInstructionsLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections
  alias Oli.VendorProperties

  on_mount {OliWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, _session, socket) do
    if socket.assigns.current_user do
      logout_path = build_logout_path(params["request_path"])

      lms_course_titles =
        Sections.list_user_enrolled_lti_section_titles(socket.assigns.current_user)

      socket =
        socket
        |> assign(:lms_course_titles, lms_course_titles)
        |> assign(:section_title, params["section_title"])
        |> assign(:logout_path, logout_path)

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="lms_user_warning" class="container flex items-center justify-center h-[70vh]">
      <div class="grid grid-cols-12">
        <div class="col-span-12 text-center pt-4">
          <p><i class="far fa-hand-paper" aria-hidden="true" style="font-size: 64px"></i></p>
          <h2 class="mt-4 mb-4">Account Type Mismatch</h2>
          <div class="my-10">
            <p>
              The account <strong><%= "#{@current_user.email}" %></strong>
              you use to access these courses
              <i>
                <%= if @lms_course_titles != [],
                  do: "- #{Enum.join(@lms_course_titles, ", ")} -" %>
              </i>
              only works with single sign-on through your school’s LMS.
            </p>
            <p>
              <strong><%= "#{@section_title}" %></strong>
              requires you to use a login account. Please log out of your current account with the button below, visit the enrollment URL again, and create a new <%= VendorProperties.product_short_name() %> account using either email and password, or Sign In With Google.
            </p>
          </div>
          <%= link to: @logout_path, method: :delete, class: "btn btn-primary" do %>
            <i class="fas fa-sign-out-alt me-1"></i> Log Out
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp build_logout_path(nil), do: ~p"/users/log_out"
  defp build_logout_path(""), do: ~p"/users/log_out"

  defp build_logout_path(request_path) do
    ~p"/users/log_out?#{[request_path: request_path]}"
  end
end
