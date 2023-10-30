defmodule OliWeb.Components.Delivery.Layouts do
  @moduledoc """
  This module contains the layout components for the delivery UI.
  """
  use OliWeb, :html

  alias Phoenix.LiveView.JS
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.{User, Author}
  alias Oli.Branding
  alias Oli.Branding.Brand
  alias OliWeb.Components.Delivery.UserAccountMenu

  attr(:ctx, SessionContext)
  attr(:section, Section)
  attr(:brand, Brand)
  attr(:preview_mode, :boolean)
  attr(:active_tab, :atom, required: true)
  slot(:inner_block, required: true)

  def header_with_sidebar_nav(assigns) do
    ~H"""
    <div class="h-screen flex flex-col overscroll-none">
      <.header ctx={@ctx} section={@section} brand={@brand} preview_mode={@preview_mode} />

      <main role="main" class="flex-1 flex flex-col relative md:flex-row overscroll-contain">
        <.sidebar_nav ctx={@ctx} section={@section} active_tab={@active_tab} />

        <div class="flex-1 flex flex-col">
          <%= render_slot(@inner_block) %>
        </div>
      </main>
    </div>
    """
  end

  attr(:ctx, SessionContext)
  attr(:section, Section)
  attr(:brand, Brand)
  attr(:preview_mode, :boolean)

  def header(assigns) do
    ~H"""
    <div class="h-14 flex flex-row bg-delivery-header dark:bg-delivery-header-dark">
      <div class="w-48 p-2">
        <a
          className="block lg:p-2 lg:mb-14 mx-auto"
          href={logo_link_path(@preview_mode, @section, @ctx.user)}
        >
          <.logo_img />
        </a>
      </div>
      <div class="flex-grow-1 p-2">
        <div class="hidden md:block">
          <span class="text-2xl text-bold"><%= @section.title %></span>
        </div>
      </div>
      <div class="p-2">
        <div class="hidden md:block">
          <UserAccountMenu.menu id="user-account-menu" ctx={@ctx} section={@section} />
        </div>
        <button
          class="block md:hidden py-1.5 px-3 rounded border border-transparent hover:border-gray-300 active:bg-gray-100"
          phx-click={toggle_collapsed_nav()}
        >
          <i class="fa-solid fa-bars"></i>
        </button>
      </div>
    </div>
    """
  end

  # This is a workaround for toggling the hidden class and having it survive DOM patching.
  # https://elixirforum.com/t/toggle-classes-with-phoenix-liveview-js/45608/5
  defp toggle_collapsed_nav(js \\ %JS{}) do
    js
    |> JS.remove_class(
      "hidden",
      to: "#nav-menu.hidden"
    )
    |> JS.add_class(
      "hidden",
      to: "#nav-menu:not(.hidden)"
    )
  end

  attr(:ctx, SessionContext)
  attr(:section, Section)
  attr(:active_tab, :atom)

  def sidebar_nav(assigns) do
    ~H"""
    <nav
      id="nav-menu"
      class="
        flex
        hidden
        md:flex
        flex-col
        w-full
        md:w-48
        shadow-xl
        bg-delivery-navbar
        dark:bg-delivery-navbar-dark
      "
    >
      <.nav_link href={~p"/ng23/sections/#{@section.slug}"} is_active={@active_tab == :index}>
        Home
      </.nav_link>
      <.nav_link
        href={~p"/ng23/sections/#{@section.slug}/content"}
        is_active={@active_tab == :content}
      >
        Content
      </.nav_link>

      <.nav_link
        href={~p"/ng23/sections/#{@section.slug}/discussion"}
        is_active={@active_tab == :discussion}
      >
        Discussion
      </.nav_link>
      <.nav_link
        href={~p"/ng23/sections/#{@section.slug}/assignments"}
        is_active={@active_tab == :assignments}
      >
        Assignments
      </.nav_link>
      <.nav_link
        href={~p"/ng23/sections/#{@section.slug}/explorations"}
        is_active={@active_tab == :explorations}
      >
        Explorations
      </.nav_link>
      <div class="flex-grow-1"></div>

      <div class="hidden md:flex w-full px-6 py-4 text-center">
        <.tech_support_button id="tech-support" ctx={@ctx} />
      </div>

      <div class="flex flex-row md:hidden align-center justify-between border-t border-gray-300 dark:border-gray-800">
        <div class="px-6 py-4">
          <.tech_support_button id="tech-support-collapsed" ctx={@ctx} />
        </div>

        <div class="px-6 py-4">
          <UserAccountMenu.menu id="user-account-menu-sidebar" ctx={@ctx} section={@section} />
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

  def logo_link_path(is_preview_mode, section, user) do
    cond do
      is_preview_mode ->
        "#"

      is_open_and_free_section?(section) or is_independent_learner?(user) ->
        ~p"/sections"

      true ->
        Routes.static_page_path(OliWeb.Endpoint, :index)
    end
  end

  defp is_open_and_free_section?(section) do
    case section do
      %Section{open_and_free: open_and_free} ->
        open_and_free

      _ ->
        false
    end
  end

  defp is_independent_learner?(current_user) do
    case current_user do
      %User{independent_learner: independent_learner} ->
        independent_learner

      _ ->
        false
    end
  end
end
