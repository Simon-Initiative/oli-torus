defmodule OliWeb.Components.Delivery.UserAccount do
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias Oli.Accounts.{User, Author}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React
  alias OliWeb.Components.Timezone

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext)
  attr(:section, Section, default: nil)
  attr(:class, :string, default: "")
  attr(:dropdown_class, :string, default: "")

  def menu(assigns) do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class={"
          flex
          flex-row
          px-3
          items-center
          rounded-lg
          focus:outline-none
          pointer
          hover:bg-gray-100
          dark:hover:bg-gray-700
          active:bg-gray-200
          dark:active:bg-gray-600
          focus:bg-gray-100
          dark:focus:bg-gray-700
          #{@class}
        "}
        phx-click={toggle_menu("##{@id}-dropdown")}
        phx-hook="HideOnOutsideClick"
        phx-value-hide-target={"##{@id}-dropdown"}
        phx-value-ignore-initiator="true"
        phx-value-display="flex"
      >
        <div class="mr-2 block">
          <div class={if !@ctx.is_admin, do: "py-2", else: ""}><%= username(@ctx) %></div>
          <div :if={@ctx.is_admin} class="text-sm font-bold text-yellow">System Admin</div>
        </div>
        <.user_icon ctx={@ctx} />
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"} class={@dropdown_class}>
        <%= case assigns.ctx do %>
          <% %SessionContext{author: %Author{}, is_admin: true} -> %>
            <.admin_menu_items id={"#{@id}-menu-items-admin"} ctx={@ctx} />
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
      # display: "flex",
      to: id,
      in: {"ease-out duration-300", "opacity-0 top-[40px]", "opacity-100"},
      out: {"ease-out duration-300", "opacity-100", "opacity-0 top-[40px]"}
    )
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def admin_menu_items(assigns) do
    ~H"""
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_link href={Routes.authoring_session_path(OliWeb.Endpoint, :signout, type: :author)}>
      Sign out
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def user_menu_items(assigns) do
    ~H"""
    <.menu_item_maybe_linked_account user={@ctx.user} />
    <.menu_item_maybe_edit_account user={@ctx.user} />
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_link href={Routes.session_path(OliWeb.Endpoint, :signout, type: :user)}>
      Sign out
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def guest_menu_items(assigns) do
    ~H"""
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_link href={
      Routes.delivery_path(OliWeb.Endpoint, :signin, section: maybe_section_slug(assigns))
    }>
      Create account or sign in
    </.menu_item_link>
    <.menu_item_link href={signout_path(@ctx)}>
      <%= if @ctx.user.is_guest, do: "Leave course", else: "Sign out" %>
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:class, :string, default: "")
  slot :inner_block, required: true

  def dropdown_menu(assigns) do
    ~H"""
    <div
      id={@id}
      class={"hidden absolute top-[50px] right-0 z-50 whitespace-nowrap bg-white dark:bg-black p-2 rounded-lg shadow-lg #{@class}"}
    >
      <ul>
        <%= render_slot(@inner_block) %>
      </ul>
    </div>
    """
  end

  slot :inner_block, required: true

  def menu_item(assigns) do
    ~H"""
    <li class="block py-2 px-4 first:rounded-t last:rounded-b">
      <%= render_slot(@inner_block) %>
    </li>
    """
  end

  def menu_divider(assigns) do
    ~H"""
    <li class="block w-full">
      <hr class="border-t border-gray-100 dark:border-gray-700" />
    </li>
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  def menu_item_link(assigns) do
    ~H"""
    <a
      class="block py-2 px-4 hover:no-underline text-body-color dark:text-body-color-dark hover:text-body-color hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer first:rounded-t last:rounded-b"
      href={@href}
    >
      <%= render_slot(@inner_block) %>
    </a>
    """
  end

  def menu_item_my_courses_link(assigns) do
    ~H"""
    <.menu_item_link href={~p"/sections"}>
      My Courses
    </.menu_item_link>
    """
  end

  attr :user, User, required: true

  def menu_item_maybe_linked_account(assigns) do
    ~H"""
    <%= case linked_author_account(@user) do %>
      <% nil -> %>
        <.menu_item_link href={Routes.delivery_path(OliWeb.Endpoint, :link_account)}>
          Link authoring account
        </.menu_item_link>
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

  attr :user, User, required: true

  def menu_item_maybe_edit_account(assigns) do
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

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def menu_item_dark_mode_selector(assigns) do
    ~H"""
    <.menu_item>
      <div class="text-xs font-semibold mb-1">Dark Mode</div>
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
      <div class="text-xs font-semibold mb-1">Timezone</div>
      <div class="w-64">
        <Timezone.select id={@id} ctx={@ctx} />
      </div>
    </.menu_item>
    """
  end

  attr(:ctx, SessionContext, required: true)

  def user_icon(assigns) do
    ~H"""
    <%= case @ctx do %>
      <% %SessionContext{user: user} when user != nil -> %>
        <.user_picture_icon picture={user.picture} />
      <% %SessionContext{author: author} when author != nil -> %>
        <.user_picture_icon picture={author.picture} />
    <% end %>
    """
  end

  attr :picture, :string, default: nil

  def user_picture_icon(assigns) do
    ~H"""
    <%= case @picture do %>
      <% nil -> %>
        <div class="self-center">
          <div class="max-w-[28px] rounded-full">
            <i class="fa-solid fa-circle-user fa-2xl mt-[-1px] ml-[-1px] text-gray-600"></i>
          </div>
        </div>
      <% picture -> %>
        <div class="self-center">
          <img src={picture} referrerpolicy="no-referrer" class="rounded-full max-w-[28px]" />
        </div>
    <% end %>
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

  defp signout_path(%SessionContext{user: user, author: author}) do
    admin_role_id = Oli.Accounts.SystemRole.role_id().admin

    case {user, author} do
      {_, %Author{system_role_id: ^admin_role_id}} ->
        Routes.authoring_session_path(OliWeb.Endpoint, :signout, type: :author)

      {_user, _} ->
        Routes.session_path(OliWeb.Endpoint, :signout, type: :user)
    end
  end
end
