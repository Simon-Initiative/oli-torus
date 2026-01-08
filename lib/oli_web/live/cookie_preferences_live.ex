defmodule OliWeb.CookiePreferencesLive do
  use OliWeb, :live_view

  alias Oli.Consent

  def mount(params, _session, socket) do
    # Get return_to from params or use referer as fallback
    return_to = Map.get(params, "return_to") || get_referer(socket) || "/"

    # Get current cookie preferences from database if user is logged in
    {functional_active, analytics_active, targeting_active} = get_cookie_preferences(socket)

    {:ok,
     assign(socket,
       is_admin: false,
       return_to: return_to,
       functional_active: functional_active,
       analytics_active: analytics_active,
       targeting_active: targeting_active,
       expanded_sections: %{
         strict_cookies: false,
         functional_cookies: false,
         analytics_cookies: false,
         targeting_cookies: false
       },
       expanded_cookie_tables: %{
         strict_cookies: false,
         functional_cookies: false,
         analytics_cookies: false,
         targeting_cookies: false
       },
       privacy_policies_url: privacy_policies_url()
     )}
  end

  def render(assigns) do
    ~H"""
    <!-- Mobile page layout (no backdrop) -->
    <div class="bg-Background-bg-primary">
      <div class="max-w-2xl mx-auto">
        <div class="bg-Background-bg-primary rounded-md outline-none text-current">
          <!-- Header -->
          <div class="p-4">
            <!-- Back button -->
            <div class="mb-4">
              <button type="button" class="flex items-center gap-2" phx-click="go_back">
                <OliWeb.Icons.back_arrow />
                <span class="font-open-sans font-semibold text-[14px] leading-[24px] tracking-[0%] align-middle text-Text-text-high">
                  Back
                </span>
              </button>
            </div>
            <!-- Title -->
            <div class="flex flex-shrink-0 items-center mt-8">
              <h5 class="font-open-sans text-[18px] leading-[24px] tracking-[0px] font-bold text-Text-text-high">
                Cookie Preferences
              </h5>
            </div>
          </div>
          
    <!-- Body -->
          <div class="relative">
            <div class="bg-Background-bg-primary p-4">
              <.cookie_preferences_content
                privacy_policies_url={@privacy_policies_url}
                functional_active={@functional_active}
                analytics_active={@analytics_active}
                targeting_active={@targeting_active}
                expanded_sections={@expanded_sections}
                expanded_cookie_tables={@expanded_cookie_tables}
              />
            </div>
          </div>
          
    <!-- Footer -->
          <div class="flex flex-col gap-3 p-4">
            <button
              type="button"
              class="w-full bg-Fill-Buttons-fill-primary flex gap-0 items-center justify-center px-6 py-3 rounded-md"
              phx-click="save_preferences"
              id="save-cookie-preferences"
              phx-hook="SaveCookiePreferences"
            >
              <span class="font-open-sans font-semibold text-[14px] leading-[16px] tracking-normal text-center align-middle text-white">
                Save My Preferences
              </span>
            </button>
            <button
              type="button"
              class="w-full bg-Background-bg-primary border border-Border-border-bold flex gap-0 items-center justify-center px-6 py-3 rounded-md hover:no-underline"
              phx-click="go_back"
            >
              <span class="font-open-sans font-semibold text-[14px] leading-[16px] tracking-normal text-center align-middle text-Specially-Tokens-Text-text-button-secondary">
                Cancel
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp cookie_preferences_content(assigns) do
    ~H"""
    <div>
      <div class="mb-4">
        <p class="text-Text-text-low-alpha">
          We are committed to privacy and data protection. When you provide us with your personal
          data, including preferences, we will only process information that is necessary for the
          purpose for which it has been collected.
        </p>
        <p>
          <%= if not_blank?(@privacy_policies_url) do %>
            <a
              class="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle"
              href={@privacy_policies_url}
            >
              Privacy Notice
            </a>
          <% end %>
        </p>
      </div>

      <div class="accordion flex flex-col gap-y-8">
        <!-- Strictly Necessary Cookies -->
        <div class="accordion-item border-0">
          <div class="accordion-header mb-0 flex justify-content-between">
            <div class="flex flex-row">
              <button
                class="flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                phx-click="toggle_section"
                phx-value-section="strict_cookies"
              >
                Strictly Necessary Cookies
                <i
                  class={"fa fa-chevron-down #{chevron_class(@expanded_sections.strict_cookies)}"}
                  style="width: 20px; height: 20px;"
                >
                </i>
              </button>
            </div>
            <div class="form-check form-switch">
              <input
                type="checkbox"
                role="switch"
                aria-label="Strictly Necessary Cookies"
                class="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top focus:outline-none cursor-pointer shadow-sm"
                checked
                disabled
              />
            </div>
          </div>
          <%= if @expanded_sections.strict_cookies do %>
            <div class="accordion-collapse">
              <div class="accordion-body py-4 px-0">
                <div class="mb-2 text-Text-text-low-alpha">
                  <p>
                    These cookies are necessary for our website to function properly and cannot be
                    switched off in our systems.
                  </p>
                  <p>
                    You can set your browser to block or alert you about these cookies, but some parts
                    of the site will not then work. These cookies do not store any personally
                    identifiable information.
                  </p>
                </div>
                <div class="small">
                  <button
                    class="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle bg-transparent border-0 p-0"
                    phx-click="toggle_cookie_table"
                    phx-value-section="strict_cookies"
                  >
                    View Cookies
                  </button>
                  <%= if @expanded_cookie_tables.strict_cookies do %>
                    <div class="mt-2 overflow-x-auto max-w-full">
                      <table class="table table-striped min-w-full">
                        <thead>
                          <tr>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Domain
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Cookies
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Type
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Description
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td class="whitespace-nowrap">
                              canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu
                            </td>
                            <td class="whitespace-nowrap">
                              _oli_key, _cky_opt_in, _cky_opt_in_dismiss, _cky_opt_choices,
                              _legacy_normandy_session, log_session_id, _csrf_token
                            </td>
                            <td class="whitespace-nowrap">1st Party</td>
                            <td class="max-w-xs">
                              This cookies are usually only set in response to actions made by you which
                              amount to a request for services, such as setting your privacy
                              preferences, logging in or where they're essential to provide you with a
                              service you have requested.
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Functionality Cookies -->
        <div class="accordion-item border-0">
          <div class="accordion-header mb-0 flex justify-content-between">
            <div class="flex flex-row">
              <button
                class="collapsed flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                phx-click="toggle_section"
                phx-value-section="functional_cookies"
              >
                Functionality Cookies
                <i
                  class={"fa fa-chevron-down #{chevron_class(@expanded_sections.functional_cookies)}"}
                  style="width: 20px; height: 20px;"
                >
                </i>
              </button>
            </div>
            <div class="form-check form-switch">
              <input
                type="checkbox"
                role="switch"
                aria-label="Functionality Cookies"
                class="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                checked={@functional_active}
                phx-click="toggle_preference"
                phx-value-preference="functional_cookies"
                phx-value-checked={to_string(!@functional_active)}
              />
            </div>
          </div>
          <%= if @expanded_sections.functional_cookies do %>
            <div class="accordion-collapse">
              <div class="accordion-body py-4 px-0">
                <div class="mb-2 text-Text-text-low-alpha">
                  <p>
                    These cookies are used to provide you with a more personalized experience on our
                    website and to remember choices you make when you use our website.
                  </p>
                  <p>
                    For example, we may use functionality cookies to remember your language
                    preferences or remember your login details.
                  </p>
                </div>
                <div class="small">
                  <button
                    class="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle bg-transparent border-0 p-0"
                    phx-click="toggle_cookie_table"
                    phx-value-section="functional_cookies"
                  >
                    View Cookies
                  </button>
                  <%= if @expanded_cookie_tables.functional_cookies do %>
                    <div class="mt-2 overflow-x-auto max-w-full">
                      <table class="table table-striped min-w-full">
                        <thead>
                          <tr>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Domain
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Cookies
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Type
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Description
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td class="whitespace-nowrap">None</td>
                            <td class="whitespace-nowrap"></td>
                            <td class="whitespace-nowrap"></td>
                            <td class="whitespace-nowrap"></td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Analytics Cookies -->
        <div class="accordion-item border-0">
          <div class="accordion-header mb-0 flex justify-content-between">
            <div class="flex flex-row">
              <button
                class="collapsed flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                phx-click="toggle_section"
                phx-value-section="analytics_cookies"
              >
                Analytics Cookies
                <i
                  class={"fa fa-chevron-down #{chevron_class(@expanded_sections.analytics_cookies)}"}
                  style="width: 20px; height: 20px;"
                >
                </i>
              </button>
            </div>
            <div class="form-check form-switch">
              <input
                type="checkbox"
                role="switch"
                aria-label="Analytics Cookies"
                class="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                checked={@analytics_active}
                phx-click="toggle_preference"
                phx-value-preference="analytics_cookies"
                phx-value-checked={to_string(!@analytics_active)}
              />
            </div>
          </div>
          <%= if @expanded_sections.analytics_cookies do %>
            <div class="accordion-collapse">
              <div class="accordion-body py-4 px-0">
                <div class="mb-2 text-Text-text-low-alpha">
                  <p>
                    These cookies are used to collect information to analyze the traffic to our
                    website and how visitors are using our website.
                  </p>
                  <p>
                    For example, these cookies may track things such as how long you spend on the
                    website or the pages you visit which helps us to understand how we can improve our
                    website site for you.
                  </p>
                  <p>
                    The information collected through these tracking and performance cookies do not
                    identify any individual visitor.
                  </p>
                </div>
                <div class="small">
                  <button
                    class="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle bg-transparent border-0 p-0"
                    phx-click="toggle_cookie_table"
                    phx-value-section="analytics_cookies"
                  >
                    View Cookies
                  </button>
                  <%= if @expanded_cookie_tables.analytics_cookies do %>
                    <div class="mt-2 overflow-x-auto max-w-full">
                      <table class="table table-striped min-w-full">
                        <thead>
                          <tr>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Domain
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Cookies
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Type
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Description
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td class="whitespace-nowrap">
                              canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu
                            </td>
                            <td class="whitespace-nowrap">
                              _gid, _ga, _ga_xxxxxxx, _utma, _utmb, _utmc, _utmz, nmstat
                            </td>
                            <td class="whitespace-nowrap">1st Party</td>
                            <td class="max-w-xs">
                              This cookies record basic website information such as: repeat visits; page
                              usage; country of origin for use in Google analytics and other site
                              improvements
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Targeting Cookies -->
        <div class="accordion-item border-0">
          <div class="accordion-header mb-0 flex justify-content-between">
            <div class="flex flex-row">
              <button
                class="collapsed flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha"
                type="button"
                phx-click="toggle_section"
                phx-value-section="targeting_cookies"
              >
                Targeting Cookies
                <i
                  class={"fa fa-chevron-down #{chevron_class(@expanded_sections.targeting_cookies)}"}
                  style="width: 20px; height: 20px;"
                >
                </i>
              </button>
            </div>
            <div class="form-check form-switch">
              <input
                type="checkbox"
                role="switch"
                aria-label="Targeting Cookies"
                class="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
                checked={@targeting_active}
                phx-click="toggle_preference"
                phx-value-preference="targeting_cookies"
                phx-value-checked={to_string(!@targeting_active)}
              />
            </div>
          </div>
          <%= if @expanded_sections.targeting_cookies do %>
            <div class="accordion-collapse">
              <div class="accordion-body py-4 px-0">
                <div class="mb-2 text-Text-text-low-alpha">
                  <p>
                    These cookies are used to show advertising that is likely to be of interest to you
                    based on your browsing habits.
                  </p>
                  <p>
                    These cookies, as served by our content and/or advertising providers, may combine
                    information they collected from our website with other information they have
                    independently collected relating to your web browser's activities across
                    their network of websites.
                  </p>
                  <p>
                    If you choose to remove or disable these targeting or advertising cookies, you
                    will still see adverts but they may not be relevant to you.
                  </p>
                </div>
                <div class="small">
                  <button
                    class="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle bg-transparent border-0 p-0"
                    phx-click="toggle_cookie_table"
                    phx-value-section="targeting_cookies"
                  >
                    View Cookies
                  </button>
                  <%= if @expanded_cookie_tables.targeting_cookies do %>
                    <div class="mt-2 overflow-x-auto max-w-full">
                      <table class="table table-striped min-w-full">
                        <thead>
                          <tr>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Domain
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Cookies
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Type
                            </th>
                            <th
                              scope="col"
                              class="text-Text-text-high bg-Background-bg-primary whitespace-nowrap"
                            >
                              Description
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td class="whitespace-nowrap">None</td>
                            <td class="whitespace-nowrap"></td>
                            <td class="whitespace-nowrap"></td>
                            <td class="whitespace-nowrap"></td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    updated_sections =
      Map.put(
        socket.assigns.expanded_sections,
        String.to_atom(section),
        !Map.get(socket.assigns.expanded_sections, String.to_atom(section))
      )

    {:noreply, assign(socket, expanded_sections: updated_sections)}
  end

  def handle_event("toggle_cookie_table", %{"section" => section}, socket) do
    updated_tables =
      Map.put(
        socket.assigns.expanded_cookie_tables,
        String.to_atom(section),
        !Map.get(socket.assigns.expanded_cookie_tables, String.to_atom(section))
      )

    {:noreply, assign(socket, expanded_cookie_tables: updated_tables)}
  end

  def handle_event(
        "toggle_preference",
        %{"preference" => preference, "checked" => checked},
        socket
      ) do
    checked_bool = checked == "true"

    socket =
      case preference do
        "functional_cookies" ->
          assign(socket, functional_active: checked_bool)

        "analytics_cookies" ->
          assign(socket, analytics_active: checked_bool)

        "targeting_cookies" ->
          assign(socket, targeting_active: checked_bool)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("save_preferences", _params, socket) do
    # Prepare preferences data for JavaScript hook
    preferences = %{
      necessary: true,
      functionality: socket.assigns.functional_active,
      analytics: socket.assigns.analytics_active,
      targeting: socket.assigns.targeting_active
    }

    # Send preferences to the JavaScript hook, then navigate back
    socket =
      socket
      |> push_event("save-cookie-preferences", %{preferences: preferences})

    {:noreply, socket}
  end

  def handle_event("go_back", _params, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.return_to)}
  end

  defp privacy_policies_url(), do: Application.fetch_env!(:oli, :privacy_policies)[:url]

  defp not_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp not_blank?(_), do: false

  defp get_referer(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: _address, port: _port} ->
        # Try to get referer from request headers if available
        case get_connect_info(socket, :user_agent) do
          nil ->
            nil

          _ ->
            # In LiveView, we can't directly access HTTP headers
            # So we'll rely on the return_to parameter instead
            nil
        end

      _ ->
        nil
    end
  end

  defp chevron_class(expanded) do
    base_class = "ml-2 transition-transform duration-200"

    if expanded,
      do: "#{base_class} rotate-180",
      else: "#{base_class} rotate-0"
  end

  defp get_cookie_preferences(socket) do
    case socket.assigns[:current_user] do
      nil ->
        # Default preferences for non-authenticated users
        {true, true, false}

      user ->
        cookies = Consent.retrieve_cookies(user.id)

        case Enum.find(cookies, fn cookie -> cookie.name == "_cky_opt_choices" end) do
          nil ->
            # No existing preferences, use defaults
            {true, true, false}

          choices_cookie ->
            case Jason.decode(choices_cookie.value) do
              {:ok, preferences} ->
                {
                  Map.get(preferences, "functionality", true),
                  Map.get(preferences, "analytics", true),
                  Map.get(preferences, "targeting", false)
                }

              {:error, _} ->
                # If JSON decode fails, use defaults
                {true, true, false}
            end
        end
    end
  end
end
