defmodule OliWeb.Dialogue.WindowLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use OliWeb, :verified_routes
  use Phoenix.HTML
  import Ecto.Query, warn: false

  import Phoenix.Component
  import OliWeb.Components.Common

  alias Oli.Conversation.Dialogue
  alias OliWeb.Dialogue.UserInput
  alias Oli.Conversation.Message
  alias Phoenix.LiveView.JS

  defp realize_prompt_template(nil, _), do: ""

  defp realize_prompt_template(template, bindings) do
    keyword_list = Map.to_list(bindings)
    EEx.eval_string(template, keyword_list)
  end

  # Gets the page prompt template and gathers all pieces of information necessary
  # to realize that template into the completed page prompt
  defp build_page_prompt(
         %{
           "current_user_id" => current_user_id,
           "section_slug" => section_slug,
           "revision_id" => revision_id
         } = _session
       ) do
    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)
    project = Oli.Authoring.Course.get_project!(section.base_project_id)

    {:ok, page_content} = Oli.Converstation.PageContentCache.get(revision_id)

    bindings = %{
      current_user_id: current_user_id,
      section_id: section.id,
      page_content: page_content,
      course_title: project.title,
      course_description: project.description,
      # TODO: replace this with the actual topic
      topic: "Chemistry"
    }

    realize_prompt_template(section.page_prompt_template, bindings)
  end

  # TODO for other types of pages (Home, Learn, Discussions, etc) we should build a new template.
  # For now we just use the page prompt template to be able to render
  # the bot in those pages.
  defp build_course_prompt(
         %{
           "current_user_id" => current_user_id,
           "section_slug" => section_slug
         } = _session
       ) do
    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)
    project = Oli.Authoring.Course.get_project!(section.base_project_id)

    # TODO: use a different prompt template (and probably other bindings) for the course prompt
    bindings = %{
      current_user_id: current_user_id,
      section_id: section.id,
      course_title: project.title,
      page_content: "a page content",
      course_description: project.description,
      # TODO: replace this with the actual topic
      topic: "Chemistry"
    }

    realize_prompt_template(section.page_prompt_template, bindings)
  end

  defp build_dialogue(session, pid) do
    if session["revision_id"] do
      build_page_prompt(session)
    else
      build_course_prompt(session)
    end
    |> Dialogue.new(
      fn _d, type, chunk ->
        send(pid, {:reply_chunk, type, chunk})
      end,
      model: :largest_context
    )
  end

  def mount(
        _params,
        %{"current_user_id" => current_user_id} = session,
        socket
      ) do
    {:ok,
     assign(socket,
       minimized: true,
       dialogue: build_dialogue(session, self()),
       form: to_form(UserInput.changeset(%UserInput{}, %{content: ""})),
       streaming: false,
       allow_submission?: true,
       active_message: nil,
       function_call: nil,
       title: "Dot",
       current_user: Oli.Accounts.get_user!(current_user_id)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed z-[10000] w-full bottom-0 right-0 flex">
      <div class="ml-auto">
        <.conversation
          current_user={@current_user}
          form={@form}
          allow_submission?={@allow_submission?}
          streaming={@streaming}
          dialogue={@dialogue}
          active_message={@active_message}
        />
        <.collapsed_bot />
      </div>
    </div>
    """
  end

  def collapsed_bot(assigns) do
    ~H"""
    <div id="ai_bot_collapsed" class="w-[170px] h-[74px] relative ml-auto">
      <button
        phx-click={
          JS.hide(to: "#ai_bot_collapsed")
          |> JS.show(
            to: "#ai_bot_conversation",
            transition:
              {"ease-out duration-1000", "translate-x-full translate-y-full",
               "translate-x-0 translate-y-0"}
          )
          |> JS.focus(to: "#ai_bot_input")
          |> JS.add_class("overflow-hidden", to: "body")
        }
        class="absolute right-[1px] cursor-pointer hover:scale-105"
      >
        <img
          class="animate-[spin_40s_cubic-bezier(0.4,0,0.6,1)_infinite]"
          src={~p"/images/ng23/footer_dot_ai.png"}
        />
        <div class="w-[39.90px] h-[39.90px] absolute bottom-4 right-4 bg-zinc-300 rounded-full blur-[30px] animate-[pulse_3s_cubic-bezier(0.4,0,0.6,1)_infinite]">
        </div>
      </button>
      <.left_to_right_fade_in_icon />
    </div>
    """
  end

  attr :current_user, :map
  attr :form, :map
  attr :allow_submission?, :boolean
  attr :streaming, :boolean
  attr :dialogue, :list
  attr :active_message, :any

  def conversation(assigns) do
    ~H"""
    <.focus_wrap
      id="ai_bot_conversation"
      class="hidden mb-1 mr-[6px]"
      phx-click-away={JS.dispatch("click", to: "#close_chat_button")}
      phx-window-keydown={JS.dispatch("click", to: "#close_chat_button")}
      phx-key="escape"
    >
      <div class="w-[556px] h-[634px] pb-6 shadow-lg bg-white dark:bg-[#0A0A17] rounded-3xl flex flex-col justify-between">
        <div class="h-[45px] shrink-0 pr-3 rounded-t-3xl bg-slate-400 dark:bg-black flex items-center">
          <button
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
              |> JS.remove_class("overflow-hidden", to: "body")
            }
            class="flex items-center justify-center ml-auto cursor-pointer opacity-80 dark:opacity-100 dark:hover:opacity-80 hover:opacity-100 hover:scale-105"
          >
            <.close_icon />
          </button>
        </div>
        <.messages
          dialogue={@dialogue}
          streaming={@streaming}
          active_message={@active_message}
          user_initials={to_initials(@current_user)}
        />
        <.message_input form={@form} allow_submission?={@allow_submission?} streaming={@streaming} />
      </div>
    </.focus_wrap>
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
      <path
        class="fill-white dark:fill-black"
        d="M170 0H134C107 0 92.5 13 68.5 37C44.5 61 24.2752 74 0 74H170V0Z"
      />
    </svg>
    """
  end

  attr :content, :string
  attr :user_initials, :string, default: "BOT AI"
  attr :index, :integer

  def chat_message(assigns) do
    ~H"""
    <div class="flex gap-1.5 w-full">
      <div class="flex-col justify-start items-start flex">
        <div
          :if={@user_initials == "BOT AI"}
          class="-mt-1.5 w-11 h-11 rounded-full justify-center items-center flex"
        >
          <div class="w-12 h-12 bg-[url('/images/ng23/footer_dot_ai.png')] bg-cover bg-center"></div>
        </div>
        <div
          :if={@user_initials != "BOT AI"}
          class="w-7 h-7 ml-2 mr-2 rounded-full justify-center items-center flex text-white bg-[#2080F0] dark:bg-[#DF8028]"
        >
          <div class="text-[14px] uppercase">
            <%= @user_initials %>
          </div>
        </div>
      </div>
      <div class={[
        "grow shrink basis-0 p-3 rounded-xl shadow justify-start items-start gap-6 flex bg-opacity-10 dark:bg-opacity-100",
        if(@user_initials == "BOT AI",
          do: "bg-gray-500 dark:bg-gray-600",
          else: "bg-gray-900 dark:bg-gray-800"
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
      <div class="relative w-7 h-7 justify-center items-center flex">
        <div
          id={"confirmation_message_#{@index}"}
          class="absolute hidden text-xs top-6 left-1 dark:text-white"
        >
          copied!
        </div>
        <button
          :if={@user_initials == "BOT AI"}
          class="grow shrink basis-0 self-stretch px-3 py-2 rounded-lg justify-center items-center gap-1.5 inline-flex"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            class="cursor-pointer hover:opacity-50 dark:text-white"
            phx-hook="CopyListener"
            id={"copy_button_#{@index}"}
            data-clipboard-target={"#message_#{@index}_content"}
            data-confirmation-message-target={"#confirmation_message_#{@index}"}
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
        </button>
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

  attr :dialogue, :list
  attr :active_message, :any
  attr :streaming, :boolean
  attr :user_initials, :string

  def messages(assigns) do
    ~H"""
    <div
      role="message container"
      id="message-container"
      class="h-[500px] overflow-y-auto pt-5"
      phx-hook="KeepScrollAtBottom"
    >
      <div class="flex flex-col justify-end items-center px-6 gap-1.5 min-h-full">
        <%= for {message, index} <- Enum.with_index(@dialogue.rendered_messages, 1), message.role not in [:system, :function] do %>
          <.chat_message
            index={index}
            content={message.content}
            user_initials={if message.role == :assistant, do: "BOT AI", else: @user_initials}
          />
        <% end %>
        <.live_response :if={@streaming} active_message={@active_message} />
      </div>
    </div>
    """
  end

  attr :form, :map
  attr :allow_submission?, :boolean
  attr :streaming, :boolean

  def message_input(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-submit="update"
      id="ai_user_input_form"
      class="w-full mt-5 px-6"
      phx-hook="TextareaListener"
    >
      <div class="px-3 py-1.5 rounded-xl border border-black dark:border-white border-opacity-40 flex justify-start items-center gap-2 w-full">
        <div class="rounded-xl justify-center items-center gap-3 flex">
          <div class="px-1.5 py-[3px] justify-center items-center flex">
            <.mic_icon />
          </div>
        </div>
        <div class="grow shrink basis-0 justif-start items-center gap-2 flex w-full">
          <.input
            type="textarea"
            field={@form[:content]}
            class="h-[38px] w-full bg-transparent border-none dark:text-white text-sm font-normal font-['Open Sans'] tracking-tight focus:border-transparent focus:ring-0"
            disabled={@streaming}
            required={true}
            placeholder="How can I help?"
            id="ai_bot_input"
            data-grow="true"
            data-initial-height={40}
            onkeyup="resizeTextArea(this)"
          />
        </div>
        <button
          disabled={!@allow_submission?}
          class="w-[38px] h-[38px] px-6 py-2 opacity-60 bg-blue-800 rounded-lg justify-center items-center gap-3 flex cursor-pointer hover:opacity-50"
        >
          <div class="w-[25px] h-[25px] pl-[3.12px] pr-[2.08px] py-[4.17px] justify-center items-center flex">
            <.submit_icon />
          </div>
        </button>
      </div>
    </.form>
    """
  end

  attr :active_message, :any

  def live_response(assigns) do
    ~H"""
    <%= if is_nil(@active_message) do %>
      <svg
        class="fill-black dark:fill-white"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <style>
          .spinner_b2T7{animation:spinner_xe7Q .8s linear infinite}.spinner_YRVV{animation-delay:-.65s}.spinner_c9oY{animation-delay:-.5s}@keyframes spinner_xe7Q{93.75%,100%{r:3px}46.875%{r:.2px}}
        </style>
        <circle class="spinner_b2T7" cx="4" cy="12" r="3" />
        <circle class="spinner_b2T7 spinner_YRVV" cx="12" cy="12" r="3" /><circle
          class="spinner_b2T7 spinner_c9oY"
          cx="20"
          cy="12"
          r="3"
        />
      </svg>
    <% else %>
      <.chat_message index={0} content={@active_message} user_initials="BOT AI" />
    <% end %>
    """
  end

  def handle_event("minimize", _, socket) do
    {:noreply, assign(socket, minimized: true)}
  end

  def handle_event("restore", _, socket) do
    {:noreply, assign(socket, minimized: false)}
  end

  def handle_event("update", %{"user_input" => %{"content" => content}}, socket) do
    dialogue = Dialogue.add_message(socket.assigns.dialogue, Message.new(:user, content))

    pid = self()

    Task.async(fn ->
      Dialogue.engage(dialogue, :async)
      send(pid, {:reply_finished})
    end)

    {:noreply, assign(socket, streaming: true, dialogue: dialogue, allow_submission?: false)}
  end

  use Oli.Conversation.DialogueHandler
end
