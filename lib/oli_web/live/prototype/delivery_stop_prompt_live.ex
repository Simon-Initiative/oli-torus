defmodule OliWeb.Prototype.DeliveryStopPromptLive do
  use OliWeb, :live_view

  require Logger

  alias Oli.GenAI.Dialogue.{Server, Configuration}
  alias Oli.GenAI.Completions.{Message, Function}
  alias Oli.GenAI.FeatureConfig
  alias Oli.Prototype.VideoAnnotationCache

  # Hardcoded video sources for testing
  # Cute otters video (default Torus fallback)

  # Example HTML5 video URL
  @html5_video_url "/path/to/video.mp4"

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:html5_video_url, @html5_video_url)
      # Default to YouTube
      |> assign(:player_type, :youtube)
      |> assign(:dialogue_active, false)
      |> assign(:current_prompt, nil)
      |> assign(:dialogue_server, nil)
      |> assign(:dialogue_messages, [])
      |> assign(:current_message, "")
      |> assign(:streaming, false)
      |> assign(:conversation_mode, false)
      |> assign(:awaiting_initial_answer, false)
      |> assign(:feedback_given, false)
      |> assign(:objective_hits, [])
      |> assign(:annotations, [])
      |> assign(:pending_annotations, [])
      |> assign(:current_video_time, 0.0)
      |> assign(:next_prompt, nil)
      |> assign(:next_prompt_countdown, nil)
      |> assign(:cached_video_url, nil)
      |> assign(:transcripts, [])

    # Try to load annotations and transcripts from cache
    socket = load_cached_data(socket)

    {:ok, socket}
  end

  def handle_event("hit_objective", %{"id" => objective_id}, socket) do
    timestamp = System.system_time(:second)
    hit = %{objective_id: objective_id, timestamp: timestamp}

    objective_hits = [hit | socket.assigns.objective_hits]

    # Log the objective hit (for future analytics)
    IO.inspect(hit, label: "Objective Hit")

    socket = assign(socket, :objective_hits, objective_hits)
    {:noreply, socket}
  end

  def handle_event("resume_video", _params, socket) do
    # Step 1: Fade out the dialogue first
    socket = push_event(socket, "ui:fade-out", %{})

    # Step 2: After 400ms, clear dialogue state and resume video, then fade back in
    Process.send_after(self(), :complete_resume_video, 400)

    {:noreply, socket}
  end

  def handle_event("continue_as_conversation", _params, socket) do
    socket = assign(socket, :conversation_mode, true)
    {:noreply, socket}
  end

  def handle_event("feedback_helpful", _params, socket) do
    socket = assign(socket, :feedback_given, true)
    {:noreply, socket}
  end

  def handle_event("feedback_not_helpful", _params, socket) do
    socket = assign(socket, :feedback_given, true)
    {:noreply, socket}
  end

  def handle_event("video_time_update", %{"time" => time}, socket) do
    socket =
      socket
      |> assign(:current_video_time, time)
      |> check_for_prompts(time)

    {:noreply, socket}
  end

  def handle_event("switch_player", %{"type" => type}, socket) do
    player_type = String.to_atom(type)
    socket = assign(socket, :player_type, player_type)
    {:noreply, socket}
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    case socket.assigns.dialogue_server do
      nil ->
        {:noreply, put_flash(socket, :error, "No active dialogue session")}

      server ->
        # Add user message to messages
        user_message = %{role: "user", content: message}
        messages = socket.assigns.dialogue_messages ++ [user_message]

        # Send to dialogue server async in Task
        Task.start(fn ->
          Server.engage(server, %Message{role: :user, content: message})
        end)

        socket =
          socket
          |> assign(:dialogue_messages, messages)
          |> assign(:streaming, true)
          |> assign(:current_message, "")
          |> assign(:awaiting_initial_answer, false)

        {:noreply, socket}
    end
  end

  def handle_event("send_message", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("trigger_prompt", %{"prompt" => prompt}, socket) do
    socket = start_dialogue_prompt(socket, %{"prompt" => prompt})
    {:noreply, socket}
  end

  # Handle dialogue server responses
  def handle_info({:dialogue_server, {:tokens_received, content}}, socket) do
    # This is for student dialogue - update the streaming message
    updated_message = socket.assigns.current_message <> content
    {:noreply, assign(socket, :current_message, updated_message)}
  end

  def handle_info({:dialogue_server, {:tokens_finished}}, socket) do
    # This is for student dialogue - add completed message
    assistant_message = %{role: "assistant", content: socket.assigns.current_message}
    messages = socket.assigns.dialogue_messages ++ [assistant_message]

    socket =
      socket
      |> assign(:dialogue_messages, messages)
      |> assign(:current_message, "")
      |> assign(:streaming, false)

    {:noreply, socket}
  end

  def handle_info({:dialogue_server, {:error, reason}}, socket) do
    Logger.error("Dialogue server error: #{inspect(reason)}")
    socket = put_flash(socket, :error, "Dialogue error occurred")
    {:noreply, socket}
  end

  def handle_info(
        {:dialogue_server, {:function_called, "cueTo", %{"time" => time_in_seconds}}},
        socket
      ) do
    # Handle cueTo function call from dialogue - seek the video
    socket = push_event(socket, "seek_video", %{time: time_in_seconds})
    {:noreply, socket}
  end

  def handle_info({:dialogue_server, _other}, socket) do
    # Handle other dialogue server messages if needed
    IO.inspect("OTHER")
    {:noreply, socket}
  end

  def handle_info({:delayed_prompt, prompt}, socket) do
    socket = start_dialogue_prompt(socket, prompt)
    {:noreply, socket}
  end

  def handle_info({:complete_dialogue_activation, annotation, server}, socket) do
    socket =
      socket
      |> assign(:dialogue_active, true)
      |> assign(:current_prompt, annotation["prompt"])
      |> assign(:dialogue_server, server)
      |> assign(:conversation_mode, false)
      |> assign(:awaiting_initial_answer, true)
      |> assign(:feedback_given, false)
      |> push_event("pause_video", %{})
      |> push_event("ui:fade-in", %{})
      |> tap(fn socket ->
        require Logger
        Logger.info("Dialogue activated for video #{socket.assigns.current_video_id}")
      end)

    {:noreply, socket}
  end

  def handle_info(:complete_resume_video, socket) do
    socket =
      socket
      |> assign(:dialogue_active, false)
      |> assign(:current_prompt, nil)
      |> assign(:dialogue_messages, [])
      |> assign(:current_message, "")
      |> assign(:streaming, false)
      |> assign(:conversation_mode, false)
      |> assign(:awaiting_initial_answer, false)
      |> assign(:feedback_given, false)
      |> assign(:dialogue_server, nil)
      |> push_event("resume_video", %{})
      |> push_event("ui:fade-in", %{})

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <style>
      /* Hide any header/footer elements for prototype */
      body { margin: 0; padding: 0; background: #141414; }
      .prototype-fullscreen {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        z-index: 9999;
        overflow-y: auto;
        background: #141414;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
      }
      .netflix-card {
        background: #222;
        border-radius: 8px;
        border: none;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
        transition: transform 0.2s ease, box-shadow 0.2s ease;
      }
      .netflix-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
      }
      .netflix-button {
        background: #e50914;
        border: none;
        color: white;
        border-radius: 4px;
        font-weight: 600;
        transition: all 0.2s ease;
        box-shadow: 0 2px 8px rgba(229, 9, 20, 0.3);
      }
      .netflix-button:hover {
        background: #f6121d;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(229, 9, 20, 0.4);
      }
      .netflix-button:disabled {
        background: #666;
        color: #999;
        transform: none;
        box-shadow: none;
      }
      .netflix-input {
        background: #333;
        border: 1px solid #555;
        color: #fff;
        border-radius: 4px;
        transition: border-color 0.2s ease;
      }
      .netflix-input:focus {
        border-color: #e50914;
        outline: none;
        box-shadow: 0 0 0 2px rgba(229, 9, 20, 0.2);
      }
      .text-netflix-primary {
        color: #fff;
      }
      .text-netflix-secondary {
        color: #b3b3b3;
      }
      .text-netflix-muted {
        color: #808080;
      }
      .bg-netflix-dark {
        background: #181818;
      }
      .bg-netflix-darker {
        background: #141414;
      }
      .video-container {
        background: #000;
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
      }
      .dialogue-message-user {
        background: #e50914;
        color: white;
        border-radius: 16px 16px 4px 16px;
      }
      .dialogue-message-ai {
        background: #333;
        color: #fff;
        border-radius: 16px 16px 16px 4px;
      }
      /* Ensure proper height for flex layout */
      .prototype-fullscreen {
        height: 100vh;
      }
      #stop-prompts {
        height: calc(100vh - 100px); /* Account for header height */
        min-height: 600px; /* Ensure minimum height */
        flex-direction: row !important; /* Force horizontal layout */
      }

      /* Fade transition system */
      .fadeable {
        transition: opacity 500ms ease;
      }
      .is-fading {
        opacity: 0;
        pointer-events: none;
      }
      .video-dim {
        transition: opacity 300ms ease;
      }
      .video-dim.is-dimmed {
        opacity: 0.7;
      }

      /* Ensure side-by-side layout */
      .video-area {
        flex: 0 0 66.666667%; /* 2/3 width, don't shrink */
        max-width: 66.666667%;
        min-height: 100%;
      }

      .dialogue-side {
        flex: 0 0 33.333333%; /* 1/3 width, don't shrink */
        max-width: 33.333333%;
        min-height: 100%;
      }
    </style>

    <div class="prototype-fullscreen min-h-screen text-netflix-primary">
      <!-- Header -->
      <div class="p-4 md:p-6 border-b border-gray-800">
        <h1 class="text-3xl font-bold text-white">Video Learning Experience</h1>
        <p class="text-netflix-secondary">
          Interactive video with AI-powered dialogue prompts
        </p>
      </div>

    <!-- Main Content Area: Video + Dialogue Side by Side -->
      <div id="stop-prompts" class="flex h-full">
        <!-- Video Area (2/3 width) -->
        <div class="video-area flex flex-col">
          <!-- Video Player Container -->
          <div class="flex-1 p-4 video-dim" id="video-container">
            <div class="netflix-card overflow-hidden h-full">
              <%= if @player_type == :youtube and @current_video_id != nil do %>
                <div
                  id={@current_video_id}
                  phx-hook="YouTubePlayer"
                  phx-update="ignore"
                  data-video-id={@current_video_id}
                  class="w-full h-full video-container"
                >
                  <div class="w-full h-full bg-black flex items-center justify-center text-white">
                    <div class="text-center">
                      <i class="fas fa-play-circle text-6xl mb-4 text-netflix-secondary"></i>
                      <div class="text-xl font-semibold mb-2">Loading Video...</div>
                      <div class="text-sm text-netflix-muted">Video ID: {@current_video_id}</div>
                    </div>
                  </div>
                </div>
              <% end %>

    <!-- Video Info -->
              <%= if @cached_video_url do %>
                <div class="p-3 bg-netflix-dark border-t border-gray-700">
                  <div class="flex items-center text-sm text-netflix-secondary">
                    <i class="fas fa-link mr-2"></i>
                    <span class="truncate">{@cached_video_url}</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

    <!-- Dialogue Area (1/3 width) -->
        <div class="dialogue-side flex flex-col border-l border-gray-800">
          <div class="flex-1 netflix-card rounded-none border-l-0 fadeable dialogue-area"
               id="dialogue-container"
               phx-hook="DialogueFader">
            <%= if @dialogue_active do %>
              <div class="p-4 h-full flex flex-col">
                <!-- Active Dialogue Header -->
                <div class="mb-4 pb-4 border-b border-gray-700 flex-shrink-0">
                  <div class="flex items-center mb-2">
                    <div class="w-2 h-2 bg-red-600 rounded-full mr-2 animate-pulse"></div>
                    <h3 class="text-lg font-semibold text-white">Active</h3>
                  </div>
                  <div class="bg-red-600/10 border border-red-600/30 rounded p-3">
                    <div class="text-red-400 font-semibold text-xs mb-1">Question:</div>
                    <div class="text-white text-sm leading-tight">{@current_prompt}</div>
                  </div>
                </div>

    <!-- Dialogue Messages -->
                <div class="flex-1 overflow-y-auto mb-4 space-y-3" id="dialogue-messages">
                  <%= for {message, index} <- Enum.with_index(@dialogue_messages) do %>
                    <%= if message.role != "system" do %>
                      <div class={[
                        "flex",
                        if(message.role == "user", do: "justify-end", else: "justify-start")
                      ]}>
                        <div class={[
                          "max-w-[85%] p-3 text-sm",
                          if(message.role == "user",
                            do: "dialogue-message-user",
                            else: "dialogue-message-ai"
                          )
                        ]}>
                          <div class="text-xs font-medium mb-1 opacity-75">
                            {if message.role == "user",
                              do: "You",
                              else: if(@conversation_mode, do: "AI", else: "Feedback")}
                          </div>
                          <div class="leading-relaxed">{message.content}</div>

                          <!-- Feedback buttons for first assistant message (feedback) -->
                          <%= if message.role == "assistant" and index == 1 and not @conversation_mode and not @feedback_given do %>
                            <div class="mt-3 pt-2 border-t border-gray-600 flex items-center space-x-2">
                              <span class="text-xs text-netflix-muted">Was this helpful?</span>
                              <button
                                phx-click="feedback_helpful"
                                class="text-green-400 hover:text-green-300 transition-colors p-1"
                                title="Helpful"
                              >
                                <i class="fas fa-smile text-sm"></i>
                              </button>
                              <button
                                phx-click="feedback_not_helpful"
                                class="text-red-400 hover:text-red-300 transition-colors p-1"
                                title="Not helpful"
                              >
                                <i class="fas fa-frown text-sm"></i>
                              </button>
                            </div>
                          <% end %>

                          <!-- Thank you message after feedback -->
                          <%= if message.role == "assistant" and index == 1 and not @conversation_mode and @feedback_given do %>
                            <div class="mt-3 pt-2 border-t border-gray-600">
                              <span class="text-xs text-green-400">Thanks for helping us improve!</span>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  <% end %>

                  <%= if @streaming and @current_message != "" do %>
                    <div class="flex justify-start">
                      <div class="max-w-[85%] p-3 dialogue-message-ai text-sm">
                        <div class="text-xs font-medium mb-1 opacity-75">
                          {if @conversation_mode, do: "AI", else: "Feedback"}
                        </div>
                        <div class="leading-relaxed">
                          {@current_message}<span class="animate-pulse">|</span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

    <!-- Action Area -->
                <div class="flex-shrink-0 space-y-3">
                  <%= cond do %>
                    <% @awaiting_initial_answer -> %>
                      <!-- Initial Answer Phase: Show input for student answer -->
                      <form phx-submit="send_message">
                        <div class="space-y-2">
                          <input
                            type="text"
                            name="message"
                            placeholder="Type your answer..."
                            class="w-full px-3 py-2 netflix-input text-sm"
                            disabled={@streaming}
                          />
                          <button
                            type="submit"
                            class="w-full px-4 py-2 netflix-button font-semibold text-sm disabled:opacity-50"
                            disabled={@streaming}
                          >
                            <i class="fas fa-paper-plane mr-1"></i>
                            {if @streaming, do: "Submitting...", else: "Submit Answer"}
                          </button>
                        </div>
                      </form>
                    <% @streaming -> %>
                      <!-- Streaming Phase: Just show streaming indicator -->
                      <div class="text-center text-netflix-secondary text-sm">
                        <i class="fas fa-spinner fa-spin mr-2"></i> Getting feedback...
                      </div>
                    <% @conversation_mode -> %>
                      <!-- Conversation Mode: Show input form for additional questions -->
                      <form phx-submit="send_message">
                        <div class="flex space-x-2">
                          <input
                            type="text"
                            name="message"
                            placeholder="Ask a follow-up question..."
                            class="flex-1 px-3 py-2 netflix-input text-sm"
                          />
                          <button
                            type="submit"
                            class="px-4 py-2 netflix-button font-semibold text-sm"
                          >
                            <i class="fas fa-paper-plane mr-1"></i> Send
                          </button>
                        </div>
                      </form>
                      <button
                        type="button"
                        phx-click="resume_video"
                        class="w-full px-4 py-2 bg-gray-600 hover:bg-gray-500 text-white rounded font-semibold flex items-center justify-center text-sm transition-colors"
                      >
                        <i class="fas fa-play mr-2"></i> Continue Video
                      </button>
                    <% true -> %>
                      <!-- Feedback Complete: Show two action buttons -->
                      <div class="space-y-2">
                        <button
                          type="button"
                          phx-click="resume_video"
                          class="w-full px-4 py-3 netflix-button font-semibold flex items-center justify-center text-sm"
                        >
                          <i class="fas fa-play mr-2"></i> Continue Video
                        </button>
                        <button
                          type="button"
                          phx-click="continue_as_conversation"
                          class="w-full px-4 py-2 bg-gray-600 hover:bg-gray-500 text-white rounded font-semibold flex items-center justify-center text-sm transition-colors"
                        >
                          <i class="fas fa-comments mr-2"></i> Ask Question
                        </button>
                      </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="p-4 h-full flex flex-col">
                <!-- Default dialogue state -->
                <div class="flex-1 flex flex-col items-center justify-center text-center">
                  <div class="text-netflix-muted mb-4">
                    <i class="fas fa-comments text-4xl"></i>
                  </div>
                  <h3 class="text-lg font-semibold text-white mb-2">
                    Learning Dialogue
                  </h3>
                  <p class="text-netflix-secondary text-sm mb-3 leading-relaxed">
                    Interactive prompts will appear here during video playback.
                  </p>
                  <%= if length(@annotations) == 0 do %>
                    <p class="text-netflix-muted text-xs">
                      No annotations loaded.
                    </p>
                  <% else %>
                    <div class="inline-flex items-center bg-green-600/20 text-green-400 px-3 py-1 rounded-full text-xs mb-4">
                      <i class="fas fa-check-circle mr-1"></i>
                      {length(@annotations)} prompts ready
                    </div>
                  <% end %>

                  <%= if @next_prompt_countdown && @next_prompt_countdown > 0 do %>
                    <div class="mt-4 pt-4 border-t border-gray-700 w-full">
                      <div class="text-center">
                        <p class="text-netflix-secondary text-xs mb-1">Next question in</p>
                        <div class="text-lg font-semibold text-white mb-1">
                          {@next_prompt_countdown} seconds
                        </div>
                        <p class="text-netflix-muted text-xs leading-tight">
                          "{String.slice(@next_prompt["prompt"], 0, 50)}{if String.length(
                                                                              @next_prompt["prompt"]
                                                                            ) > 50,
                                                                            do: "..."}"
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Check if current video time should trigger any prompts
  defp check_for_prompts(socket, current_time) do
    # Skip if dialogue is already active
    if socket.assigns.dialogue_active do
      socket
    else
      # Check for prompts that should be triggered at current time (within 1 second tolerance)
      prompt_to_trigger =
        Enum.find(socket.assigns.pending_annotations, fn annotation ->
          abs(annotation["time"] - current_time) <= 1.0
        end)

      socket =
        case prompt_to_trigger do
          nil ->
            socket

          annotation ->
            # Remove this annotation from pending and trigger it
            remaining_annotations =
              Enum.reject(socket.assigns.pending_annotations, fn a -> a == annotation end)

            socket
            |> assign(:pending_annotations, remaining_annotations)
            |> start_dialogue_prompt(annotation)
        end

      # Update next prompt countdown
      update_next_prompt_countdown(socket, current_time)
    end
  end

  # Update countdown display for next prompt
  defp update_next_prompt_countdown(socket, current_time) do
    next_prompt =
      socket.assigns.pending_annotations
      |> Enum.filter(fn annotation -> annotation["time"] > current_time end)
      |> Enum.min_by(fn annotation -> annotation["time"] end, fn -> nil end)

    case next_prompt do
      nil ->
        socket
        |> assign(:next_prompt, nil)
        |> assign(:next_prompt_countdown, nil)

      prompt ->
        countdown = max(0, round(prompt["time"] - current_time))

        socket
        |> assign(:next_prompt, prompt)
        |> assign(:next_prompt_countdown, countdown)
    end
  end

  # Load cached annotations and transcripts from GenServer
  defp load_cached_data(socket) do
    case VideoAnnotationCache.get_cached_video() do
      {:ok, annotations, transcripts, video_url} ->
        # Sort annotations by time for proper handling
        sorted_annotations = Enum.sort_by(annotations, & &1["time"])

        IO.inspect(video_url, label: "Cached Video URL")

        # Extract video ID from cached URL or use fallback
        current_video_id =
          case extract_video_id_from_url(video_url) do
            nil -> nil
            id -> id
          end

        socket
        |> assign(:annotations, sorted_annotations)
        |> assign(:pending_annotations, sorted_annotations)
        |> assign(:transcripts, transcripts)
        |> assign(:cached_video_url, video_url)
        |> assign(:current_video_id, current_video_id)

      {:error, _reason} ->
        # No cached data available yet
        socket
        |> assign(:annotations, [])
        |> assign(:pending_annotations, [])
        |> assign(:transcripts, [])
        |> assign(:cached_video_url, nil)
        |> assign(:current_video_id, nil)
    end
  end

  # Create a GenAI dialogue server for the prompt
  defp start_dialogue(prompt, rubric, socket) do
    try do
      # Get a service config for GenAI (using default/fallback for prototype)
      case get_service_config() do
        {:ok, service_config} ->
          # Get transcripts from socket assigns
          transcripts = socket.assigns.transcripts || []
          transcripts_json = Jason.encode!(transcripts)

          # Create initial system message
          system_message = %Message{
            role: :system,
            content:
              "The student is watching a video with the following transcript #{transcripts_json} and has been prompted with this question: [#{prompt}]. The rubric for evaluating this is [#{rubric}]Please provide feedback to the student based on the prompt, the rubric and their response. Limit your feedback to at most two sentences."
          }

          # Define available functions for the dialogue
          functions = [
            Function.new(
              "cueTo",
              "Seek the video to a specific timestamp when the student asks about a particular part of the video. Use this to help students navigate to relevant sections.",
              %{
                "type" => "object",
                "properties" => %{
                  "time" => %{
                    "type" => "number",
                    "description" => "Time in seconds to seek to in the video"
                  }
                },
                "required" => ["time"]
              }
            )
            |> Map.put("full_name", "Elixir.OliWeb.Prototype.DeliveryStopPromptLive.cueTo")
          ]

          # Create configuration
          config =
            Configuration.new(
              service_config,
              [system_message],
              functions,
              self()
            )

          # Start the dialogue server
          Server.new(config)

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Error starting dialogue: #{inspect(error)}")
        {:error, "Failed to initialize dialogue system"}
    end
  end

  # Start dialogue with a prompt and pause video
  defp start_dialogue_prompt(socket, annotation) do
    case start_dialogue(annotation["prompt"], annotation["rubric"], socket) do
      {:ok, server} ->
        # Step 1: Fade out the UI first
        socket = push_event(socket, "ui:fade-out", %{})

        # Step 2: After 500ms, update state and pause video, then fade back in
        Process.send_after(self(), {:complete_dialogue_activation, annotation, server}, 500)

        socket

      {:error, reason} ->
        put_flash(socket, :error, "Failed to start dialogue: #{inspect(reason)}")
    end
  end

  # Extract video ID from YouTube URL
  defp extract_video_id_from_url(nil), do: nil

  defp extract_video_id_from_url(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        url
        |> URI.parse()
        |> Map.get(:query, "")
        |> URI.decode_query()
        |> Map.get("v")

      String.contains?(url, "youtu.be/") ->
        url
        |> String.split("youtu.be/")
        |> List.last()
        |> String.split("?")
        |> List.first()

      true ->
        nil
    end
  end

  # Get a service config for GenAI - simplified for prototype
  defp get_service_config do
    try do
      # Try to get a default GenAI service config for student dialogue feature
      # Using section_id = nil to get default/global config
      service_config = FeatureConfig.load_for(1, :student_dialogue)
      {:ok, service_config}
    rescue
      error ->
        Logger.warning("No GenAI service configured for prototype: #{inspect(error)}")
        {:error, "GenAI service not available"}
    end
  end

  def cueTo(%{"time" => time_in_seconds} = _arguments) when is_number(time_in_seconds) do
    Logger.info("cueTo function called with time: #{time_in_seconds}")

    # The dialogue server will handle sending the message to the LiveView
    # We just return the result here
    "Video cued to #{time_in_seconds} seconds"
  end

  def cueTo(%{"time" => time_string} = _arguments) when is_binary(time_string) do
    case Float.parse(time_string) do
      {time_in_seconds, _} ->
        cueTo(%{"time" => time_in_seconds})

      :error ->
        "Invalid time format. Please provide time as a number in seconds."
    end
  end

  def cueTo(_arguments) do
    "Invalid arguments. Please provide time in seconds as a number."
  end
end
