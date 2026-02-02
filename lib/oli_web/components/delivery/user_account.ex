defmodule OliWeb.Components.Delivery.UserAccount do
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}
  alias Oli.Delivery
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React
  alias OliWeb.Components.Timezone
  alias OliWeb.Icons
  alias OliWeb.Common.Links

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext)

  attr(:is_admin, :boolean,
    required: true,
    doc:
      "if the user has an admin role (system, account, or content admin) the admin menu will be shown in the 3 workspaces (course author, instructor, and student)"
  )

  attr(:active_workspace, :atom,
    required: true,
    doc: """
    The active workspace (:course_author, :instructor or :student).
    The user or author from the context will be assigned to the menu depending on the active workspace.

    - author form ctx will be assigned to course author workspace menu.
    - user form ctx will be assigned to instructor or student workspace menu.

    There is a special case; when the user is_admin, then the author form ctx will be assigned to the menu, regardless of the active workspace.
    """
  )

  attr(:class, :string, default: "")
  attr(:dropdown_class, :string, default: "")

  def workspace_menu(%{ctx: %{author: %{system_role_id: system_role_id}}} = assigns)
      when system_role_id in [2, 3, 4] do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class={"flex flex-row items-center justify-center rounded-full outline outline-2 outline-neutral-300 dark:outline-neutral-700 hover:outline-4 hover:dark:outline-zinc-600 focus:outline-4 focus:outline-primary-300 dark:focus:outline-zinc-600 #{@class}"}
        phx-click={toggle_menu("##{@id}-dropdown")}
        aria-label={user_account_aria_label(@ctx)}
      >
        <.user_picture_icon user={@ctx.author} />
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"} class={@dropdown_class}>
        <.account_label label="Admin" class="text-yellow-500" />
        <.author_menu_items
          ctx={@ctx}
          id={@id}
          target_signout_path={target_signout_path(@active_workspace)}
          is_admin={true}
        />
      </.dropdown_menu>
    </div>
    """
  end

  def workspace_menu(%{active_workspace: :course_author} = assigns) do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class={"flex flex-row items-center justify-center rounded-full outline outline-2 outline-neutral-300 dark:outline-neutral-700 hover:outline-4 hover:dark:outline-zinc-600 focus:outline-4 focus:outline-primary-300 dark:focus:outline-zinc-600 #{@class}"}
        phx-click={toggle_menu("##{@id}-dropdown")}
        aria-label={user_account_aria_label(@ctx)}
      >
        <.user_picture_icon user={@ctx.author} />
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"} class={@dropdown_class}>
        <.account_label :if={!Accounts.is_admin?(@ctx.author)} label="Author" class="text-purple-300" />
        <.account_label :if={Accounts.is_admin?(@ctx.author)} label="Admin" class="text-yellow-500" />
        <.author_menu_items
          ctx={@ctx}
          id={@id}
          target_signout_path={target_signout_path(@active_workspace)}
          is_admin={Accounts.is_admin?(@ctx.author)}
        />
      </.dropdown_menu>
    </div>
    """
  end

  def workspace_menu(%{active_workspace: active_workspace} = assigns)
      when active_workspace in [:instructor, :student] do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class={"flex flex-row items-center justify-center rounded-full outline outline-2 outline-neutral-300 dark:outline-neutral-700 hover:outline-4 hover:dark:outline-zinc-600 focus:outline-4 focus:outline-primary-300 dark:focus:outline-zinc-600 #{@class}"}
        phx-click={toggle_menu("##{@id}-dropdown")}
        aria-label={user_account_aria_label(@ctx)}
      >
        <.user_picture_icon :if={Accounts.is_admin?(@ctx.author)} user={@ctx.author} />
        <.user_picture_icon
          :if={@ctx.user != nil and (@ctx.author == nil or !Accounts.is_admin?(@ctx.author))}
          user={@ctx.user}
        />
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"} class={@dropdown_class}>
        <.account_label
          :if={
            @ctx.user != nil and @active_workspace == :instructor and @ctx.user.can_create_sections
          }
          label="Instructor"
          class="text-emerald-400"
        />
        <.user_menu_items
          :if={@ctx.user != nil}
          ctx={@ctx}
          id={@id}
          dropdown_id={"#{@id}-dropdown"}
          target_signout_path={target_signout_path(@active_workspace)}
        />
        <.guest_menu_items :if={@ctx.user == nil} ctx={@ctx} id={@id} />
      </.dropdown_menu>
    </div>
    """
  end

  defp target_signout_path(:course_author), do: ~p"/workspaces/course_author"
  defp target_signout_path(:instructor), do: ~p"/workspaces/instructor"
  defp target_signout_path(:student), do: ~p"/workspaces/student"

  attr(:label, :string, required: true)
  attr(:class, :string, default: "")

  def account_label(assigns) do
    ~H"""
    <div role="account label" class={["text-sm font-bold font-['Roboto'] p-[5px]", @class]}>
      {@label}
    </div>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext)
  attr(:current_user, Accounts.User, default: nil)
  attr(:current_author, Accounts.Author, default: nil)
  attr(:section, Section, default: nil)
  attr(:is_admin, :boolean, required: true)
  attr(:class, :string, default: "")
  attr(:dropdown_class, :string, default: "")
  attr(:show_support_link, :boolean, default: false)

  def menu(assigns) do
    ~H"""
    <div class="relative">
      <button
        id={@id}
        class={[
          "flex flex-row items-center justify-center rounded-full",
          @class,
          "outline outline-2 outline-neutral-300 dark:outline-neutral-700 hover:outline-4 hover:dark:outline-zinc-600 focus:outline-4 focus:outline-primary-300 dark:focus:outline-zinc-600"
        ]}
        phx-click={toggle_menu("##{@id}-dropdown")}
      >
        <.user_icon ctx={@ctx} />
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"} class={@dropdown_class}>
        <%= if @is_admin do %>
          <.author_menu_items
            id={"#{@id}-menu-items-admin"}
            ctx={@ctx}
            is_admin={@is_admin}
            show_support_link={@show_support_link}
          />
        <% else %>
          <%= case assigns.ctx do %>
            <% %SessionContext{user: %User{guest: true}} -> %>
              <.guest_menu_items
                id={"#{@id}-menu-items-admin"}
                dropdown_id={"#{@id}-dropdown"}
                ctx={@ctx}
                section={@section}
              />
            <% %SessionContext{user: %User{}} -> %>
              <.user_menu_items
                id={"#{@id}-menu-items-admin"}
                dropdown_id={"#{@id}-dropdown"}
                ctx={@ctx}
                show_support_link={@show_support_link}
              />
            <% %SessionContext{author: %Author{}} -> %>
              <.author_menu_items
                id={"#{@id}-menu-items-admin"}
                ctx={@ctx}
                is_admin={@is_admin}
                show_support_link={@show_support_link}
              />
            <% _ -> %>
          <% end %>
        <% end %>
      </.dropdown_menu>
    </div>
    """
  end

  def toggle_menu(id, js \\ %JS{}) do
    js
    |> JS.toggle(
      to: id,
      in: {"ease-out duration-300", "opacity-0 translate-y-2", "opacity-100 translate-y-0"},
      out: {"ease-out duration-300", "opacity-100 translate-y-0", "opacity-0 translate-y-2"}
    )
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:target_signout_path, :string, default: "")
  attr(:show_support_link, :boolean, default: false)

  def author_menu_items(assigns) do
    ~H"""
    <.menu_item_open_admin_panel :if={@is_admin} />
    <.menu_item_link href={~p"/authors/settings"}>
      Edit Account
    </.menu_item_link>
    <.menu_divider />
    <.menu_item_dark_mode_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item_timezone_selector id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_divider />
    <.menu_item :if={@show_support_link}>
      {OliWeb.Components.Common.tech_support_button(%{id: "tech_support_author_menu"})}
    </.menu_item>
    <.menu_item_link href={~p"/authors/log_out"} method={:delete}>
      Sign out
    </.menu_item_link>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)
  attr(:dropdown_id, :string, required: true)
  attr(:target_signout_path, :string, default: "")
  attr(:show_support_link, :boolean, default: false)

  def user_menu_items(assigns) do
    ~H"""
    <.menu_item_back dropdown_id={@dropdown_id} />
    <.menu_item_profile_header ctx={@ctx} />
    <.menu_item_profile_link
      :if={!is_nil(@ctx.user) && !Accounts.user_confirmation_pending?(@ctx.user)}
      href={~p"/users/settings"}
      icon={:edit}
      label="Account Settings"
    />
    <.menu_item_confirm_user_account :if={
      is_independent_learner?(@ctx.user) && Accounts.user_confirmation_pending?(@ctx.user)
    } />
    <.menu_item_profile_link
      :if={@ctx.user && is_independent_learner?(@ctx.user)}
      href={Links.my_courses_path(@ctx.user)}
      icon={:books}
      label="My Courses"
    />
    <.menu_item_profile_link
      :if={Delivery.user_research_consent_required?(@ctx.user)}
      href={~p"/research_consent"}
      icon={:license}
      label="Research Consent"
    />
    <.menu_group_label>Theme</.menu_group_label>
    <.menu_item_profile_theme_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_group_label>Preferences</.menu_group_label>
    <.menu_item_profile_button
      :if={not_blank?(privacy_policies_url())}
      icon={:cookie}
      label="Cookies"
      onclick={"OLI.handleCookiePreferences(#{Jason.encode!(privacy_policies_url())})"}
    />
    <.menu_item_profile_timezone id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_item_linked_authoring_account
      :if={Accounts.can_manage_linked_account?(@ctx.user)}
      user={@ctx.user}
    />
    <.menu_item_profile_signout href={~p"/users/log_out"} />
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)
  attr(:section, Section, default: nil)
  attr(:dropdown_id, :string, default: nil)

  def guest_menu_items(assigns) do
    ~H"""
    <.menu_item_back dropdown_id={@dropdown_id || "#{@id}-dropdown"} />
    <.menu_item_guest_header />
    <.menu_item_profile_link
      :if={Delivery.user_research_consent_required?(@ctx.user)}
      href={~p"/research_consent"}
      icon={:license}
      label="Research Consent"
    />
    <.menu_group_label>Theme</.menu_group_label>
    <.menu_item_profile_theme_selector id={"#{@id}-dark-mode-selector"} ctx={@ctx} />
    <.menu_group_label>Preferences</.menu_group_label>
    <.menu_item_profile_button
      :if={not_blank?(privacy_policies_url())}
      icon={:cookie}
      label="Cookies"
      onclick={"OLI.handleCookiePreferences(#{Jason.encode!(privacy_policies_url())})"}
    />
    <.menu_item_profile_timezone id={"#{@id}-tz-selector"} ctx={@ctx} />
    <.menu_item_guest_actions section={@section} />
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
      class={"hidden fixed inset-0 z-50 w-full max-w-none overflow-y-auto bg-delivery-body dark:bg-delivery-body-dark rounded-none shadow-none py-4 px-0 whitespace-normal sm:absolute sm:inset-auto sm:top-[55px] sm:right-[0px] sm:bottom-auto sm:left-auto sm:h-auto sm:w-[300px] sm:rounded-xl sm:shadow-lg sm:py-3 sm:px-2 sm:border sm:border-gray-200 dark:sm:border-gray-800 sm:whitespace-nowrap #{@class}"}
    >
      <ul class="flex flex-col gap-3">
        {render_slot(@inner_block)}
      </ul>
    </div>
    """
  end

  slot(:inner_block, required: true)

  def menu_item(assigns) do
    ~H"""
    <li class="block p-1 whitespace-normal">
      {render_slot(@inner_block)}
    </li>
    """
  end

  def menu_divider(assigns) do
    ~H"""
    <li class="py-2">
      <div class="h-0 border-t border-gray-200 dark:border-zinc-800"></div>
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
        <li class="block p-1 whitespace-normal">
          <%= link to: @href, class: "w-full text-gray-800 hover:text-gray-800 dark:text-white hover:text-white text-sm font-normal font-['Roboto'] h-[26px] p-[5px] rounded-md justify-start items-center inline-flex block hover:no-underline dark:hover:bg-white/5 hover:bg-gray-100 cursor-pointer", target: @target do %>
            {render_slot(@inner_block)}
          <% end %>
        </li>
        """

      _method ->
        ~H"""
        <li class="block p-1 whitespace-normal">
          <%= link to: @href, method: @method, class: "w-full text-gray-800 hover:text-white dark:text-white text-sm font-normal font-['Roboto'] h-8 px-1.5 py-2 mt-[10px] m-[5px] rounded-md border border-rose-400 justify-center items-center gap-2.5 inline-flex cursor-pointer hover:no-underline hover:bg-red-300 hover:border-red-500 dark:hover:bg-red-950/40", target: @target do %>
            {render_slot(@inner_block)}
          <% end %>
        </li>
        """
    end
  end

  def menu_item_confirm_user_account(assigns) do
    ~H"""
    <.menu_item_link href={~p"/users/confirm"}>
      Confirm Account
    </.menu_item_link>

    <.menu_divider />
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)
  attr(:show_labels, :boolean, default: false)

  def menu_item_dark_mode_selector(assigns) do
    ~H"""
    <.menu_item>
      <.menu_item_label>Theme Settings</.menu_item_label>
      <div>
        {React.component(
          @ctx,
          "Components.DarkModeSelector",
          %{
            showLabels: @show_labels,
            idPrefix: @id
          },
          id: @id
        )}
      </div>
    </.menu_item>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def menu_item_profile_theme_selector(assigns) do
    ~H"""
    <li class="px-4 pb-4 sm:px-2">
      <div class="sm:hidden">
        {React.component(
          @ctx,
          "Components.DarkModeSelector",
          %{
            showLabels: true,
            idPrefix: @id,
            className:
              "text-sm w-full !gap-0 justify-between bg-delivery-hints-bg dark:bg-delivery-hints-bg-dark p-2 rounded-lg"
          },
          id: @id
        )}
      </div>
      <div class="hidden sm:block">
        {React.component(
          @ctx,
          "Components.DarkModeSelector",
          %{
            showLabels: false,
            idPrefix: "#{@id}-desktop",
            className:
              "text-sm w-full !gap-0 justify-between bg-delivery-hints-bg dark:bg-delivery-hints-bg-dark p-2 rounded-lg"
          },
          id: "#{@id}-desktop"
        )}
      </div>
    </li>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def menu_item_timezone_selector(assigns) do
    ~H"""
    <.menu_item>
      <.menu_item_label>Timezone</.menu_item_label>
      <div class="w-full">
        <Timezone.select id={@id} ctx={@ctx} />
      </div>
    </.menu_item>
    """
  end

  slot :inner_block, required: true

  defp menu_item_label(assigns) do
    ~H"""
    <div class="text-gray-500 dark:text-gray-400 text-xs font-medium font-['Roboto'] mb-[10px] uppercase">
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true

  defp menu_group_label(assigns) do
    ~H"""
    <li class="px-4 pt-4 pb-2 text-sm font-bold font-['Roboto'] uppercase text-gray-600 dark:text-gray-400 sm:px-2 sm:pt-0 sm:pb-0">
      {render_slot(@inner_block)}
    </li>
    """
  end

  attr(:dropdown_id, :string, required: true)

  def menu_item_back(assigns) do
    ~H"""
    <li class="px-4 py-3 border-b border-gray-200 dark:border-gray-800 sm:hidden">
      <button
        type="button"
        class="flex items-center gap-2 text-base font-semibold text-delivery-body-color dark:text-delivery-body-color-dark"
        phx-click={JS.hide(to: "##{@dropdown_id}")}
        aria-label="Close profile menu"
      >
        <i class="fa-solid fa-arrow-left"></i>
        <span>Back</span>
      </button>
    </li>
    """
  end

  defp menu_item_guest_header(assigns) do
    ~H"""
    <li class="px-4 py-3 flex items-center gap-3 border-b border-gray-200 dark:border-gray-800 sm:hidden">
      <div class="h-10 w-10 rounded-full bg-delivery-hints-bg dark:bg-delivery-hints-bg-dark flex items-center justify-center text-delivery-body-color dark:text-delivery-body-color-dark text-sm font-semibold">
        G
      </div>
      <div class="flex flex-col">
        <span class="text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark">
          Guest
        </span>
      </div>
    </li>
    """
  end

  attr(:section, Section, default: nil)

  defp menu_item_guest_actions(assigns) do
    ~H"""
    <li class="px-4 py-4 sm:px-2 flex flex-col gap-3">
      <%= link to: ~p"/users/register?#{maybe_section_param(@section)}",
        class:
          "block w-full text-center text-base font-medium text-white py-3 rounded-md bg-delivery-primary hover:bg-delivery-primary-600 shadow-md hover:no-underline" do %>
        Create an Account
      <% end %>
      <%= link to: ~p"/users/log_in?#{maybe_section_param(@section)}",
        class:
          "block w-full text-center text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark py-3 rounded-md border border-gray-300 dark:border-gray-700 shadow-md hover:no-underline hover:bg-gray-100 dark:hover:bg-gray-800/60" do %>
        Sign In
      <% end %>
    </li>
    """
  end

  attr(:ctx, SessionContext, required: true)

  def menu_item_profile_header(assigns) do
    assigns =
      assign(assigns, :account_user, account_user(assigns.ctx))

    ~H"""
    <li class="px-4 py-3 flex items-center gap-3 border-b border-gray-200 dark:border-gray-800 sm:hidden">
      <.user_picture_icon :if={@account_user} user={@account_user} size_class="h-10 w-10" />
      <div class="flex flex-col">
        <span class="text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark">
          {@account_user && @account_user.name}
        </span>
        <span class="text-sm text-gray-600 dark:text-gray-400">
          {@account_user && @account_user.email}
        </span>
      </div>
    </li>
    """
  end

  attr(:href, :string, required: true)
  attr(:icon, :any, required: true)
  attr(:label, :string, required: true)

  def menu_item_profile_link(assigns) do
    ~H"""
    <li class="border-b border-gray-200 dark:border-gray-800">
      <%= link to: @href, class: "px-4 py-3 flex items-center gap-4 hover:no-underline hover:bg-gray-100 dark:hover:bg-gray-800/60 sm:px-2" do %>
        <%= if is_atom(@icon) do %>
          {apply(Icons, @icon, [%{class: "text-gray-500 dark:text-gray-400 w-5 h-5"}])}
        <% else %>
          <i class={[@icon, "text-gray-500 dark:text-gray-400 text-lg"]}></i>
        <% end %>
        <span class="flex-1 text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark">
          {@label}
        </span>
        <i class="fa-solid fa-chevron-right text-gray-500 dark:text-gray-400 text-sm"></i>
      <% end %>
    </li>
    """
  end

  attr(:icon, :any, required: true)
  attr(:label, :string, required: true)
  attr(:onclick, :string, required: true)

  def menu_item_profile_button(assigns) do
    ~H"""
    <li class="border-b border-gray-200 dark:border-gray-800">
      <button
        type="button"
        onclick={@onclick}
        class="w-full px-4 py-3 flex items-center gap-4 hover:bg-gray-100 dark:hover:bg-gray-800/60 sm:px-2"
      >
        <%= if is_atom(@icon) do %>
          {apply(Icons, @icon, [%{class: "text-gray-500 dark:text-gray-400 w-5 h-5"}])}
        <% else %>
          <i class={[@icon, "text-gray-500 dark:text-gray-400 text-lg"]}></i>
        <% end %>
        <span class="flex-1 text-left text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark">
          {@label}
        </span>
        <i class="fa-solid fa-chevron-right text-gray-500 dark:text-gray-400 text-sm"></i>
      </button>
    </li>
    """
  end

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def menu_item_profile_timezone(assigns) do
    ~H"""
    <li class="px-4 py-3 flex flex-col gap-2 border-b border-gray-200 dark:border-gray-800 sm:px-2">
      <div class="flex items-center gap-4">
        <Icons.timezone_world class="text-gray-500 dark:text-gray-400" />
        <span class="text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark">
          Timezone
        </span>
      </div>
      <div class="w-full">
        <Timezone.select
          id={@id}
          ctx={@ctx}
          select_class="bg-delivery-hints-bg dark:bg-delivery-hints-bg-dark text-delivery-body-color dark:text-delivery-body-color-dark border-gray-300 dark:border-gray-700 h-9"
        />
      </div>
    </li>
    """
  end

  attr(:href, :string, required: true)

  def menu_item_profile_signout(assigns) do
    ~H"""
    <li class="px-4 py-4 sm:px-2">
      <%= link to: @href, method: :delete, class: "block w-full text-center text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark py-3 rounded-md border border-red-500 shadow-md hover:no-underline hover:bg-red-600/10" do %>
        Sign Out
      <% end %>
    </li>
    """
  end

  attr(:user, User, required: true)

  defp menu_item_linked_authoring_account(assigns) do
    ~H"""
    <%= case Accounts.linked_author_account(@user) do %>
      <% nil -> %>
        <li class="border-b border-gray-200 dark:border-gray-800">
          <%= link to: ~p"/users/link_account",
            class:
              "px-4 py-3 flex items-center gap-4 hover:no-underline hover:bg-gray-100 dark:hover:bg-gray-800/60 sm:px-2" do %>
            <span class="flex-1 text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark">
              Link authoring account
            </span>
            <i class="fa-solid fa-chevron-right text-gray-500 dark:text-gray-400 text-sm"></i>
          <% end %>
        </li>
      <% %Author{email: linked_author_account_email} -> %>
        <li class="px-4 pt-4 pb-2 text-sm font-bold font-['Roboto'] uppercase text-gray-600 dark:text-gray-400 sm:px-2 sm:pt-0 sm:pb-0">
          Linked Authoring Account
        </li>
        <li class="border-b border-gray-200 dark:border-gray-800">
          <%= link to: ~p"/users/link_account",
            class:
              "px-4 py-3 flex items-center gap-4 hover:no-underline hover:bg-gray-100 dark:hover:bg-gray-800/60 sm:px-2" do %>
            <div
              class="flex-1 overflow-hidden text-ellipsis text-base font-medium text-delivery-body-color dark:text-delivery-body-color-dark"
              role="linked authoring account email"
            >
              {linked_author_account_email}
            </div>
            <i class="fa-solid fa-chevron-right text-gray-500 dark:text-gray-400 text-sm"></i>
          <% end %>
        </li>
    <% end %>
    """
  end

  @spec menu_item_open_admin_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_item_open_admin_panel(assigns) do
    ~H"""
    <.menu_item_link href={~p"/admin"}>
      <.icon name="fa-solid fa-wrench" class="mr-2" /> Admin Panel
    </.menu_item_link>

    <.menu_divider />
    """
  end

  attr(:ctx, SessionContext, required: true)

  defp maybe_research_consent_link(assigns) do
    ~H"""
    <%= if Delivery.user_research_consent_required?(@ctx.user) do %>
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
  attr(:size_class, :string, default: "h-8 w-8")

  def user_picture_icon(assigns) do
    ~H"""
    <%= case @user.picture do %>
      <% nil -> %>
        <div
          role="img"
          class={[
            "bg-delivery-primary-700 dark:bg-zinc-800 rounded-full flex justify-center items-center text-white text-sm font-semibold leading-[14px]",
            @size_class
          ]}
          aria-label={"#{@user.name} profile avatar"}
        >
          {to_initials(@user)}
        </div>
      <% picture -> %>
        <div class="flex justify-center items-center">
          <img
            src={picture}
            referrerpolicy="no-referrer"
            class={["rounded-full", @size_class]}
            alt={"#{@user.name} profile avatar"}
          />
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

  attr(:ctx, SessionContext, required: true)

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
        aria-label={user_account_aria_label(@ctx)}
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

  def maybe_section_param(%Section{slug: slug}), do: [section: slug]
  def maybe_section_param(_), do: []

  defp user_account_aria_label(%SessionContext{} = ctx) do
    name =
      cond do
        match?(%{author: %{name: name}} when is_binary(name), ctx) -> ctx.author.name
        match?(%{user: %{name: name}} when is_binary(name), ctx) -> ctx.user.name
        true -> nil
      end

    case name && String.trim(name) do
      nil -> "user account menu"
      "" -> "user account menu"
      trimmed -> "#{trimmed} user account menu"
    end
  end

  defp to_initials(%{name: nil}), do: "G"

  defp to_initials(%{name: name}) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
  end

  defp to_initials(_), do: "?"

  defp account_user(%SessionContext{user: %User{} = user}), do: user
  defp account_user(%SessionContext{author: %Author{} = author}), do: author
  defp account_user(_), do: nil

  defp privacy_policies_url(), do: Application.fetch_env!(:oli, :privacy_policies)[:url]

  defp not_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp not_blank?(_), do: false
end
