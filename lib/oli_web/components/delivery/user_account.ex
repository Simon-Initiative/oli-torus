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

  def menu(assigns) do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class="
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
        "
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
      <.dropdown_menu id={"#{@id}-dropdown"}>
        <%= case assigns.ctx do %>
          <% %SessionContext{author: %Author{} = author, is_admin: true} -> %>
            <.admin_menu_items id={"#{@id}-menu-items-admin"} ctx={@ctx} />
          <% %SessionContext{user: %User{guest: true}} -> %>
            <.guest_menu_items id={"#{@id}-menu-items-admin"} ctx={@ctx} />
          <% %SessionContext{user: %User{} = user} -> %>
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
    """
  end

  attr(:id, :string, required: true)
  slot :inner_block, required: true

  def dropdown_menu(assigns) do
    ~H"""
    <div
      id={@id}
      class="hidden absolute top-[50px] right-0 z-50 whitespace-nowrap bg-white dark:bg-black p-2 rounded-lg shadow-lg"
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
      <div>
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

  # attr :user, User, default: nil

  # def user_icon(assigns) do
  #   ~H"""
  #   <%= case @user do %>
  #     <% nil -> %>
  #       <div className="user-icon">
  #         <div className="user-img rounded-full">
  #           <i className="fa-solid fa-circle-user fa-2xl mt-[-1px] ml-[-1px] text-gray-600"></i>
  #         </div>
  #       </div>
  #     <% %User{picture: picture} -> %>
  #       <div className="user-icon">
  #         <img src={picture} className="rounded-full" referrerPolicy="no-referrer" />
  #       </div>
  #   <% end %>
  #   """
  # end

  # def menu(assigns) do
  #   assigns = user_account_menu_assigns(assigns)

  #   ~H"""
  #   <%= React.component(
  #     @ctx,
  #     "Components.UserAccountMenu",
  #     %{
  #       user: @user,
  #       preview: @preview,
  #       routes: @routes,
  #       sectionSlug: @section_slug,
  #       selectedTimezone: @selected_timezone,
  #       timezones: @timezones
  #     },
  #     id: "menu",
  #     target_id: "user-menu"
  #   ) %>
  #   """
  # end

  # def user_menu_loader(assigns) do
  #   ~H"""
  #   <svg
  #     width="158.507"
  #     height="43.756"
  #     viewBox="0 0 40.857 11.279"
  #     xmlns="http://www.w3.org/2000/svg"
  #   >
  #     <!-- Animated gradient -->
  #     <defs>
  #       <linearGradient id="loader-gradient" gradientTransform="rotate(20)">
  #         <stop offset="5%" stop-color="#eee">
  #           <animate
  #             attributeName="stop-color"
  #             values="#EEEEEE; #CCCCCC; #EEEEEE"
  #             dur="1s"
  #             repeatCount="indefinite"
  #           >
  #           </animate>
  #         </stop>
  #         <stop offset="95%" stop-color="#aaa">
  #           <animate
  #             attributeName="stop-color"
  #             values="#EEEEEE; #DDDDDD; #EEEEEE"
  #             dur="3s"
  #             repeatCount="indefinite"
  #           >
  #           </animate>
  #         </stop>
  #       </linearGradient>
  #     </defs>

  #     <g transform="translate(-8.79 -1.99)">
  #       <circle fill="url(#loader-gradient)" cx="44.009" cy="7.63" r="5.639" /><path
  #         fill="url(#loader-gradient)"
  #         d="M8.791 4.478h27.588v2.267H8.791z"
  #       /><path fill="url(#loader-gradient)" d="M16.78 8.321h19.627v2.267H16.78z" />
  #     </g>
  #   </svg>
  #   """
  # end

  # def user_account_menu_assigns(assigns) do
  #   assigns
  #   |> assign(
  #     :user,
  #     case assigns.ctx do
  #       %SessionContext{user: user_or_admin} when not is_nil(user_or_admin) ->
  #         %{
  #           picture: user_or_admin.picture,
  #           name: user_name(user_or_admin),
  #           role: user_role(assigns[:section], user_or_admin),
  #           roleLabel: user_role_text(assigns[:section], user_or_admin),
  #           roleColor: user_role_color(assigns[:section], user_or_admin),
  #           isGuest: user_is_guest?(assigns),
  #           isIndependentInstructor: Sections.is_independent_instructor?(user_or_admin),
  #           isIndependentLearner: user_is_independent_learner?(user_or_admin),
  #           linkedAuthorAccount: linked_author_account(user_or_admin),
  #           selectedTimezone: timezone_preference(user_or_admin)
  #         }

  #       %SessionContext{author: author} when not is_nil(author) ->
  #         %{
  #           picture: author.picture,
  #           name: user_name(author),
  #           role: user_role(assigns[:section], author),
  #           roleLabel: user_role_text(assigns[:section], author),
  #           roleColor: user_role_color(assigns[:section], author),
  #           isGuest: user_is_guest?(assigns),
  #           isIndependentInstructor: Sections.is_independent_instructor?(author),
  #           isIndependentLearner: user_is_independent_learner?(author),
  #           linkedAuthorAccount: linked_author_account(author),
  #           selectedTimezone: timezone_preference(author)
  #         }

  #       _ ->
  #         nil
  #     end
  #   )
  #   |> assign(:preview, is_preview_mode?(assigns))
  #   |> assign(
  #     :routes,
  #     %{
  #       signin:
  #         Routes.delivery_path(OliWeb.Endpoint, :signin, section: maybe_section_slug(assigns)),
  #       signout: signout_path(assigns.ctx),
  #       projects: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive),
  #       linkAccount: Routes.delivery_path(OliWeb.Endpoint, :link_account),
  #       editAccount: Routes.pow_registration_path(OliWeb.Endpoint, :edit),
  #       updateTimezone: Routes.static_page_path(OliWeb.Endpoint, :update_timezone),
  #       openAndFreeIndex: ~p"/sections"
  #     }
  #   )
  #   |> assign(
  #     :section_slug,
  #     maybe_section_slug(assigns)
  #   )
  #   |> OliWeb.Common.SelectTimezone.timezone_assigns()
  # end

  # defp signout_path(%SessionContext{user: user_or_admin}) do
  #   admin_role_id = SystemRole.role_id().admin

  #   case user_or_admin do
  #     %Author{system_role_id: ^admin_role_id} ->
  #       Routes.authoring_session_path(OliWeb.Endpoint, :signout, type: :author)

  #     _ ->
  #       Routes.session_path(OliWeb.Endpoint, :signout, type: :user)
  #   end
  # end
end
