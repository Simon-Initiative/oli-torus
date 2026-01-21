defmodule OliWeb.CookiePreferencesLive do
  use OliWeb, :live_view

  alias Oli.Consent

  def mount(params, _session, socket) do
    # Get return_to from params or use referer as fallback
    return_to = Map.get(params, "return_to") || "/"

    # Get current cookie preferences from database if user is logged in
    {functional_active, analytics_active, targeting_active, has_db_preferences} =
      get_cookie_preferences(socket)

    {:ok,
     assign(socket,
       is_admin: false,
       return_to: return_to,
       functional_active: functional_active,
       analytics_active: analytics_active,
       targeting_active: targeting_active,
       has_db_preferences: has_db_preferences,
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
    assigns =
      assign(assigns, :cookie_sections, [
        %{
          key: :strict_cookies,
          title: "Strictly Necessary Cookies",
          description: [
            "These cookies are necessary for our website to function properly and cannot be switched off in our systems.",
            "You can set your browser to block or alert you about these cookies, but some parts of the site will not then work. These cookies do not store any personally identifiable information."
          ],
          cookies: [
            %{
              domain: "canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu",
              cookies:
                "_oli_key, _cky_opt_in, _cky_opt_in_dismiss, _cky_opt_choices, _legacy_normandy_session, log_session_id, _csrf_token",
              type: "1st Party",
              description:
                "This cookies are usually only set in response to actions made by you which amount to a request for services, such as setting your privacy preferences, logging in or where they're essential to provide you with a service you have requested."
            }
          ],
          disabled: true,
          checked: true
        },
        %{
          key: :functional_cookies,
          title: "Functionality Cookies",
          description: [
            "These cookies are used to provide you with a more personalized experience on our website and to remember choices you make when you use our website.",
            "For example, we may use functionality cookies to remember your language preferences or remember your login details."
          ],
          cookies: [%{domain: "None", cookies: "", type: "", description: ""}],
          disabled: false,
          checked: assigns.functional_active
        },
        %{
          key: :analytics_cookies,
          title: "Analytics Cookies",
          description: [
            "These cookies are used to collect information to analyze the traffic to our website and how visitors are using our website.",
            "For example, these cookies may track things such as how long you spend on the website or the pages you visit which helps us to understand how we can improve our website site for you.",
            "The information collected through these tracking and performance cookies do not identify any individual visitor."
          ],
          cookies: [
            %{
              domain: "canvas.oli.cmu.edu, proton.oli.cmu.edu, oli.cmu.edu, cmu.edu",
              cookies: "_gid, _ga, _ga_xxxxxxx, _utma, _utmb, _utmc, _utmz, nmstat",
              type: "1st Party",
              description:
                "This cookies record basic website information such as: repeat visits; page usage; country of origin for use in Google analytics and other site improvements"
            }
          ],
          disabled: false,
          checked: assigns.analytics_active
        },
        %{
          key: :targeting_cookies,
          title: "Targeting Cookies",
          description: [
            "These cookies are used to show advertising that is likely to be of interest to you based on your browsing habits.",
            "These cookies, as served by our content and/or advertising providers, may combine information they collected from our website with other information they have independently collected relating to your web browser's activities across their network of websites.",
            "If you choose to remove or disable these targeting or advertising cookies, you will still see adverts but they may not be relevant to you."
          ],
          cookies: [%{domain: "None", cookies: "", type: "", description: ""}],
          disabled: false,
          checked: assigns.targeting_active
        }
      ])

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
        <%= for section <- @cookie_sections do %>
          <.cookie_section
            section={section}
            expanded_sections={@expanded_sections}
            expanded_cookie_tables={@expanded_cookie_tables}
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :section, :map, required: true
  attr :expanded_sections, :map, required: true
  attr :expanded_cookie_tables, :map, required: true

  defp cookie_section(assigns) do
    ~H"""
    <div class="accordion-item border-0">
      <div class="accordion-header mb-0 flex justify-content-between">
        <div class="flex flex-row">
          <button
            class={[
              "flex flex-row items-center font-open-sans text-[16px] leading-[16px] tracking-normal font-bold align-middle text-Text-text-low-alpha",
              unless(@section.disabled, do: "collapsed")
            ]}
            type="button"
            phx-click="toggle_section"
            phx-value-section={@section.key}
            aria-expanded={@expanded_sections[@section.key]}
            aria-controls={"#{@section.key}-panel"}
          >
            {@section.title}
            <i
              class={"fa fa-chevron-down #{chevron_class(@expanded_sections[@section.key])}"}
              style="width: 20px; height: 20px;"
            >
            </i>
          </button>
        </div>
        <div class="form-check form-switch">
          <input
            type="checkbox"
            role="switch"
            aria-label={@section.title}
            class="form-check-input appearance-none w-9 -ml-10 rounded-full float-left h-5 align-top bg-no-repeat bg-contain focus:outline-none cursor-pointer shadow-sm"
            checked={@section.checked}
            disabled={@section.disabled}
            phx-click={unless @section.disabled, do: "toggle_preference"}
            phx-value-preference={unless @section.disabled, do: @section.key}
            phx-value-checked={unless @section.disabled, do: to_string(!@section.checked)}
          />
        </div>
      </div>
      <%= if @expanded_sections[@section.key] do %>
        <div id={"#{@section.key}-panel"} class="accordion-collapse">
          <div class="accordion-body py-4 px-0">
            <div class="mb-2 text-Text-text-low-alpha">
              <%= for description <- @section.description do %>
                <p>{description}</p>
              <% end %>
            </div>
            <div class="small">
              <button
                class="text-Text-text-button font-open-sans font-bold text-[14px] leading-[16px] tracking-normal text-center align-middle bg-transparent border-0 p-0"
                phx-click="toggle_cookie_table"
                phx-value-section={@section.key}
              >
                View Cookies
              </button>
              <%= if @expanded_cookie_tables[@section.key] do %>
                <div class="mt-2 overflow-x-auto max-w-full">
                  <table class="table table-striped w-full">
                    <thead>
                      <tr>
                        <th
                          scope="col"
                          class="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/4"
                        >
                          Domain
                        </th>
                        <th
                          scope="col"
                          class="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/4"
                        >
                          Cookies
                        </th>
                        <th
                          scope="col"
                          class="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/6"
                        >
                          Type
                        </th>
                        <th
                          scope="col"
                          class="text-Text-text-high bg-Background-bg-primary px-2 py-1 text-xs sm:text-sm w-1/3"
                        >
                          Description
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for cookie <- @section.cookies do %>
                        <tr>
                          <td class="px-2 py-1 text-xs sm:text-sm break-words">{cookie.domain}</td>
                          <td class="px-2 py-1 text-xs sm:text-sm break-words">{cookie.cookies}</td>
                          <td class="px-2 py-1 text-xs sm:text-sm">{cookie.type}</td>
                          <td class="px-2 py-1 text-xs sm:text-sm break-words leading-tight">
                            {cookie.description}
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp section_key(section) when is_binary(section) do
    String.to_existing_atom(section)
  rescue
    ArgumentError -> nil
  end

  defp section_key(_), do: nil

  def handle_event("toggle_section", %{"section" => section}, socket) do
    case section_key(section) do
      nil ->
        {:noreply, socket}

      key ->
        updated_sections =
          Map.update!(socket.assigns.expanded_sections, key, fn current -> not current end)

        {:noreply, assign(socket, expanded_sections: updated_sections)}
    end
  end

  def handle_event("toggle_cookie_table", %{"section" => section}, socket) do
    case section_key(section) do
      nil ->
        {:noreply, socket}

      key ->
        updated_tables =
          Map.update!(socket.assigns.expanded_cookie_tables, key, fn current -> not current end)

        {:noreply, assign(socket, expanded_cookie_tables: updated_tables)}
    end
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

    # Check if user is authenticated
    is_authenticated = socket.assigns[:current_user] != nil

    # Send preferences to the JavaScript hook, then navigate back
    socket =
      socket
      |> put_flash(:info, "Cookie preferences have been updated.")
      |> push_event("save-cookie-preferences", %{
        preferences: preferences,
        is_authenticated: is_authenticated
      })

    {:noreply, socket}
  end

  def handle_event("go_back", _params, socket) do
    {:noreply, redirect(socket, to: socket.assigns.return_to)}
  end

  def handle_event("browser_cookie_preferences", %{"preferences" => preferences}, socket)
      when is_map(preferences) do
    # Only update from browser cookies if user doesn't have preferences in DB
    # Priority: DB preferences > browser cookies > defaults
    if socket.assigns.has_db_preferences do
      # User has DB preferences, ignore browser cookies
      {:noreply, socket}
    else
      # No DB preferences, use browser cookies
      socket =
        socket
        |> assign(:functional_active, Map.get(preferences, "functionality", true))
        |> assign(:analytics_active, Map.get(preferences, "analytics", true))
        |> assign(:targeting_active, Map.get(preferences, "targeting", false))

      {:noreply, socket}
    end
  end

  def handle_event("browser_cookie_preferences", _params, socket) do
    # Invalid preferences format, ignore
    {:noreply, socket}
  end

  defp privacy_policies_url(), do: Application.fetch_env!(:oli, :privacy_policies)[:url]

  defp not_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp not_blank?(_), do: false

  defp chevron_class(expanded) do
    base_class = "ml-2 transition-transform duration-200"

    if expanded,
      do: "#{base_class} rotate-180",
      else: "#{base_class} rotate-0"
  end

  defp get_cookie_preferences(socket) do
    case socket.assigns[:current_user] do
      nil ->
        # Non-authenticated user: use defaults, browser cookies will be loaded via JS hook
        # has_db_preferences = false means we should accept browser cookies
        {true, true, false, false}

      user ->
        cookies = Consent.retrieve_cookies(user.id)

        case Enum.find(cookies, fn cookie -> cookie.name == "_cky_opt_choices" end) do
          nil ->
            # No existing preferences in DB, browser cookies will be loaded via JS hook
            {true, true, false, false}

          choices_cookie ->
            case Jason.decode(choices_cookie.value) do
              {:ok, preferences} when is_map(preferences) ->
                # Has DB preferences, use them and ignore browser cookies
                {
                  Map.get(preferences, "functionality", true),
                  Map.get(preferences, "analytics", true),
                  Map.get(preferences, "targeting", false),
                  true
                }

              _ ->
                # If JSON decode fails or result is not a map, use defaults
                {true, true, false, false}
            end
        end
    end
  end
end
