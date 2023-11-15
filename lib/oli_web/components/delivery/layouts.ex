defmodule OliWeb.Components.Delivery.Layouts do
  @moduledoc """
  This module contains the layout components for the delivery UI.
  """
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.{User, Author}
  alias Oli.Branding
  alias Oli.Branding.Brand
  alias OliWeb.Components.Delivery.UserAccount

  attr(:ctx, SessionContext)
  attr(:section, Section)
  attr(:brand, Brand)
  attr(:preview_mode, :boolean)
  attr(:active_tab, :atom, required: true)
  slot(:inner_block, required: true)

  def header_with_sidebar_nav(assigns) do
    assigns = assign(assigns, :is_system_admin, assigns[:is_system_admin] || false)

    ~H"""
    <div class="h-screen flex flex-col overscroll-none">
      <.header
        ctx={@ctx}
        is_system_admin={@is_system_admin}
        section={@section}
        brand={@brand}
        preview_mode={@preview_mode}
      />

      <main role="main" class="flex-1 flex flex-col relative md:flex-row overscroll-contain">
        <.sidebar_nav
          ctx={@ctx}
          is_system_admin={@is_system_admin}
          section={@section}
          active_tab={@active_tab}
        />

        <div class="md:w-[calc(100%-192px)] flex-1 flex flex-col md:ml-48 mt-14">
          <%= render_slot(@inner_block) %>
        </div>
      </main>
    </div>
    """
  end

  attr :flash, :any, required: true

  def flash_messages(assigns) do
    ~H"""
    <div id="live_flash_container" class="flash container mx-auto px-0 sticky top-[80px]">
      <%= if live_flash(@flash, :info) do %>
        <div class="alert alert-info flex flex-row" role="alert">
          <div class="flex-1">
            <%= live_flash(@flash, :info) %>
          </div>

          <button
            type="button"
            class="close"
            data-bs-dismiss="alert"
            aria-label="Close"
            phx-click="lv:clear-flash"
            phx-value-key="info"
          >
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      <% end %>

      <%= if live_flash(@flash, :error) do %>
        <div class="alert alert-danger flex flex-row" role="alert">
          <div class="flex-1">
            <%= live_flash(@flash, :error) %>
          </div>

          <button
            type="button"
            class="close"
            data-bs-dismiss="alert"
            aria-label="Close"
            phx-click="lv:clear-flash"
            phx-value-key="error"
          >
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  attr(:ctx, SessionContext)
  attr(:is_system_admin, :boolean, required: true)
  attr(:section, Section)
  attr(:brand, Brand)
  attr(:preview_mode, :boolean)

  def header(assigns) do
    ~H"""
    <div class="fixed z-50 w-full h-14 flex flex-row bg-delivery-header dark:bg-delivery-header-dark shadow-sm">
      <div class="w-48 p-2">
        <a
          className="block lg:p-2 lg:mb-14 mx-auto"
          href={logo_link_path(@preview_mode, @section, @ctx.user)}
        >
          <.logo_img />
        </a>
      </div>
      <div class="flex items-center flex-grow-1 p-2">
        <div :if={@section} class="hidden md:block">
          <span class="text-2xl text-bold">
            <%= @section.title %><%= if @preview_mode, do: " (Preview Mode)" %>
          </span>
        </div>
      </div>
      <div class="flex items-center p-2">
        <div class="hidden md:block">
          <UserAccount.menu
            id="user-account-menu"
            ctx={@ctx}
            section={@section}
            is_system_admin={@is_system_admin}
          />
        </div>
        <button
          class="block md:hidden py-1.5 px-3 rounded border border-transparent hover:border-gray-300 active:bg-gray-100"
          phx-click={toggle_class(%JS{}, "hidden", to: "#nav-menu")}
        >
          <i class="fa-solid fa-bars"></i>
        </button>
      </div>
    </div>
    """
  end

  attr(:ctx, SessionContext)
  attr(:is_system_admin, :boolean, required: true)
  attr(:section, Section)
  attr(:active_tab, :atom)

  def sidebar_nav(assigns) do
    ~H"""
    <nav
      id="nav-menu"
      class="
        fixed
        z-50
        mt-14
        md:h-[calc(100vh-56px)]
        flex
        hidden
        md:flex
        flex-col
        w-full
        md:w-48
        shadow-sm
        bg-delivery-navbar
        dark:bg-delivery-navbar-dark
      "
    >
      <.nav_link href={~p"/sections/#{@section.slug}"} is_active={@active_tab == :index}>
        Home
      </.nav_link>
      <.nav_link href={~p"/sections/#{@section.slug}/content"} is_active={@active_tab == :content}>
        Content
      </.nav_link>

      <.nav_link
        href={~p"/sections/#{@section.slug}/discussion"}
        is_active={@active_tab == :discussion}
      >
        Discussion
      </.nav_link>
      <.nav_link
        href={~p"/sections/#{@section.slug}/assignments"}
        is_active={@active_tab == :assignments}
      >
        Assignments
      </.nav_link>
      <.nav_link
        href={~p"/sections/#{@section.slug}/explorations"}
        is_active={@active_tab == :explorations}
      >
        Explorations
      </.nav_link>
      <.nav_link href={~p"/sections/#{@section.slug}/practice"} is_active={@active_tab == :practice}>
        Practice
      </.nav_link>

      <div class="hidden md:flex w-full px-6 py-4 text-center mt-auto">
        <.tech_support_button id="tech-support" ctx={@ctx} />
      </div>

      <div class="flex flex-row md:hidden align-center justify-between border-t border-gray-300 dark:border-gray-800">
        <div class="px-6 py-4">
          <.tech_support_button id="tech-support-collapsed" ctx={@ctx} />
        </div>

        <div class="px-6 py-4">
          <UserAccount.menu
            id="user-account-menu-sidebar"
            ctx={@ctx}
            is_system_admin={@is_system_admin}
            section={@section}
          />
        </div>
      </div>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :is_active, :boolean, required: true
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <.link navigate={@href} class={nav_link_class(@is_active)}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  defp nav_link_class(is_active) do
    case is_active do
      true ->
        "px-6 py-4 text-current hover:no-underline hover:text-delivery-primary font-bold bg-gray-50 dark:bg-gray-800"

      false ->
        "px-6 py-4 text-current hover:no-underline hover:text-delivery-primary"
    end
  end

  attr(:section, Section)
  attr(:brand, Brand)

  def logo_img(assigns) do
    assigns =
      assigns
      |> assign(:logo_src, Branding.brand_logo_url(assigns[:section]))
      |> assign(:logo_src_dark, Branding.brand_logo_url_dark(assigns[:section]))

    ~H"""
    <img src={@logo_src} class="inline-block dark:hidden" alt="logo" />
    <img src={@logo_src_dark} class="hidden dark:inline-block" alt="logo dark" />
    """
  end

  attr(:id, :string)
  attr(:ctx, SessionContext)

  def tech_support_button(assigns) do
    ~H"""
    <%= React.component(
      @ctx,
      "Components.TechSupportButton",
      %{},
      id: @id
    ) %>
    """
  end

  def user_given_name(%SessionContext{user: user, author: author}) do
    case {user, author} do
      {%User{guest: true}, _} ->
        "Guest"

      {%User{given_name: given_name}, _} ->
        given_name

      {_, %Author{given_name: given_name}} ->
        given_name

      {_, _} ->
        ""
    end
  end

  def user_name(%SessionContext{user: user, author: author}) do
    case {user, author} do
      {%User{guest: true}, _} ->
        "Guest"

      {%User{name: name}, _} ->
        name

      {_, %Author{name: name}} ->
        name

      {_, _} ->
        ""
    end
  end

  defp logo_link_path(is_preview_mode, section, user) do
    cond do
      is_preview_mode ->
        "#"

      is_open_and_free_section?(section) or is_independent_learner?(user) ->
        ~p"/sections"

      true ->
        Routes.static_page_path(OliWeb.Endpoint, :index)
    end
  end
end
