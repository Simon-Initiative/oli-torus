defmodule OliWeb.Dialogue.PlaygroundLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use Phoenix.HTML
  import Ecto.Query, warn: false

  alias Oli.Repo
  import Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Conversation.Dialogue
  alias OliWeb.Dialogue.UserInput
  alias Oli.Conversation.Message

  defp realize_prompt_template(nil, _), do: ""

  defp realize_prompt_template(template, bindings) do
    keyword_list = Map.to_list(bindings)
    EEx.eval_string(template, keyword_list)
  end

  # Gets the page prompt template and gathers all pieces of information necessary
  # to realize that template into the completed page prompt
  defp build_page_prompt(session) do
    %{
      "current_user_id" => current_user_id,
      "section_slug" => section_slug,
      "revision_id" => revision_id
    } = session

    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)
    project = Oli.Authoring.Course.get_project!(section.base_project_id)

    {:ok, page_content} = Oli.Converstation.PageContentCache.get(revision_id)

    bindings = %{
      current_user_id: current_user_id,
      section_id: section.id,
      page_content: page_content,
      course_title: project.title,
      course_description: project.description
    }

    realize_prompt_template(section.page_prompt_template, bindings)
  end

  def mount(
        _params,
        session,
        socket
      ) do
    pid = self()

    dialogue =
      build_page_prompt(session)
      |> Dialogue.new(
        fn _d, type, chunk ->
          send(pid, {:reply_chunk, type, chunk})
        end,
        model: :largest_context
      )

    {:ok,
     assign(socket,
       minimized: true,
       dialogue: dialogue,
       changeset: UserInput.changeset(%UserInput{}, %{content: ""}),
       streaming: false,
       allow_submission?: true,
       active_message: nil,
       function_call: nil,
       title: "Dialogue Playground"
     )}
  end

  defp size(true) do
    "width: 33.33%; height: 5%;"
  end

  defp size(false) do
    "width: 33.33%; height: 50%;"
  end

  defp window_style(minimized) do
    "#{size(minimized)} z-index: 10000; border-radius: 8px; margin-left: 5px; margin-right: 5px; position: fixed; bottom: 0; right: 0; overflow: auto; background-color: #fff; border: 1px solid #ccc; box-shadow: -2px -2px 10px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column;"
  end

  def render(assigns) do
    ~H"""
    <div style={window_style(@minimized)}>
      <div class="flex justify-between border-b-2 border-gray p-3">
        <div>Dot (prototype)</div>
        <div>
          <i phx-click="minimize" class="cursor-pointer fa-regular fa-window-minimize mr-2"></i>
          <i phx-click="restore" class="cursor-pointer fa-regular fa-window-restore"></i>
        </div>
      </div>

      <div style="flex: 1; overflow-y: auto; padding-left: 3px; padding-right: 4px;">
        <%= render_messages(assigns) %>
        <%= if @streaming do %>
          <%= render_live_response(assigns) %>
        <% end %>
      </div>

      <div style="background: #eee; padding: 5px;">
        <%= render_input(assigns) %>
      </div>
    </div>
    """
  end

  def render_messages(assigns) do
    ~H"""
    <div class="messages">
      <%= for message <- @dialogue.rendered_messages do %>
        <%= if message.role != :system and message.role != :function do %>
          <div class={styles(message.role)}>
            <%= raw(message.content) %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def render_input(assigns) do
    ~H"""
    <.form :let={f} for={@changeset} phx-submit="update">
      <div class="relative">
        <%= textarea(f, :content,
          class:
            "resize-none ml-2 w-95 p-2 w-full rounded-md border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-transparent",
          disabled: @streaming,
          required: true
        ) %>
        <div class="absolute inset-y-0 right-0 flex items-center">
          <button
            disabled={!@allow_submission?}
            class="h-full rounded-md border-0 bg-transparent py-0 px-2 text-gray-500 focus:ring-2 focus:ring-inset focus:ring-blue-500 sm:text-sm"
            type="submit"
          >
            <i class="fa-solid fa-arrow-right"></i>
          </button>
        </div>
      </div>
    </.form>
    """
  end

  def render_live_response(assigns) do
    ~H"""
    <div class={styles(:assistant)}>
      <%= if is_nil(@active_message) do %>
        <svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
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
        <%= @active_message %>
      <% end %>
    </div>
    """
  end

  defp styles(:assistant) do
    "bg-gray-100 rounded-xl p-3 mb-2"
  end

  defp styles(:user) do
    "bg-slate-100 rounded-xl p-3 mb-2"
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

  def handle_info({:reply_chunk, type, content}, socket) do
    case type do
      :function_call ->
        case socket.assigns.function_call do
          nil ->
            {:noreply, assign(socket, function_call: content)}

          fc ->
            updated =
              Map.keys(content)
              |> Enum.reduce(fc, fn key, acc ->
                case Map.get(acc, key) do
                  nil -> Map.put(acc, key, content[key])
                  current_value -> Map.put(acc, key, "#{current_value}#{content[key]}")
                end
              end)

            {:noreply, assign(socket, function_call: updated)}
        end

      :content ->
        {:noreply, assign(socket, active_message: "#{socket.assigns.active_message}#{content}")}
    end
  end

  def handle_info({:summarization_finished, dialogue}, socket) do
    {:noreply, assign(socket, dialogue: dialogue, allow_submission?: true)}
  end

  def handle_info({:reply_finished}, socket) do
    case socket.assigns.function_call do
      nil ->
        message = Earmark.as_html!(socket.assigns.active_message)
        dialogue = Dialogue.add_message(socket.assigns.dialogue, Message.new(:assistant, message))

        allow_submission? =
          if Dialogue.should_summarize?(dialogue) do
            pid = self()

            Task.async(fn ->
              dialogue = Dialogue.summarize(dialogue)
              send(pid, {:summarization_finished, dialogue})
            end)

            false
          else
            true
          end

        {:noreply,
         assign(socket,
           dialogue: dialogue,
           streaming: false,
           active_message: nil,
           allow_submission?: allow_submission?
         )}

      fc ->

        result = Oli.Conversation.Functions.call(fc["name"], Jason.decode!(fc["arguments"]))

        dialogue =
          Dialogue.add_message(
            socket.assigns.dialogue,
            Message.new(:function, result, fc["name"])
          )

        pid = self()

        Task.async(fn ->
          Dialogue.engage(dialogue, :async)
          send(pid, {:reply_finished})
        end)

        {:noreply, assign(socket, dialogue: dialogue, function_call: nil)}
    end
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end


end
