defmodule OliWeb.Components.Delivery.UserAccount do
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias Oli.Accounts.{User, Author}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React
  alias OliWeb.Components.Timezone

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext)
  attr(:is_system_admin, :boolean, required: true)
  attr(:section, Section, default: nil)
  attr(:class, :string, default: "")
  attr(:dropdown_class, :string, default: "")

  def menu(assigns) do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class={"flex flex-row items-center justify-center rounded-full outline outline-2 outline-neutral-300 dark:outline-neutral-700 hover:outline-4 hover:dark:outline-zinc-600 focus:outline-4 focus:outline-primary-300 dark:focus:outline-zinc-600 #{@class}"}
        phx-click={toggle_menu("##{@id}-dropdown")}
      >
        <.user_icon ctx={@ctx} />
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"} class={@dropdown_class}>
        <%= case assigns.ctx do %>
          <% %SessionContext{author: %Author{}} -> %>
            <.author_menu_items
              id={"#{@id}-menu-items-admin"}
              ctx={@ctx}
              is_system_admin={@is_system_admin}
            />
          <% %SessionContext{user: %User{guest: true}} -> %>
            <.guest_menu_items id={"#{@id}-menu-items-admin"} ctx={@ctx} />
          <% %SessionContext{user: %User{}} -> %>
            <.user_menu_items id={"#{@id}-menu-items-admin"} ctx={@ctx} />
          <% _ -> %>
        <% end %>
      </.dropdown_menu>
    </div>
    """
  end

  def toggle_menu(id, js \\ %JS{}) do
    js
    |> JS.toggle(
      to: id,
      in: {"ease-out duration-300", "opacity-0 top-[40px]", "opacity-100"},
      out: {"ease-out duration-300", "opacity-100", "opacity-0 top-[40px]"}
    )
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)
  attr(:is_system_admin, :boolean, required: true)

  def author_menu_items(assigns) do
    ~H"""
    <.maybe_menu_item_open_admin_panel is_system_admin={@is_system_admin} />
    <.menu_item_edit_author_account author={@ctx.author} />
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_link
      href={Routes.authoring_pow_session_path(OliWeb.Endpoint, :delete)}
      method={:delete}
    >
      Sign out
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def user_menu_items(assigns) do
    ~H"""
    <.menu_item_maybe_linked_account user={@ctx.user} />
    <.maybe_menu_item_edit_user_account user={@ctx.user} />
    <.menu_item_link href={~p"/sections"}>
      My Courses
    </.menu_item_link>
    <.menu_divider />
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.maybe_research_consent_link ctx={@ctx} />
    <.menu_item_link href={~p"/users/log_out"} method={:delete}>
      Sign out
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def guest_menu_items(assigns) do
    ~H"""
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_link href={
      Routes.delivery_path(OliWeb.Endpoint, :signin, section: maybe_section_slug(assigns))
    }>
      Create account or sign in
    </.menu_item_link>
    <.menu_divider />
    <.maybe_research_consent_link ctx={@ctx} />
    <.menu_item_link href={~p"/users/log_out"}>
      Leave Guest account
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def dropdown_menu(assigns) do
    ~H"""
    <div
      id={@id}
      phx-click-away={JS.hide()}
      class={"hidden absolute top-[51px] -right-[9px] z-50 p-[10px] whitespace-nowrap bg-gray-100 border-gray-300 w-[220px] dark:bg-[#0F0D0F] rounded-xl border dark:border-zinc-800 #{@class}"}
    >
      <ul>
        <%= render_slot(@inner_block) %>
      </ul>
    </div>
    """
  end

  slot(:inner_block, required: true)

  def menu_item(assigns) do
    ~H"""
    <li class="block p-1">
      <%= render_slot(@inner_block) %>
    </li>
    """
  end

  def menu_divider(assigns) do
    ~H"""
    <li class="py-[4px]">
      <div class="h-0 border border-t border-gray-200 dark:border-zinc-800"></div>
    </li>
    """
  end

  attr(:href, :string, required: true)
  attr(:method, :atom, default: nil)
  attr(:target, :string, default: nil)
  slot(:inner_block, required: true)

  def menu_item_link(assigns) do
    case assigns[:method] do
      nil ->
        ~H"""
        <%= link to: @href, class: "w-full text-gray-800 hover:text-gray-800 dark:text-white hover:text-white text-sm font-normal font-['Roboto'] h-[26px] p-[5px] rounded-md justify-start items-center inline-flex block hover:no-underline dark:hover:bg-white/5 hover:bg-gray-200 cursor-pointer", target: @target do %>
          <%= render_slot(@inner_block) %>
        <% end %>
        """

      _method ->
        ~H"""
        <%= link to: @href, method: @method, class: "w-[190px] text-gray-800 hover:text-white dark:text-white text-sm font-normal font-['Roboto'] h-8 px-1.5 py-2 mt-[10px] m-[5px] rounded-md border border-rose-400 justify-center items-center gap-2.5 inline-flex cursor-pointer hover:no-underline hover:bg-red-300 hover:border-red-500 dark:hover:bg-[#33181A]", target: @target do %>
          <%= render_slot(@inner_block) %>
        <% end %>
        """
    end
  end

  def menu_item_my_courses_link(assigns) do
    ~H"""
    <.menu_item_link href={~p"/sections"}>
      My Courses
    </.menu_item_link>
    """
  end

  attr(:user, User, required: true)

  def menu_item_maybe_linked_account(assigns) do
    ~H"""
    <%= case linked_author_account(@user) do %>
      <% nil -> %>
        <%= if Sections.is_independent_instructor?(@user) do %>
          <.menu_item_link href={Routes.delivery_path(OliWeb.Endpoint, :link_account)}>
            Link authoring account
          </.menu_item_link>
          <.menu_divider />
        <% end %>
      <% linked_author_account_email -> %>
        <.menu_item>
          <div class="text-xs font-semibold mb-1">Linked Authoring Account:</div>
          <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)} target="_blank">
            <div class="flex flex-row justify-between items-center">
              <div><%= linked_author_account_email %></div>
              <div><i class="fas fa-external-link-alt ml-2"></i></div>
            </div>
          </a>
        </.menu_item>

        <.menu_item_link href={Routes.delivery_path(OliWeb.Endpoint, :link_account)}>
          Link a different account
        </.menu_item_link>

        <.menu_divider />
    <% end %>
    """
  end

  attr(:user, User, required: true)

  def maybe_menu_item_edit_user_account(assigns) do
    ~H"""
    <.menu_item_link
      :if={is_independent_learner?(@user)}
      href={Routes.pow_registration_path(OliWeb.Endpoint, :edit)}
    >
      Edit Account
    </.menu_item_link>

    <.menu_divider />
    """
  end

  attr(:author, Author, required: true)

  def menu_item_edit_author_account(assigns) do
    ~H"""
    <.menu_item_link href={Routes.live_path(OliWeb.Endpoint, OliWeb.Workspace.AccountDetailsLive)}>
      Edit Account
    </.menu_item_link>

    <.menu_divider />
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def menu_item_dark_mode_selector(assigns) do
    ~H"""
    <.menu_item>
      <div class="dark:text-gray-400 text-xs font-medium font-['Roboto'] mb-[10px]">THEME</div>
      <div>
        <%= React.component(
          @ctx,
          "Components.DarkModeSelector",
          %{
            showLabels: false
          },
          id: @id
        ) %>
      </div>
    </.menu_item>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def menu_item_timezone_selector(assigns) do
    ~H"""
    <.menu_item>
      <div class="dark:text-gray-400 text-xs font-medium font-['Roboto'] mb-[10px]">TIMEZONE</div>
      <div class="w-[190px]">
        <Timezone.select id={@id} ctx={@ctx} />
      </div>
    </.menu_item>
    """
  end

  attr(:is_system_admin, :boolean, required: true)

  @spec maybe_menu_item_open_admin_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def maybe_menu_item_open_admin_panel(assigns) do
    ~H"""
    <%= if @is_system_admin do %>
      <.menu_item_link href={~p"/admin"}>
        <.icon name="fa-solid fa-wrench" class="mr-2" /> Admin Panel
      </.menu_item_link>
      <.menu_divider />
    <% end %>
    """
  end

  attr(:ctx, SessionContext, required: true)

  defp maybe_research_consent_link(assigns) do
    ~H"""
    <%= if show_research_consent_link?(@ctx.user) do %>
      <.menu_item_link href={~p"/research_consent"}>
        Research Consent
      </.menu_item_link>
      <.menu_divider />
    <% end %>
    """
  end

  attr(:ctx, SessionContext, required: true)

  def user_icon(assigns) do
    ~H"""
    <%= case @ctx do %>
      <% %SessionContext{user: user} when user != nil -> %>
        <.user_picture_icon user={user} />
      <% %SessionContext{author: author} when author != nil -> %>
        <.user_picture_icon user={author} />
      <% _ -> %>
        <.default_user_icon />
    <% end %>
    """
  end

  attr(:user, :map)

  def user_picture_icon(assigns) do
    ~H"""
    <%= case @user.picture do %>
      <% nil -> %>
        <div class="w-8 h-8 bg-delivery-primary-700 dark:bg-zinc-800 rounded-full flex justify-center items-center text-white text-sm font-semibold leading-[14px]">
          <%= to_initials(@user) %>
        </div>
      <% picture -> %>
        <div class="flex justify-center items-center">
          <img src={picture} referrerpolicy="no-referrer" class="rounded-full h-8 w-8" />
        </div>
    <% end %>
    """
  end

  def default_user_icon(assigns) do
    ~H"""
    <div class="self-center">
      <div class="h-8 w-8 rounded-full flex justify-center items-center">
        <i class="fa-solid fa-circle-user fa-2xl mt-[1px] text-gray-600"></i>
      </div>
    </div>
    """
  end

  def preview_user_menu(assigns) do
    ~H"""
    <div class="flex">
      <button
        class="
            dropdown-toggle
            px-6
            py-2.5
            font-medium
            text-sm
            leading-tight
            transition
            duration-150
            ease-in-out
            flex
            items-center
            whitespace-nowrap
          "
        type="button"
        data-bs-toggle="dropdown"
        aria-expanded="false"
      >
        <div class="user-icon">
          <.user_picture_icon />
        </div>
        <div class="block lg:inline-block lg:mt-0 text-grey-darkest mx-2">
          <div class="username">
            Preview
          </div>
        </div>
      </button>
    </div>
    """
  end

  def maybe_section_slug(assigns) do
    case assigns[:section] do
      %Section{slug: slug} ->
        slug

      _ ->
        ""
    end
  end

  def linked_author_account(%User{author: %Author{email: email}}), do: email
  def linked_author_account(_), do: nil

  defp to_initials(%{name: nil}), do: "G"

  defp to_initials(%{name: name}) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
  end

  defp to_initials(_), do: "?"

  defp show_research_consent_link?(user) do
    case user do
      nil ->
        false

      # Direct delivery user
      %User{independent_learner: true} ->
        case Delivery.get_research_consent_form_setting() do
          :oli_form ->
            true

          _ ->
            false
        end

      # LTI user
      user ->
        # check institution research consent setting
        institution = Institutions.get_institution_by_lti_user(user)

        case institution do
          %Institution{research_consent: :oli_form} ->
            true

          # if research consent is set to anything else or institution was
          # not found for LTI user, do not show the link
          _ ->
            false
        end
    end
  end
end
