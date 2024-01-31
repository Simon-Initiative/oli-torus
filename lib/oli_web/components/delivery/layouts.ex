defmodule OliWeb.Components.Delivery.Layouts do
  @moduledoc """
  This module contains the layout components for the delivery UI.
  """
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.{User, Author}
  alias Oli.Branding
  alias Oli.Branding.Brand
  alias OliWeb.Components.Delivery.UserAccount
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias OliWeb.Delivery.Student.Utils

  attr(:ctx, SessionContext)
  attr(:is_system_admin, :boolean, required: true)
  attr(:section, Section, default: nil)
  attr(:project, Project, default: nil)
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
        <.title section={@section} project={@project} preview_mode={@preview_mode} />
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

  attr(:section, Section, default: nil)
  attr(:project, Project, default: nil)
  attr(:preview_mode, :boolean)

  def title(assigns) do
    ~H"""
    <div :if={@section} class="hidden md:block">
      <span class="text-2xl text-bold">
        <%= @section.title %><%= if @preview_mode, do: " (Preview Mode)" %>
      </span>
    </div>
    <div :if={@project} class="hidden md:block">
      <span class="text-2xl text-bold">
        <%= @project.title %>
      </span>
    </div>
    """
  end

  attr(:ctx, SessionContext)
  attr(:is_system_admin, :boolean, required: true)
  attr(:section, Section, default: nil)
  attr(:active_tab, :atom)
  attr(:preview_mode, :boolean)

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
      <.nav_link href={path_for(:index, @section, @preview_mode)} is_active={@active_tab == :index}>
        Home
      </.nav_link>
      <.nav_link href={path_for(:learn, @section, @preview_mode)} is_active={@active_tab == :learn}>
        Learn
      </.nav_link>

      <.nav_link
        href={path_for(:discussions, @section, @preview_mode)}
        is_active={@active_tab == :discussions}
      >
        Discussions
      </.nav_link>
      <.nav_link
        href={path_for(:schedule, @section, @preview_mode)}
        is_active={@active_tab == :schedule}
      >
        Schedule
      </.nav_link>
      <.nav_link
        href={path_for(:explorations, @section, @preview_mode)}
        is_active={@active_tab == :explorations}
      >
        Explorations
      </.nav_link>
      <.nav_link
        href={path_for(:practice, @section, @preview_mode)}
        is_active={@active_tab == :practice}
      >
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

  defp path_for(:index, %Section{slug: section_slug}, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview"
    else
      ~p"/sections/#{section_slug}"
    end
  end

  defp path_for(:index, _section, _preview_mode) do
    "#"
  end

  defp path_for(:learn, %Section{slug: section_slug}, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/learn"
    else
      ~p"/sections/#{section_slug}/learn"
    end
  end

  defp path_for(:learn, _section, _preview_mode) do
    "#"
  end

  defp path_for(:discussions, %Section{slug: section_slug}, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/discussions"
    else
      ~p"/sections/#{section_slug}/discussions"
    end
  end

  defp path_for(:discussions, _section, _preview_mode) do
    "#"
  end

  defp path_for(:schedule, %Section{slug: section_slug}, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/assignments"
    else
      ~p"/sections/#{section_slug}/assignments"
    end
  end

  defp path_for(:schedule, _section, _preview_mode) do
    "#"
  end

  defp path_for(:explorations, %Section{slug: section_slug}, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/explorations"
    else
      ~p"/sections/#{section_slug}/explorations"
    end
  end

  defp path_for(:explorations, _section, _preview_mode) do
    "#"
  end

  defp path_for(:practice, %Section{slug: section_slug}, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/practice"
    else
      ~p"/sections/#{section_slug}/practice"
    end
  end

  defp path_for(:practice, _section, _preview_mode) do
    "#"
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

  attr(:current_page, :map)
  attr(:previous_page, :map)
  attr(:next_page, :map)
  attr(:section_slug, :string)
  attr(:request_path, :string)

  def previous_next_nav(assigns) do
    # <.links /> were changed from "navigate" to "href" to force a page reload
    # to fix a bug where the page content would render incorrectly some components
    # (for instance, the popup or the formula component from Oli.Rendering.Content.Html)
    # and the page would not react to interactions after navigation to another page
    # ("working" loader kept spinning after interacting with an activity)
    ~H"""
    <div
      :if={!is_nil(@current_page)}
      class="fixed bottom-0 left-1/2 -translate-x-1/2 h-[74px] py-4 shadow-lg bg-white dark:bg-black lg:rounded-tl-[40px] lg:rounded-tr-[40px] flex items-center gap-3 lg:w-[720px] w-full"
    >
      <div class="hidden lg:block absolute -left-[114px] z-0">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="170"
          height="74"
          viewBox="0 0 170 74"
          fill="none"
        >
          <path
            class="fill-white dark:fill-black"
            d="M170 0H134C107 0 92.5 13 68.5 37C44.5 61 24.2752 74 0 74H170V0Z"
          />
        </svg>
      </div>

      <div
        :if={!is_nil(@previous_page)}
        class="grow shrink basis-0 h-10 justify-start items-center lg:gap-6 flex z-10 overflow-hidden whitespace-nowrap"
        role="prev_page"
      >
        <div class="px-2 lg:px-6 rounded justify-end items-center gap-2 flex">
          <.link href={resource_navigation_url(@previous_page, @section_slug, @request_path)}>
            <div class="w-[72px] h-10 opacity-30 hover:opacity-40 bg-blue-600 flex items-center justify-center cursor-pointer">
              <.left_arrow />
            </div>
          </.link>
        </div>
        <div class="grow shrink basis-0 dark:text-white text-xs font-normal overflow-hidden text-ellipsis">
          <%= @previous_page["title"] %>
        </div>
      </div>

      <div
        :if={!is_nil(@next_page)}
        class="grow shrink basis-0 h-10 justify-end items-center lg:gap-6 flex z-10 overflow-hidden whitespace-nowrap"
        role="next_page"
      >
        <div class="grow shrink basis-0 text-right dark:text-white text-xs font-normal overflow-hidden text-ellipsis">
          <%= @next_page["title"] %>
        </div>
        <div class="px-2 lg:px-6 py-2 rounded justify-end items-center gap-2 flex">
          <.link href={resource_navigation_url(@next_page, @section_slug, @request_path)}>
            <div class="w-[72px] h-10 opacity-90 hover:opacity-100 bg-blue-600 flex items-center justify-center cursor-pointer">
              <.right_arrow />
            </div>
          </.link>
        </div>
      </div>

      <div class="hidden lg:block absolute -right-[114px] z-0">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="170"
          height="74"
          viewBox="0 0 170 74"
          fill="none"
        >
          <path
            class="fill-white dark:fill-black"
            d="M0 0H36C63 0 77.5 13 101.5 37C125.5 61 145.725 74 170 74H0V0Z"
          />
        </svg>
      </div>
    </div>
    """
  end

  defp resource_navigation_url(
         %{"slug" => slug, "type" => "page", "id" => resource_id},
         section_slug,
         request_path
       ) do
    # If the request_path is the Learn page and we navigate to a different lesson,
    # we need to update the request_path to include the new target resource.
    if request_path && String.contains?(request_path, "/learn") do
      request_path = Utils.learn_live_path(section_slug, resource_id)
      Utils.lesson_live_path(section_slug, slug, request_path)
    else
      Utils.lesson_live_path(section_slug, slug, request_path)
    end
  end

  defp resource_navigation_url(%{"id" => container_id}, section_slug, _) do
    Utils.learn_live_path(section_slug, container_id)
  end

  attr(:to, :string)

  def back_arrow(assigns) do
    ~H"""
    <div
      class="flex justify-center items-center absolute top-2 lg:top-10 left-2 lg:left-12 p-4"
      role="back_link"
    >
      <.link navigate={@to} class="hover:no-underline hover:scale-105 cursor-pointer">
        <svg
          width="34"
          height="33"
          viewBox="0 0 34 33"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          class="hover:opacity-100 hover:scale-105"
        >
          <path
            d="M17.0459 32.5278C8.19971 32.5278 0.884277 25.2124 0.884277 16.3662C0.884277 7.50391 8.18359 0.20459 17.0298 0.20459C25.8921 0.20459 33.2075 7.50391 33.2075 16.3662C33.2075 25.2124 25.8921 32.5278 17.0459 32.5278ZM17.0459 30.4331C24.8447 30.4331 31.1289 24.1489 31.1289 16.3662C31.1289 8.56738 24.8286 2.2832 17.0298 2.2832C9.24707 2.2832 2.979 8.56738 2.979 16.3662C2.979 24.1489 9.24707 30.4331 17.0459 30.4331ZM20.1235 24.2778C19.7852 24.6162 19.1567 24.6001 18.7861 24.2456L11.8252 17.5747C11.1162 16.9141 11.1001 15.8184 11.8252 15.1416L18.7861 8.4707C19.189 8.1001 19.7529 8.1001 20.1235 8.43848C20.5103 8.79297 20.5103 9.42139 20.1235 9.79199L13.2593 16.3501L20.1235 22.9404C20.5103 23.2949 20.5103 23.8911 20.1235 24.2778Z"
            fill="#9D9D9D"
          />
        </svg>
      </.link>
    </div>
    """
  end

  defp left_arrow(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
      <path d="M7.825 13H20V11H7.825L13.425 5.4L12 4L4 12L12 20L13.425 18.6L7.825 13Z" fill="white" />
    </svg>
    """
  end

  defp right_arrow(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      class="rotate-180"
    >
      <path d="M7.825 13H20V11H7.825L13.425 5.4L12 4L4 12L12 20L13.425 18.6L7.825 13Z" fill="white" />
    </svg>
    """
  end

  def annotations_dropdown(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5 absolute top-10 right-12 z-50 p-4 hidden">
      <div class="flex py-1.5 pl-[18px] items-center gap-2.5">
        <div class="w-6 h-6 relative opacity-50">
          <i class="fa-solid fa-eye" />
        </div>
        <div class="w-[132px] dark:text-white text-xs font-bold uppercase tracking-wide">
          All annotations
        </div>
      </div>
      <div class="w-6 h-6 justify-center items-center gap-2.5 inline-flex">
        <i class="fa-solid fa-caret-down" />
      </div>
    </div>
    """
  end

  attr :additional_classes, :string,
    default: "",
    required: false,
    doc: """
    Additional classes to add to the spinner.
    If you want to override the default styling you may probably need to add the Tailwind classes
    with the '!' important flag, ex: "!w-10 !h-10"
    """

  def spinner(assigns) do
    ~H"""
    <svg
      aria-hidden="true"
      class={[
        "w-8 h-8 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600",
        @additional_classes
      ]}
      viewBox="0 0 100 101"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
        fill="currentColor"
      />
      <path
        d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
        fill="currentFill"
      />
    </svg>
    <span class="sr-only">Loading...</span>
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

  defp logo_link_path(preview_mode, section, user) do
    cond do
      preview_mode ->
        "#"

      is_open_and_free_section?(section) or is_independent_learner?(user) ->
        ~p"/sections"

      true ->
        Routes.static_page_path(OliWeb.Endpoint, :index)
    end
  end

  def show_collab_space?(nil), do: false
  def show_collab_space?(%CollabSpaceConfig{status: :disabled}), do: false
  def show_collab_space?(_), do: true
end
