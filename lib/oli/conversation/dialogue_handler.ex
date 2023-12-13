defmodule Oli.Conversation.DialogueHandler do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
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
            {:noreply,
             assign(socket, active_message: "#{socket.assigns.active_message}#{content}")}
        end
      end

      def handle_info({:summarization_finished, dialogue}, socket) do
        {:noreply, assign(socket, dialogue: dialogue, allow_submission?: true)}
      end

      def handle_info({:reply_finished}, socket) do
        case socket.assigns.function_call do
          nil ->
            message = Earmark.as_html!(socket.assigns.active_message)

            dialogue =
              Oli.Conversation.Dialogue.add_message(
                socket.assigns.dialogue,
                Oli.Conversation.Message.new(:assistant, message)
              )

            allow_submission? =
              if Oli.Conversation.Dialogue.should_summarize?(dialogue) do
                pid = self()

                Task.async(fn ->
                  dialogue = Oli.Conversation.Dialogue.summarize(dialogue)
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
              Oli.Conversation.Dialogue.add_message(
                socket.assigns.dialogue,
                Oli.Conversation.Message.new(:function, result, fc["name"])
              )

            pid = self()

            Task.async(fn ->
              Oli.Conversation.Dialogue.engage(dialogue, :async)
              send(pid, {:reply_finished})
            end)

            {:noreply, assign(socket, dialogue: dialogue, function_call: nil)}
        end
      end

      def handle_info(_, socket) do
        {:noreply, socket}
      end
    end
  end
end
