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

  attr :current_user, :map

  def footer(assigns) do
    ~H"""
    <div class="fixed z-50 w-full bottom-0 flex flex-row">
      <div class="ml-auto">
        <.ai_bot current_user={@current_user} />
      </div>
    </div>
    """
  end

  attr :current_user, :map

  def ai_bot(assigns) do
    ~H"""
    <.conversation current_user={@current_user} />
    <div id="ai_bot_collapsed" class="w-[170px] h-[74px] relative ml-auto">
      <div
        phx-click={
          JS.hide(to: "#ai_bot_collapsed")
          |> JS.show(
            to: "#ai_bot_conversation",
            transition:
              {"ease-out duration-1000", "translate-x-full translate-y-full",
               "translate-x-0 translate-y-0"}
          )
        }
        class="absolute right-[1px] cursor-pointer hover:scale-105"
      >
        <img
          class="animate-[spin_40s_cubic-bezier(0.4,0,0.6,1)_infinite]"
          src={~p"/images/ng23/footer_dot_ai.png"}
        />
        <div class="w-[39.90px] h-[39.90px] absolute bottom-4 right-4 bg-zinc-300 rounded-full blur-[30px] animate-[pulse_3s_cubic-bezier(0.4,0,0.6,1)_infinite]">
        </div>
      </div>
      <.left_to_right_fade_in_icon />
    </div>
    """
  end

  attr :current_user, :map

  def conversation(assigns) do
    ~H"""
    <div
      id="ai_bot_conversation"
      class="right-0 hidden mb-1 mr-2"
      phx-click-away={JS.dispatch("click", to: "#close_chat_button")}
      phx-window-keydown={JS.dispatch("click", to: "#close_chat_button")}
      phx-key="escape"
    >
      <div class="w-[556px] h-[634px] shadow-lg bg-white dark:bg-[#0A0A17] rounded-3xl flex-col justify-center items-start inline-flex">
        <div class="self-stretch h-[45px] pl-6 pr-3 pt-3 rounded-t-3xl bg-slate-400 dark:bg-black justify-end items-start gap-2.5 inline-flex">
          <div class="w-6 h-6 relative mt-1">
            <div
              id="close_chat_button"
              phx-click={
                JS.hide(
                  to: "#ai_bot_conversation",
                  transition:
                    {"ease-out duration-700", "translate-x-1/4 translate-y-1/4",
                     "translate-x-full translate-y-full"}
                )
                |> JS.show(
                  to: "#ai_bot_collapsed",
                  transition:
                    {"ease-out duration-700 delay-1000", "translate-x-full translate-y-full",
                     "translate-x-3/4 translate-y-0"}
                )
              }
              class="w-8 h-[34px] left-[-4px] top-[-4px] absolute cursor-pointer opacity-80 dark:opacity-100 dark:hover:opacity-80 hover:opacity-100 hover:scale-105"
            >
              <.close_icon />
            </div>
          </div>
        </div>
        <div class="h-[480px] self-stretch grow shrink basis-0 p-6 flex-col justify-end items-center gap-5 inline-flex overflow-y-auto">
          <div
            role="message container"
            class="self-stretch h-[480px] flex-col justify-end items-center gap-1.5 flex"
          >
            <.chat_message
              index={1}
              content="Can you tell me the answer please?"
              user_initials={to_initials(@current_user)}
            />
            <.chat_message
              index={2}
              content="I noticed you have attempted the ‘Did I get this?’ question. As shown, this answer is incorrect.<br/>This statement aligns with Dalton's Atomic Theory. One of the key principles of Dalton's theory was that elements consist of tiny, indivisible particles called atoms<br/>What is the main focus of Dalton's Atomic Theory? What is it primarily concerned with?"
            />
            <.chat_message
              index={3}
              content="The main focus of Dalton's theory is on atoms, the fundamental building blocks of matter"
              user_initials={to_initials(@current_user)}
            />
            <.chat_message
              index={4}
              content="Option 1 states that ' The elements that make up matter are fire, earth, air, and water. '<br/>Does this statement sound like it belongs to Dalton's Atomic Theory? Why or why not?"
            />
          </div>
          <div class="self-stretch h-[55px] flex-col justify-start items-start gap-3 flex">
            <div class="self-stretch grow shrink basis-0 px-3 py-1.5 rounded-xl border border-black dark:border-white border-opacity-40 justify-start items-center gap-2 inline-flex">
              <div class="rounded-xl justify-center items-center gap-3 flex">
                <div class="px-1.5 py-[3px] justify-center items-center flex">
                  <.mic_icon />
                </div>
              </div>
              <div class="grow shrink basis-0 h-[43px] py-3 justify-start items-start gap-2 flex">
                <div class="opacity-40 dark:text-white text-sm font-normal font-['Open Sans'] tracking-tight">
                  How can I help?
                </div>
              </div>
              <div class="w-[38px] h-[38px] px-6 py-2 opacity-60 bg-blue-800 rounded-lg justify-center items-center gap-3 flex cursor-pointer hover:opacity-50">
                <div class="w-[25px] h-[25px] pl-[3.12px] pr-[2.08px] py-[4.17px] justify-center items-center flex">
                  <.submit_icon />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def close_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
      <path
        d="M6.2248 18.8248L5.1748 17.7748L10.9498 11.9998L5.1748 6.2248L6.2248 5.1748L11.9998 10.9498L17.7748 5.1748L18.8248 6.2248L13.0498 11.9998L18.8248 17.7748L17.7748 18.8248L11.9998 13.0498L6.2248 18.8248Z"
        class="fill-black dark:fill-white"
      />
    </svg>
    """
  end

  def mic_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="25"
      viewBox="0 0 24 25"
      fill="none"
      role="mic button"
      class="cursor-pointer hover:scale-105 hover:opacity-50"
    >
      <path
        d="M6 10.5V11.5C6 14.8137 8.68629 17.5 12 17.5M18 10.5V11.5C18 14.8137 15.3137 17.5 12 17.5M12 17.5V21.5M12 21.5H16M12 21.5H8M12 14.5C10.3431 14.5 9 13.1569 9 11.5V6.5C9 4.84315 10.3431 3.5 12 3.5C13.6569 3.5 15 4.84315 15 6.5V11.5C15 13.1569 13.6569 14.5 12 14.5Z"
        class="dark:stroke-white stroke-zinc-800"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  def submit_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="26"
      height="25"
      viewBox="0 0 26 25"
      fill="none"
      role="submit button"
    >
      <path
        d="M3.625 20.8332V14.453L11.4896 12.4998L3.625 10.4946V4.1665L23.4167 12.4998L3.625 20.8332Z"
        fill="white"
      />
    </svg>
    """
  end

  def left_to_right_fade_in_icon(assigns) do
    ~H"""
    <svg
      class="fill-black dark:opacity-100"
      width="170"
      height="74"
      viewBox="0 0 170 74"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M170 0H134C107 0 92.5 13 68.5 37C44.5 61 24.2752 74 0 74H170V0Z" />
    </svg>
    """
  end

  attr :content, :string
  attr :user_initials, :string, default: "BOT AI"
  attr :index, :integer

  def chat_message(assigns) do
    ~H"""
    <div class="justify-start items-start inline-flex w-full">
      <div class="self-stretch justify-start items-start gap-1.5 flex w-full">
        <div class="flex-col justify-start items-start flex overflow-hidden">
          <div
            :if={@user_initials == "BOT AI"}
            class="w-8 h-8 rounded-full justify-center items-center flex"
          >
            <div class="w-10 h-10 bg-[url('/images/ng23/footer_dot_ai.png')] bg-cover bg-center">
            </div>
          </div>
          <div
            :if={@user_initials != "BOT AI"}
            class="w-7 h-7 mr-1 rounded-full justify-center items-center flex text-white bg-[#2080F0] dark:bg-[#DF8028]"
          >
            <div class="text-[14px] uppercase">
              <%= @user_initials %>
            </div>
          </div>
        </div>
        <div class={[
          "grow shrink basis-0 p-3 rounded-xl shadow justify-start items-start gap-6 flex bg-opacity-10 dark:bg-opacity-100",
          if(@user_initials == "BOT AI",
            do: "bg-gray-400 dark:bg-gray-600",
            else: "bg-gray-500 dark:bg-gray-700"
          )
        ]}>
          <div class="grow shrink basis-0 p-2 flex-col justify-start items-start gap-6 inline-flex">
            <div class="self-stretch justify-start items-start gap-3 inline-flex">
              <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-3 inline-flex">
                <div
                  id={"message_#{@index}_content"}
                  class="self-stretch dark:text-white text-sm font-normal font-['Open Sans'] tracking-tight"
                >
                  <%= raw(@content) %>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="w-7 h-7 justify-center items-center flex">
          <div
            :if={@user_initials == "BOT AI"}
            class="grow shrink basis-0 self-stretch px-3 py-2 rounded-lg justify-center items-center gap-1.5 inline-flex"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 16 16"
              fill="none"
              class="cursor-pointer hover:opacity-50"
              phx-hook="CopyListener"
              id={"copy_button_#{@index}"}
              data-clipboard-target={"#message_#{@index}_content"}
              data-animate="true"
              role="copy button"
            >
              <path
                d="M11.667 5.99984H12.0003C12.7367 5.99984 13.3337 6.59679 13.3337 7.33317V11.9998C13.3337 12.7362 12.7367 13.3332 12.0003 13.3332H7.33366C6.59728 13.3332 6.00033 12.7362 6.00033 11.9998V11.6665M4.00033 9.99984H8.66699C9.40337 9.99984 10.0003 9.40288 10.0003 8.6665V3.99984C10.0003 3.26346 9.40337 2.6665 8.66699 2.6665H4.00033C3.26395 2.6665 2.66699 3.26346 2.66699 3.99984V8.6665C2.66699 9.40288 3.26395 9.99984 4.00033 9.99984Z"
                class="dark:stroke-white stroke-zinc-800"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp to_initials(%{name: name}) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
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
