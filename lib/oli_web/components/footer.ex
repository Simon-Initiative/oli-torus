defmodule OliWeb.Components.Footer do
  use Phoenix.Component
  use OliWeb, :verified_routes

  def delivery_footer(assigns) do
    ~H"""
    <footer class="w-full py-4 md:container lg:px-10 text-xs bg-delivery-footer dark:bg-delivery-footer-dark">
      <div class="flex flex-col">
        <div class="flex flex-col sm:flex-row gap-2">
          <.cookie_preferences />
          <.footer_part_1 />
          <.footer_part_2 />
        </div>
        <%= if Map.get(assigns, :license) do %>
          {OliWeb.LayoutView.render_license(@license)}
        <% end %>
      </div>
      <.retrieve_cookies />
    </footer>
    """
  end

  def login_footer(assigns) do
    ~H"""
    <footer class="absolute bottom-0 left-0 py-4 text-zinc-300 bg-black w-full text-xs">
      <div class="flex flex-col w-full px-10">
        <div class="flex flex-col items-center justify-between sm:flex-row px-4 md:px-32 gap-2">
          <.cookie_preferences class="no-underline text-zinc-300 w-auto" />
          <.footer_part_1 />
          <.footer_part_2 />
          <.version />
        </div>
      </div>
      <.retrieve_cookies />
    </footer>
    """
  end

  def global_footer(assigns) do
    ~H"""
    <footer class="absolute bottom-0 left-0 right-0 pb-4 w-full md:container md:mx-auto lg:px-10 text-xs bg-delivery-footer dark:bg-delivery-footer-dark">
      <div class="flex flex-col w-full px-10">
        <div class="flex flex-col sm:flex-row gap-2">
          <.cookie_preferences />
          <.footer_part_1 />
          <.footer_part_2 />
          <.version />
        </div>
      </div>
      <.retrieve_cookies />
    </footer>
    """
  end

  def email_footer(assigns) do
    ~H"""
    <footer class="absolute bottom-0 left-0 right-0 pb-4 w-full md:container md:mx-auto lg:px-10 text-xs bg-delivery-footer dark:bg-delivery-footer-dark">
      <div class="flex flex-col w-full px-10">
        <div class="flex flex-col sm:flex-row gap-2">
          <.footer_part_1 />
          <.footer_part_2 />
        </div>
      </div>
    </footer>
    """
  end

  defp footer_part_1(assigns) do
    assigns =
      assign(assigns,
        footer_text: footer_text(),
        footer_link_1_location: footer_link_1_location(),
        footer_link_1_text: footer_link_1_text()
      )

    ~H"""
    <div class="flex-1 text-left sm:text-center">
      {@footer_text}
      <%= if not_blank?(@footer_link_1_text) and not_blank?(@footer_link_1_location) do %>
        <a href={@footer_link_1_location} target="_blank" rel="noopener noreferrer">
          {@footer_link_1_text}
        </a>
      <% end %>
    </div>
    """
  end

  defp footer_part_2(assigns) do
    assigns =
      assign(assigns,
        footer_link_2_location: footer_link_2_location(),
        footer_link_2_text: footer_link_2_text()
      )

    ~H"""
    <div class="shrink-0 text-left">
      <%= if not_blank?(@footer_link_2_text) and not_blank?(@footer_link_2_location) do %>
        <a href={@footer_link_2_location} target="_blank" rel="noopener noreferrer">
          {@footer_link_2_text}
        </a>
      <% end %>
    </div>
    """
  end

  def version(assigns) do
    assigns = assign(assigns, version: version(), sha: sha(), timestamp: timestamp())

    ~H"""
    <div class="text-center sm:text-right">
      Version {@version} ({@sha}) {@timestamp}
    </div>
    """
  end

  attr :class, :string, default: ""

  defp cookie_preferences(assigns) do
    assigns = assign(assigns, privacy_policies_url: privacy_policies_url())

    ~H"""
    <div class="text-left shrink-0 relative z-10">
      <%= if not_blank?(@privacy_policies_url) do %>
        <a
          href="javascript:;"
          onclick={"OLI.handleCookiePreferences('#{@privacy_policies_url}')"}
          class={[
            @class,
            "whitespace-nowrap text-Text-text-link hover:text-Text-text-button-hover"
          ]}
        >
          Cookie Preferences
        </a>
      <% end %>
    </div>
    """
  end

  defp retrieve_cookies(assigns) do
    assigns = assign(assigns, privacy_policies_url: privacy_policies_url())

    ~H"""
    <%= if not_blank?(@privacy_policies_url) do %>
      <script>
        // Set device information for consistent mobile/tablet vs desktop detection
        window.isMobileOrTablet = <%= case assigns do
          %{conn: conn} -> OliWeb.Common.DeviceDetection.is_mobile_or_tablet?(conn)
          %{socket: socket} -> OliWeb.Common.DeviceDetection.is_mobile_or_tablet?(socket)
          _ -> "false"
        end %>;
        OLI.onReady(() => OLI.retrieveCookies('<%= ~p"/consent/cookie" %>', {privacyPoliciesUrl: '<%= @privacy_policies_url %>'}));
      </script>
    <% end %>
    """
  end

  defp footer(), do: Application.fetch_env!(:oli, :footer)
  defp footer_text(), do: footer()[:text]
  defp footer_link_1_location(), do: footer()[:link_1_location]
  defp footer_link_1_text(), do: footer()[:link_1_text]
  defp footer_link_2_location(), do: footer()[:link_2_location]
  defp footer_link_2_text(), do: footer()[:link_2_text]

  defp privacy_policies_url(), do: Application.fetch_env!(:oli, :privacy_policies)[:url]

  defp timestamp(),
    do: Application.fetch_env!(:oli, :build).date |> Timex.format!("%m/%d/%Y", :strftime)

  defp version(), do: Application.fetch_env!(:oli, :build).version

  defp sha(), do: Application.fetch_env!(:oli, :build).sha |> String.upcase()

  defp not_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp not_blank?(_), do: false
end
