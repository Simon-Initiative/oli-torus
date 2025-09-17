defmodule Oli.Conversation.DialogueHandler do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Oli.Conversation.PageTriggerReplyCache

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
            active_message = "#{socket.assigns.active_message}#{content}"

            {:noreply, assign(socket, active_message: active_message)}
        end
      end

      def handle_info({:summarization_finished, dialogue}, socket) do
        {:noreply, assign(socket, dialogue: dialogue, allow_submission?: true)}
      end

      def handle_info({:reply_finished}, socket) do
        %{
          function_call: function_call,
          dialogue: dialogue,
          resource_id: resource_id,
          current_user: current_user,
          section: section
        } = socket.assigns

        case function_call do
          nil ->
            message = Earmark.as_html!(socket.assigns.active_message)

            dialogue =
              Oli.Conversation.Dialogue.add_message(
                socket.assigns.dialogue,
                Oli.Conversation.Message.new(:assistant, message),
                current_user.id,
                resource_id,
                section.id
              )

            allow_submission? =
              if Oli.Conversation.Dialogue.should_summarize?(dialogue) do
                pid = self()

                Task.async(fn ->
                  dialogue =
                    Oli.Conversation.Dialogue.summarize(dialogue)

                  send(pid, {:summarization_finished, dialogue})
                end)

                false
              else
                true
              end

            # Cache the assistant reply for a page trigger if requested
            _ =
              case socket.assigns[:last_trigger_meta] do
                %{type: :page, revision_id: rid} when is_binary(socket.assigns.active_message) ->
                  PageTriggerReplyCache.put(rid, socket.assigns.active_message)
                _ ->
                  :ok
              end

            # Here we check if there are any triggers in the queue
            # and if so, we process the first one
            # and remove it from the queue
            case socket.assigns.trigger_queue do
              [] ->
                {:noreply,
                 assign(socket,
                   dialogue: dialogue,
                   streaming: false,
                   active_message: nil,
                   allow_submission?: allow_submission?,
                   last_trigger_meta: nil
                  )}

              [trigger | rest] ->
                prompt = Oli.Conversation.Triggers.assemble_trigger_prompt(trigger)

                dialogue =
                  Oli.Conversation.Dialogue.add_message(
                    socket.assigns.dialogue,
                    Oli.Conversation.Message.new(:system, prompt),
                    trigger.user_id,
                    trigger.resource_id,
                    trigger.section_id
                  )

                # If the queued trigger is a page trigger and revision_id is available,
                # consult the cache to possibly bypass the LLM call.
                case {trigger.trigger_type, socket.assigns[:revision_id]} do
                  {:page, rid} when not is_nil(rid) ->
                    case PageTriggerReplyCache.get(rid) do
                      {:hit, reply_text} ->
                        pid = self()

                        Task.async(fn ->
                          send(pid, {:reply_chunk, :content, reply_text})
                          send(pid, {:reply_finished})
                        end)

                        {:noreply,
                         assign(socket,
                           dialogue: dialogue,
                           active_message: socket.assigns.active_message <> "\n\n",
                           trigger_queue: rest,
                           last_trigger_meta: nil
                         )}

                      :miss ->
                        pid = self()

                        Task.async(fn ->
                          Oli.Conversation.Dialogue.engage(dialogue, :async)
                          send(pid, {:reply_finished})
                        end)

                        {:noreply,
                         assign(socket,
                           dialogue: dialogue,
                           active_message: socket.assigns.active_message <> "\n\n",
                           trigger_queue: rest,
                           last_trigger_meta: %{type: :page, revision_id: rid}
                         )}

                      {:error, _} ->
                        pid = self()

                        Task.async(fn ->
                          Oli.Conversation.Dialogue.engage(dialogue, :async)
                          send(pid, {:reply_finished})
                        end)

                        {:noreply,
                         assign(socket,
                           dialogue: dialogue,
                           active_message: socket.assigns.active_message <> "\n\n",
                           trigger_queue: rest,
                           last_trigger_meta: nil
                         )}
                    end

                  _ ->
                    pid = self()

                    Task.async(fn ->
                      Oli.Conversation.Dialogue.engage(dialogue, :async)
                      send(pid, {:reply_finished})
                    end)

                    {:noreply,
                     assign(socket,
                       dialogue: dialogue,
                       active_message: socket.assigns.active_message <> "\n\n",
                       trigger_queue: rest,
                       last_trigger_meta: nil
                     )}
                end
            end

          fc ->
            result = Oli.Conversation.Functions.call(fc["name"], Jason.decode!(fc["arguments"]))

            dialogue =
              Oli.Conversation.Dialogue.add_message(
                socket.assigns.dialogue,
                Oli.Conversation.Message.new(
                  :function,
                  result,
                  fc["name"]
                ),
                current_user.id,
                resource_id,
                section.id
              )

            pid = self()

            Task.async(fn ->
              Oli.Conversation.Dialogue.engage(dialogue, :async)
              send(pid, {:reply_finished})
            end)

            {:noreply,
             assign(socket,
               dialogue: dialogue,
               function_call: nil,
               last_trigger_meta: nil
             )}
        end
      end

      def handle_info(_, socket) do
        {:noreply, socket}
      end
    end
  end
end
