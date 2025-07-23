defmodule OliWeb.Dialogue.WindowLive do

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use OliWeb, :verified_routes
  use Phoenix.HTML

  require Logger

  import Ecto.Query, warn: false
  import Phoenix.Component
  import OliWeb.Components.Common

  alias Phoenix.PubSub
  alias Phoenix.LiveView.JS

  alias Oli.Delivery.Sections
  alias Oli.Conversation.Triggers
  alias Oli.GenAI.Dialogue.{Server, Configuration}
  alias Oli.GenAI.Completions.Message
  alias OliWeb.Components
  alias OliWeb.Dialogue.UserInput

  defp realize_prompt_template(nil, _), do: ""

  defp realize_prompt_template(template, bindings) do
    keyword_list = Map.to_list(bindings)
    EEx.eval_string(template, keyword_list)
  end

  # Gets the page prompt template and gathers all pieces of information necessary
  # to realize that template into the completed page prompt
  defp build_page_prompt(section, project, revision_id, user_id) do
    {:ok, page_content} = Oli.Converstation.PageContentCache.get(revision_id)

    bindings = %{
      current_user_id: user_id,
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
  defp build_course_prompt(section, project, user_id) do
    bindings = %{
      current_user_id: user_id,
      section_id: section.id,
      course_title: project.title,
      course_description: project.description,
      page_content:
        "Use only the available functions and their outputs to answer the question. Avoid drawing on external or assumed information."
    }

    realize_prompt_template(section.page_prompt_template, bindings)
  end

  defp init_dialogue_server(section, project, revision_id, user_id) do

    system_prompt = if revision_id do
      build_page_prompt(section, project, revision_id, user_id)
    else
      build_course_prompt(section, project, user_id)
    end

    configuration = %Configuration{
      service_config: Oli.GenAIFeatureConfig.load_for(section.id, :student_dialogue),
      messages: [Message.new(:system, system_prompt)],
      functions: OliWeb.Dialogue.StudentFunctions.functions(),
      reply_to_pid: self()
    }

    Server.new(configuration)

  end

  def mount(
        _params,
        %{"current_user_id" => current_user_id, "section_slug" => section_slug} = session,
        socket
      ) do
    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)
    resource_id = session["resource_id"]

    PubSub.subscribe(Oli.PubSub, "trigger:#{current_user_id}:#{section.id}:#{resource_id}")

    if Sections.assistant_enabled?(section) do

      project = Oli.Authoring.Course.get_project!(section.base_project_id)

      case init_dialogue_server(section, project, session["revision_id"], current_user_id) do

        {:ok, dialogue_server} ->
          {:ok,
            assign(socket,
              enabled: true,
              minimized: true,
              dialogue: dialogue_server,
              form: to_form(UserInput.changeset(%UserInput{}, %{content: ""})),
              messages: [],
              streaming: false,
              allow_submission?: true,
              trigger_queue: [],
              active_message: nil,
              title: "Dot",
              current_user: Oli.Accounts.get_user!(current_user_id),
              height: 500,
              width: 400,
              section: section,
              resource_id: session["resource_id"],
              is_page: session["is_page"] == true || false
            )}

        {:error, reason} ->
          Logger.error("Failed to initialize dialogue server: #{inspect(reason)}")
          {:ok, assign(socket, enabled: false)}
      end
    else
      {:ok, assign(socket, enabled: false)}
    end
  end

  def mount(
        _params,
        _session,
        socket
      ) do
    {:ok, assign(socket, enabled: false)}
  end

  def render(assigns) do
    ~H"""
    <div
      :if={@enabled}
      class={[
        "fixed z-[10000] lg:bottom-0 right-0 ml-auto",
        if(@is_page, do: "bottom-20", else: "bottom-0")
      ]}
    >
      <.conversation
        current_user={@current_user}
        form={@form}
        allow_submission?={@allow_submission?}
        streaming={@streaming}
        messages={@messages}
        active_message={@active_message}
        height={@height}
        width={@width}
      />
      <.collapsed_bot is_page={@is_page} />
    </div>
    """
  end

  attr :is_page, :boolean, default: false

  def collapsed_bot(assigns) do
    ~H"""
    <div
      id="ai_bot_collapsed"
      phx-hook="WakeUpDot"
      class={["lg:w-[170px] h-[74px] relative ml-auto", if(@is_page, do: "w-[80px]", else: "")]}
    >
      <button
        phx-click={
          JS.hide(to: "#ai_bot_collapsed")
          |> JS.show(
            to: "#ai_bot_conversation",
            transition:
              {"ease-out duration-200", "translate-x-full translate-y-full opacity-0",
               "translate-x-0 translate-y-0 opacity-100"}
          )
          |> JS.focus(to: "#ai_bot_input")
        }
        class="absolute right-[1px] cursor-pointer hover:scale-105"
        id="ai_bot_collapsed_button"
      >
        <.dot_icon size={:large} />
      </button>
      <.left_to_right_fade_in_icon is_page={@is_page} />
    </div>
    """
  end

  attr :current_user, :map
  attr :form, :map
  attr :allow_submission?, :boolean
  attr :streaming, :boolean
  attr :messages, :list
  attr :active_message, :any
  attr :height, :integer
  attr :width, :integer

  def conversation(assigns) do
    ~H"""
    <.focus_wrap
      id="ai_bot_conversation"
      class="hidden mb-1 mr-[6px]"
      phx-click-away={JS.dispatch("click", to: "#close_chat_button")}
      phx-window-keydown={JS.dispatch("click", to: "#close_chat_button")}
      phx-key="escape"
    >
      <div
        id="conversation_container"
        phx-hook="ResizeListener"
        style={"height: #{@height}px; width: #{@width}px;"}
        class="pb-6 shadow-lg bg-white dark:bg-[#0A0A17] rounded-3xl flex flex-col justify-between"
      >
        <div class="h-7 shrink-0 py-6 px-3 rounded-t-3xl flex items-center">
          <button
            id="resize_handle"
            class="flex items-center justify-center cursor-nw-resize rotate-90 opacity-60 dark:opacity-80 dark:hover:opacity-50 hover:opacity-100 hover:scale-105"
          >
            <.resize_icon />
          </button>
          <button
            id="close_chat_button"
            phx-click={
              JS.hide(
                to: "#ai_bot_conversation",
                transition:
                  {"ease-out duration-700", "translate-x-1/4 translate-y-1/4 opacity-100",
                   "translate-x-full translate-y-full opacity-0"}
              )
              |> JS.show(
                to: "#ai_bot_collapsed",
                transition:
                  {"ease-out duration-700 delay-1000",
                   "translate-x-full translate-y-full opacity-100",
                   "translate-x-3/4 translate-y-0 opacity-0"}
              )
            }
            class="flex items-center justify-center ml-auto cursor-pointer opacity-80 dark:opacity-100 dark:hover:opacity-80 hover:opacity-100 hover:scale-105"
          >
            <.close_icon />
          </button>
        </div>
        <.messages
          messages={@messages}
          streaming={@streaming}
          active_message={@active_message}
          user={@current_user}
        />
        <.message_input form={@form} allow_submission?={@allow_submission?} streaming={@streaming} />
      </div>
    </.focus_wrap>
    """
  end

  def resize_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 512 512">
      <path
        class="fill-black dark:fill-white"
        d="M344 0H488c13.3 0 24 10.7 24 24V168c0 9.7-5.8 18.5-14.8 22.2s-19.3 1.7-26.2-5.2l-39-39-87 87c-9.4 9.4-24.6 9.4-33.9 0l-32-32c-9.4-9.4-9.4-24.6 0-33.9l87-87L327 41c-6.9-6.9-8.9-17.2-5.2-26.2S334.3 0 344 0zM168 512H24c-13.3 0-24-10.7-24-24V344c0-9.7 5.8-18.5 14.8-22.2s19.3-1.7 26.2 5.2l39 39 87-87c9.4-9.4 24.6-9.4 33.9 0l32 32c9.4 9.4 9.4 24.6 0 33.9l-87 87 39 39c6.9 6.9 8.9 17.2 5.2 26.2s-12.5 14.8-22.2 14.8z"
      />
    </svg>
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

  def small_close_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none">
      <path
        d="M6.2248 18.8248L5.1748 17.7748L10.9498 11.9998L5.1748 6.2248L6.2248 5.1748L11.9998 10.9498L17.7748 5.1748L18.8248 6.2248L13.0498 11.9998L18.8248 17.7748L17.7748 18.8248L11.9998 13.0498L6.2248 18.8248Z"
        class="fill-gray-400"
      />
    </svg>
    """
  end

  # TODO: the recording message feature is not yet developed,
  # that is why we are hiding the mic icon for now
  def mic_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="25"
      viewBox="0 0 24 25"
      fill="none"
      role="mic button"
      class="hidden cursor-pointer hover:scale-105 hover:opacity-50"
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

  attr :size, :atom, values: [:small, :medium, :large], default: :medium

  def dot_icon(assigns) do
    ~H"""
    <div class={"#{dot_size_class(@size)} relative"}>
      <img
        class="animate-[spin_40s_cubic-bezier(0.4,0,0.6,1)_infinite]"
        src={~p"/images/assistant/footer_dot_ai.png"}
      />
      <div class={"#{orb_size_class(@size)} absolute bottom-0 right-0 bg-zinc-300 rounded-full blur-[30px] animate-[pulse_6s_cubic-bezier(0.4,0,0.6,1)_infinite]"}>
      </div>
    </div>
    """
  end

  defp dot_size_class(:small), do: "w-[32px] h-[32px]"
  defp dot_size_class(:medium), do: "w-[56px] h-[56px]"
  defp dot_size_class(:large), do: "w-[72px] h-[72px]"

  defp orb_size_class(:small), do: "w-[24px] h-[24px]"
  defp orb_size_class(:medium), do: "w-[48px] h-[48px]"
  defp orb_size_class(:large), do: "w-[64px] h-[64px]"

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

  attr :is_page, :boolean, default: false

  def left_to_right_fade_in_icon(assigns) do
    ~H"""
    <svg
      class={["fill-black dark:opacity-100", if(@is_page, do: "hidden lg:block", else: "block")]}
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
          <div
            class="w-12 h-12 bg-cover bg-center"
            style="background-image: url('/images/assistant/footer_dot_ai.png');"
          >
          </div>
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
        "grow shrink basis-0 p-3 rounded-xl shadow justify-start items-start gap-6 flex bg-opacity-30 dark:bg-opacity-100",
        if(@user_initials == "BOT AI",
          do: "bg-gray-300 dark:bg-gray-600",
          else: "bg-gray-800 dark:bg-gray-800"
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

  attr :messages, :list
  attr :active_message, :any
  attr :streaming, :boolean
  attr :user, Oli.Accounts.User

  def messages(assigns) do
    ~H"""
    <div
      role="message container"
      id="message-container"
      class="overflow-y-auto pt-5"
      phx-hook="KeepScrollAtBottom"
    >
      <div class="flex flex-col justify-end items-center px-6 gap-1.5 min-h-full">
        <%= for {message, index} <- Enum.with_index(@messages, 1), message.role not in [:system, :function] do %>
          <Components.Delivery.Dialogue.chat_message
            index={index}
            content={message.content}
            user={if message.role == :assistant, do: :assistant, else: @user}
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
      phx-window-keydown={JS.dispatch("click", to: "#bot_submit_button")}
      phx-key="enter"
    >
      <div class="px-3 py-1.5 rounded-xl border border-black dark:border-white border-opacity-40 flex justify-start items-center w-full">
        <div class="rounded-xl justify-center items-center gap-3 flex">
          <div class="px-1.5 py-[3px] justify-center items-center flex">
            <.mic_icon />
          </div>
        </div>
        <div class="grow shrink basis-0 justify-start items-center gap-2 flex w-full">
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
          id="bot_submit_button"
          disabled={!@allow_submission?}
          class="w-[38px] h-[38px] ml-2 px-6 py-2 opacity-90 bg-blue-500 rounded-lg justify-center items-center gap-3 flex cursor-pointer hover:opacity-100 active:bg-blue-600"
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
      <Components.Delivery.Dialogue.chat_message
        index={0}
        content={@active_message}
        user={:assistant}
      />
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

    %{dialogue: dialogue, messages: messages} = socket.assigns

    message = Message.new(:user, content)
    messages = messages ++ [message]

    # This asynchronously engages the dialogue server with the new message
    Server.engage(dialogue, message)

    {:noreply, assign(socket, streaming: true, messages: messages, allow_submission?: false)}
  end

  def handle_event("resize", %{"height" => height, "width" => width}, socket) do
    {:noreply, assign(socket, height: height, width: width)}
  end

  def handle_info({:tokens_received, content}, socket) do
    active_message = "#{socket.assigns.active_message}#{content}"
    {:noreply, assign(socket, active_message: active_message)}
  end

  def handle_info({:tokens_finished}, socket) do

    message = Message.new(:assistant, Earmark.as_html!(socket.assigns.active_message))

    # Here we check if there are any triggers in the queue
    # and if so, we process the first one
    # and remove it from the queue
    case socket.assigns.trigger_queue do
      [] ->

        {:noreply,
          assign(socket,
            streaming: false,
            allow_submission?: true,
            active_message: nil,
            messages: socket.assigns.messages ++ [message]
          )}

      [trigger | rest] ->
        prompt = Oli.Conversation.Triggers.assemble_trigger_prompt(trigger)

        Server.engage(socket.assigns.dialogue, Message.new(:system, prompt))

        {:noreply,
          assign(socket,
            active_message: socket.assigns.active_message <> "\n\n",
            messages: socket.assigns.messages ++ [message],
            trigger_queue: rest
          )}
    end
  end

  def handle_info({:trigger, trigger}, socket) do
    Logger.info(
      "Handlng trigger for section #{socket.assigns.section.id}, resource #{socket.assigns.resource_id}, user #{socket.assigns.current_user.id}"
    )

    # If there is currently a trigger or direct student interaction
    # streaming, we must queue the trigger and process it after
    # the current one is finished
    case socket.assigns.streaming do
      true ->
        {:noreply,
         assign(socket,
           trigger_queue: socket.assigns.trigger_queue ++ [trigger]
         )}

      false ->

        prompt = Triggers.assemble_trigger_prompt(trigger)
        Server.engage(socket.assigns.dialogue, Message.new(:system, prompt))

        socket =
          push_event(socket, "wakeup-dot", %{
            to: "#ai_bot_collapsed"
          })

        {:noreply,
         assign(socket,
           streaming: true
         )}
    end
  end

  def handle_info(_item, socket) do
    {:noreply, socket}
  end

end
