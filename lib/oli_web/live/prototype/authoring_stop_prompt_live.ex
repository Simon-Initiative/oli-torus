defmodule OliWeb.Prototype.AuthoringStopPromptLive do
  use OliWeb, :live_view

  require Logger

  alias Oli.GenAI.Dialogue.{Server, Configuration}
  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.FeatureConfig
  alias Oli.Prototype.SpeechToText
  alias Oli.Prototype.VideoAnnotationCache

  # Hardcoded video sources for testing
  # Cute otters video (default Torus fallback)
  @youtube_video_id "FCrtYilXpk0"
  # Example HTML5 video URL
  @html5_video_url "/path/to/video.mp4"

  # Learning Objectives for College-Level Rhetoric Course
  @learning_objectives [
    %{
      "id" => "rhetorical_strategies",
      "title" => "Recognize rhetorical strategies (ethos, pathos, logos)",
      "description" =>
        "Identify credibility appeals (ethos), emotional appeals (pathos), and logical reasoning (logos).",
      "category" => "rhetorical_analysis"
    },
    %{
      "id" => "persuasive_techniques",
      "title" => "Analyze persuasive techniques in media",
      "description" =>
        "Spot use of repetition, loaded language, imagery, statistics, or celebrity endorsement.",
      "category" => "media_analysis"
    },
    %{
      "id" => "bias_detection",
      "title" => "Detect bias and framing",
      "description" =>
        "Recognize how word choice, camera angles, or selective editing influence perception.",
      "category" => "critical_analysis"
    },
    %{
      "id" => "perspective_comparison",
      "title" => "Compare perspectives across media sources",
      "description" =>
        "Identify similarities/differences in how different outlets frame the same topic.",
      "category" => "comparative_analysis"
    },
    %{
      "id" => "source_credibility",
      "title" => "Evaluate credibility of sources",
      "description" =>
        "Judge reliability based on evidence, transparency, and author reputation.",
      "category" => "source_evaluation"
    }
  ]

  def mount(_params, _session, socket) do
    # Sort annotations by time for proper handling

    socket =
      socket
      |> assign(:annotations, [])
      |> assign(:pending_annotations, [])
      |> assign(:youtube_video_id, @youtube_video_id)
      |> assign(:html5_video_url, @html5_video_url)
      # Default to YouTube
      |> assign(:player_type, :youtube)
      |> assign(:objective_hits, [])
      |> assign(:learning_objectives, @learning_objectives)
      # Video preparation
      |> assign(:video_url, "")
      |> assign(:preparing_video, false)
      |> assign(:preparation_status, nil)
      # Speech to text
      |> assign(:transcribing, false)
      |> assign(:transcription_progress, [])
      |> assign(:transcription_status, nil)
      |> assign(:transcriptions, [])
      |> assign(:current_video_id, nil)
      # Question generation
      |> assign(:generating_questions, false)
      |> assign(:received_annotations, "")

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

  def handle_event("switch_player", %{"type" => type}, socket) do
    player_type = String.to_atom(type)
    socket = assign(socket, :player_type, player_type)
    {:noreply, socket}
  end

  def handle_event("prepare_video", %{"video_url" => video_url}, socket) do
    if video_url != "" do
      socket =
        socket
        |> assign(:preparing_video, true)
        |> assign(:video_url, video_url)
        |> assign(:preparation_status, "Preparing video...")

      # Start video preparation in a task
      pid = self()

      Task.start(fn ->
        prepare_video_async(video_url, pid)
      end)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Please enter a YouTube URL")}
    end
  end

  def handle_event("update_video_url", %{"video_url" => video_url}, socket) do
    {:noreply, assign(socket, :video_url, video_url)}
  end

  def handle_event("video_time_update", %{"time" => _time}, socket) do
    # Ignore time updates in authoring interface - no timer functionality needed
    {:noreply, socket}
  end

  def handle_event("generate_questions", _params, socket) do
    if length(socket.assigns.transcriptions) > 0 do
      socket =
        socket
        |> assign(:generating_questions, true)

      # Start question generation in a task
      pid = self()
      transcriptions = socket.assigns.transcriptions

      Task.start(fn ->
        generate_questions_async(transcriptions, pid)
      end)

      {:noreply, socket}
    else
      {:noreply,
       put_flash(socket, :error, "No transcriptions available to generate questions from")}
    end
  end

  # Handle dialogue server responses for question generation only
  def handle_info({:dialogue_server, {:tokens_received, content}}, socket) do
    # This is for question generation - accumulate annotations
    updated_annotations = socket.assigns.received_annotations <> content
    {:noreply, assign(socket, :received_annotations, updated_annotations)}
  end

  def handle_info({:dialogue_server, {:tokens_finished}}, socket) do
    # This is for question generation - parse JSON and set annotations
    case Jason.decode(socket.assigns.received_annotations) do
      {:ok, parsed_questions} ->
        # Filter out questions with invalid learning objective references
        {valid_questions, filtered_count} = filter_valid_questions(parsed_questions)
        # Sort questions by time for proper handling
        sorted_questions = Enum.sort_by(valid_questions, & &1["time"])

        # Store in cache for delivery interface to access
        :ok =
          VideoAnnotationCache.store_annotations(
            socket.assigns.current_video_id || @youtube_video_id,
            sorted_questions,
            socket.assigns.transcriptions,
            socket.assigns.video_url
          )

        socket =
          socket
          |> assign(:generating_questions, false)
          |> assign(:received_annotations, "")
          |> assign(:annotations, sorted_questions)
          |> assign(:pending_annotations, sorted_questions)
          |> put_flash(
            :info,
            if filtered_count > 0 do
              "Generated #{length(sorted_questions)} valid questions successfully! (Filtered out #{filtered_count} questions with invalid learning objective references)"
            else
              "Generated #{length(sorted_questions)} questions successfully!"
            end
          )

        IO.inspect(sorted_questions)

        {:noreply, socket}

      {:error, parse_error} ->
        IO.inspect(parse_error, label: "Failed to parse annotations JSON")

        socket =
          socket
          |> assign(:generating_questions, false)
          |> assign(:received_annotations, "")
          |> put_flash(:error, "Failed to parse generated questions: #{inspect(parse_error)}")

        {:noreply, socket}
    end
  end

  def handle_info({:dialogue_server, {:error, reason}}, socket) do
    Logger.error("Dialogue server error: #{inspect(reason)}")

    # This is for question generation
    socket =
      socket
      |> assign(:generating_questions, false)
      |> put_flash(:error, "Question generation failed: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_info({:dialogue_server, _other}, socket) do
    # Handle other dialogue server messages if needed
    IO.inspect("OTHER")
    {:noreply, socket}
  end

  def handle_info({:video_preparation, :success, audio_file}, socket) do
    # Extract video ID from filename (remove .wav extension)
    video_id = String.replace(audio_file, ".wav", "")

    # Subscribe to transcription updates
    Phoenix.PubSub.subscribe(Oli.PubSub, "prototype_transcription:#{video_id}")

    # Start transcription
    Task.start(fn ->
      SpeechToText.transcribe(video_id, audio_file)
    end)

    socket =
      socket
      |> assign(:preparing_video, false)
      |> assign(:preparation_status, "Video prepared successfully! Starting transcription...")
      |> assign(:transcribing, true)
      |> assign(:transcription_status, "Starting transcription...")
      |> assign(:current_video_id, video_id)
      |> assign(:transcription_progress, [])
      |> put_flash(:info, "Video audio extracted to #{audio_file}. Starting transcription...")

    {:noreply, socket}
  end

  def handle_info({:video_preparation, :error, reason}, socket) do
    socket =
      socket
      |> assign(:preparing_video, false)
      |> assign(:preparation_status, "Preparation failed: #{reason}")
      |> put_flash(:error, "Video preparation failed: #{reason}")

    {:noreply, socket}
  end

  def handle_info({:transcription_chunk, chunk}, socket) do
    progress = socket.assigns.transcription_progress ++ [chunk]

    socket =
      socket
      |> assign(:transcription_progress, progress)
      |> assign(:transcription_status, "Transcribing... (#{length(progress)} segments processed)")

    {:noreply, socket}
  end

  def handle_info({:transcription_complete, {:ok, transcriptions}}, socket) do
    socket =
      socket
      |> assign(:transcribing, false)
      |> assign(:transcriptions, transcriptions)
      |> assign(
        :transcription_status,
        "Transcription completed! #{length(transcriptions)} segments processed."
      )
      |> put_flash(:info, "Transcription completed successfully!")

    {:noreply, socket}
  end

  def handle_info({:transcription_complete, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:transcribing, false)
      |> assign(:transcription_status, "Transcription failed: #{reason}")
      |> put_flash(:error, "Transcription failed: #{reason}")

    {:noreply, socket}
  end

  def handle_info({:question_generation, :success, questions}, socket) do
    # Parse the JSON response and update annotations
    case Jason.decode(questions) do
      {:ok, parsed_questions} ->
        # Filter out questions with invalid learning objective references
        {valid_questions, filtered_count} = filter_valid_questions(parsed_questions)
        # Sort questions by time for proper handling
        sorted_questions = Enum.sort_by(valid_questions, & &1["time"])

        # Store in cache for delivery interface to access
        :ok =
          VideoAnnotationCache.store_annotations(
            socket.assigns.current_video_id || @youtube_video_id,
            sorted_questions,
            socket.assigns.transcriptions,
            socket.assigns.video_url
          )

        socket =
          socket
          |> assign(:generating_questions, false)
          |> assign(:annotations, sorted_questions)
          |> assign(:pending_annotations, sorted_questions)
          |> put_flash(
            :info,
            if filtered_count > 0 do
              "Generated #{length(sorted_questions)} valid questions successfully! (Filtered out #{filtered_count} questions with invalid learning objective references)"
            else
              "Generated #{length(sorted_questions)} questions successfully!"
            end
          )

        {:noreply, socket}

      {:error, parse_error} ->
        IO.inspect(parse_error, label: "Failed to parse questions JSON")

        socket =
          socket
          |> assign(:generating_questions, false)
          |> put_flash(:error, "Failed to parse generated questions: #{inspect(parse_error)}")

        {:noreply, socket}
    end
  end

  def handle_info({:question_generation, :error, reason}, socket) do
    socket =
      socket
      |> assign(:generating_questions, false)
      |> put_flash(:error, "Question generation failed: #{reason}")

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
    </style>

    <div class="prototype-fullscreen min-h-screen text-netflix-primary">
      <div id="stop-prompts" class="lg:container lg:mx-auto p-4 md:p-6">
        <div class="mb-8">
          <h1 class="text-4xl font-bold mb-3 text-white">Video Authoring Studio</h1>
          <p class="text-netflix-secondary text-lg">
            Extract audio, generate transcripts, and create AI-powered learning questions
          </p>
        </div>
        
    <!-- Learning Objectives -->
        <div class="mb-6 netflix-card p-6">
          <h2 class="text-xl font-semibold mb-4 text-white flex items-center">
            <i class="fas fa-graduation-cap text-netflix-secondary mr-3"></i> Course: College Rhetoric
          </h2>
          <div class="space-y-3">
            <%= for objective <- @learning_objectives do %>
              <div class="flex items-start bg-netflix-dark p-4 rounded-lg border-l-4 border-red-600">
                <span class="w-2 h-2 bg-red-600 rounded-full mr-3 mt-2 flex-shrink-0"></span>
                <div class={[
                  "flex-1",
                  if(objective["optional"], do: "opacity-75")
                ]}>
                  <div class="font-semibold text-white mb-1">
                    {objective["title"]}{if objective["optional"], do: " (optional)"}
                  </div>
                  <div class="text-sm text-netflix-secondary">{objective["description"]}</div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Video Transcription Area -->
        <div class="mb-6 netflix-card p-6">
          <h2 class="text-xl font-semibold mb-4 text-white flex items-center">
            <i class="fab fa-youtube text-red-500 mr-3"></i> YouTube Video Transcription
          </h2>
          <p class="text-netflix-secondary mb-6">
            Enter a YouTube URL for audio speech-to-text transcription
          </p>

          <form phx-submit="prepare_video" class="space-y-4">
            <div class="flex space-x-3">
              <input
                type="url"
                name="video_url"
                value={@video_url}
                placeholder="https://www.youtube.com/watch?v=..."
                phx-change="update_video_url"
                class="flex-1 px-4 py-3 netflix-input text-lg"
                disabled={@preparing_video}
              />
              <button
                type="submit"
                class="px-8 py-3 netflix-button text-lg font-semibold flex items-center"
                disabled={@preparing_video || @video_url == ""}
              >
                <%= if @preparing_video do %>
                  <i class="fas fa-spinner fa-spin mr-2"></i> Extracting Audio...
                <% else %>
                  <i class="fas fa-microphone mr-2"></i> Transcribe Video
                <% end %>
              </button>
            </div>
          </form>

          <%= if @preparation_status do %>
            <div class="mt-4 p-4 bg-netflix-dark rounded-lg border-l-4 border-blue-500">
              <div class="flex items-center text-netflix-secondary">
                <i class="fas fa-info-circle mr-3 text-blue-500"></i>
                <span>{@preparation_status}</span>
              </div>
            </div>
          <% end %>

          <%= if @transcribing || @transcription_status do %>
            <div class="mt-4 p-4 bg-netflix-dark rounded-lg border-l-4 border-green-500">
              <div class="flex items-center justify-between text-netflix-secondary mb-3">
                <div class="flex items-center">
                  <%= if @transcribing do %>
                    <i class="fas fa-spinner fa-spin mr-3 text-green-500"></i>
                  <% else %>
                    <i class="fas fa-check-circle mr-3 text-green-500"></i>
                  <% end %>
                  <span>{@transcription_status || "Transcribing speech-to-text..."}</span>
                </div>
                <%= if @transcribing do %>
                  <span class="text-xs bg-green-500/20 text-green-400 px-3 py-1 rounded-full">
                    {length(@transcription_progress)} segments
                  </span>
                <% end %>
              </div>

              <%= if length(@transcription_progress) > 0 do %>
                <div class="max-h-32 overflow-y-auto space-y-2">
                  <%= for chunk <- Enum.take(@transcription_progress, -5) do %>
                    <div class="flex items-start space-x-3 bg-black/30 p-3 rounded">
                      <span class="text-xs bg-green-500/20 text-green-400 px-2 py-1 rounded font-mono">
                        {chunk.start} - {chunk.end}
                      </span>
                      <span class="flex-1 text-netflix-secondary">{chunk.text}</span>
                    </div>
                  <% end %>
                  <%= if length(@transcription_progress) > 5 do %>
                    <div class="text-center text-netflix-muted italic">
                      ... and {length(@transcription_progress) - 5} more segments
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if length(@transcriptions) > 0 do %>
            <div class="mt-4 p-4 bg-netflix-dark rounded-lg">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white">
                  Video Transcription ({length(@transcriptions)} segments)
                </h3>
              </div>

              <button
                phx-click="generate_questions"
                class="w-full px-6 py-4 netflix-button text-lg font-semibold flex items-center justify-center"
                disabled={@generating_questions}
              >
                <%= if @generating_questions do %>
                  <i class="fas fa-brain mr-3 animate-pulse"></i> Generating Questions...
                <% else %>
                  <i class="fas fa-magic mr-3"></i> Generate Questions
                <% end %>
              </button>
            </div>
          <% end %>
        </div>
        
    <!-- Generated Questions Display -->
        <div class="netflix-card">
          <%= if length(@annotations) > 0 do %>
            <div class="p-6">
              <h3 class="text-2xl font-semibold text-white mb-6 flex items-center">
                <i class="fas fa-question-circle text-netflix-secondary mr-3"></i>
                Generated Questions ({length(@annotations)})
              </h3>
              <div class="space-y-6">
                <%= for {annotation, index} <- Enum.with_index(@annotations) do %>
                  <div class="bg-netflix-dark p-6 rounded-lg border-l-4 border-red-600">
                    <div class="flex items-start justify-between mb-4">
                      <div class="flex items-center">
                        <span class="inline-flex items-center justify-center w-10 h-10 bg-red-600 text-white text-lg font-bold rounded-full mr-4">
                          {index + 1}
                        </span>
                        <span class="text-netflix-muted font-mono">
                          {annotation["time"]}s
                        </span>
                      </div>
                    </div>
                    
    <!-- Learning Objective Reference -->
                    <%= if annotation["ref_id"] do %>
                      <% learning_objective = find_learning_objective(annotation["ref_id"]) %>
                      <%= if learning_objective do %>
                        <div class="mb-4 p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg">
                          <div class="flex items-start">
                            <i class="fas fa-target text-blue-400 mr-3 mt-1"></i>
                            <div>
                              <div class="text-sm font-semibold text-blue-400 mb-1">
                                Learning Objective: {learning_objective["title"]}
                              </div>
                              <div class="text-sm text-netflix-secondary">
                                {learning_objective["description"]}
                              </div>
                            </div>
                          </div>
                        </div>
                      <% else %>
                        <div class="mb-4 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
                          <div class="flex items-center">
                            <i class="fas fa-exclamation-triangle text-red-400 mr-3"></i>
                            <span class="text-red-400">
                              Unknown Learning Objective: {annotation["ref_id"]}
                            </span>
                          </div>
                        </div>
                      <% end %>
                    <% else %>
                      <div class="mb-4 p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
                        <div class="flex items-center">
                          <i class="fas fa-exclamation-circle text-yellow-400 mr-3"></i>
                          <span class="text-yellow-400">
                            No Learning Objective Reference
                          </span>
                        </div>
                      </div>
                    <% end %>

                    <h4 class="text-lg font-semibold text-white mb-3">
                      {annotation["prompt"]}
                    </h4>
                    <%= if annotation["rubric"] && annotation["rubric"] != "" do %>
                      <div class="bg-black/30 p-4 rounded-lg border-l-4 border-netflix-secondary">
                        <div class="text-sm font-semibold text-netflix-secondary mb-2">Rubric:</div>
                        <div class="text-netflix-secondary">{annotation["rubric"]}</div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="p-12 text-center">
              <div class="text-netflix-muted mb-6">
                <i class="fas fa-question-circle text-6xl"></i>
              </div>
              <h3 class="text-2xl font-semibold text-white mb-3">
                Generated Questions
              </h3>
              <p class="text-netflix-secondary text-lg">
                Generated questions will appear here after processing video transcripts.
              </p>
            </div>
          <% end %>
        </div>
        
    <!-- Debug Information -->
        <div class="mt-6 netflix-card p-6">
          <h4 class="text-lg font-semibold mb-4 text-white flex items-center">
            <i class="fas fa-chart-line mr-3 text-netflix-secondary"></i> Debug Information
          </h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-netflix-dark p-4 rounded-lg">
              <div class="text-netflix-muted text-sm mb-1">Player Type</div>
              <div class="text-white font-semibold">{@player_type}</div>
            </div>
            <div class="bg-netflix-dark p-4 rounded-lg">
              <div class="text-netflix-muted text-sm mb-1">Questions Generated</div>
              <div class="text-white font-semibold">{length(@annotations)}</div>
            </div>
            <div class="bg-netflix-dark p-4 rounded-lg">
              <div class="text-netflix-muted text-sm mb-1">Transcripts</div>
              <div class="text-white font-semibold">{length(@transcriptions)}</div>
            </div>
          </div>
          <%= if length(@objective_hits) > 0 do %>
            <div class="mt-6 pt-4 border-t border-gray-600">
              <h5 class="text-netflix-secondary font-medium mb-3">
                Objective Timeline
              </h5>
              <div class="space-y-2 max-h-32 overflow-y-auto">
                <%= for hit <- @objective_hits do %>
                  <div class="flex items-center text-sm bg-netflix-dark p-2 rounded">
                    <span class="bg-red-600 text-white px-2 py-1 rounded text-xs font-mono mr-3">
                      {hit.objective_id}
                    </span>
                    <span class="text-netflix-secondary">at {hit.timestamp}s</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Student View Button -->
        <%= if length(@annotations) > 0 do %>
          <div class="mt-8 text-center">
            <button
              onclick="window.open('/prototype/delivery_stop_prompts', '_blank')"
              class="px-12 py-4 netflix-button text-xl font-bold flex items-center justify-center mx-auto transform transition-transform hover:scale-105"
            >
              <i class="fas fa-play mr-3"></i> Open Student View
            </button>
            <p class="text-netflix-muted mt-3">
              Opens the student delivery experience in a new tab
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Find learning objective by ref_id
  defp find_learning_objective(ref_id) do
    Enum.find(@learning_objectives, fn lo -> lo["id"] == ref_id end)
  end

  # Filter out questions with invalid learning objective references
  defp filter_valid_questions(questions) do
    {valid_questions, invalid_questions} =
      Enum.split_with(questions, fn question ->
        case question["ref_id"] do
          # Allow questions without ref_id (they'll show warning in UI)
          nil -> true
          # Only keep if LO exists
          ref_id -> find_learning_objective(ref_id) != nil
        end
      end)

    # Log filtered questions for debugging
    if length(invalid_questions) > 0 do
      require Logger

      Logger.warning(
        "Filtered out #{length(invalid_questions)} questions with invalid learning objective references"
      )

      Enum.each(invalid_questions, fn question ->
        Logger.warning(
          "Filtered question with invalid ref_id '#{question["ref_id"]}': #{question["prompt"]}"
        )
      end)
    end

    {valid_questions, length(invalid_questions)}
  end

  # Get a service config for GenAI - simplified for prototype
  defp get_service_config do
    try do
      # Try to get a default GenAI service config for question generation
      # Using section_id = nil to get default/global config
      service_config = FeatureConfig.load_for(1, :student_dialogue)
      {:ok, service_config}
    rescue
      error ->
        Logger.warning("No GenAI service configured for prototype: #{inspect(error)}")
        {:error, "GenAI service not available"}
    end
  end

  # Async video preparation function
  defp prepare_video_async(video_url, pid) do
    try do
      # Extract video ID from URL if it's a YouTube URL
      video_id = extract_video_id(video_url)

      # Construct the yt-dlp command
      yt_dlp_path = "/Users/darren/Downloads/yt/yt-dlp_macos"
      command = "#{yt_dlp_path} -x --audio-format wav -o \"%(id)s.%(ext)s\" \"#{video_url}\""

      Logger.info("Executing yt-dlp command: #{command}")

      case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
        {output, 0} ->
          # Success - check if the audio file was actually created
          audio_file = "#{video_id}.wav"
          Logger.info("yt-dlp command completed: #{output}")

          if File.exists?(audio_file) do
            send(pid, {:video_preparation, :success, audio_file})
          else
            send(
              pid,
              {:video_preparation, :error,
               "Audio file was not created despite successful command"}
            )
          end

        {error_output, exit_code} ->
          Logger.error("yt-dlp failed with exit code #{exit_code}: #{error_output}")
          send(pid, {:video_preparation, :error, "Command failed: #{error_output}"})
      end
    rescue
      error ->
        Logger.error("Error in video preparation: #{inspect(error)}")
        send(pid, {:video_preparation, :error, "Unexpected error: #{inspect(error)}"})
    end
  end

  # Extract video ID from YouTube URL
  defp extract_video_id(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        url
        |> URI.parse()
        |> Map.get(:query, "")
        |> URI.decode_query()
        |> Map.get("v", "unknown")

      String.contains?(url, "youtu.be/") ->
        url
        |> String.split("/")
        |> List.last()
        |> String.split("?")
        |> List.first()

      true ->
        # Fallback - try to extract anything that looks like a video ID
        case Regex.run(~r/([a-zA-Z0-9_-]{11})/, url) do
          [_, video_id] -> video_id
          _ -> "unknown"
        end
    end
  end

  # Generate questions from transcripts using AI dialogue
  defp generate_questions_async(transcriptions, pid) do
    try do
      # Debug: inspect the transcript structure
      IO.inspect(transcriptions |> Enum.take(1), label: "Sample transcript structure")

      # Format transcripts for the prompt
      formatted_transcripts =
        transcriptions
        |> Enum.map(fn t ->
          # Handle different possible time formats
          {start_seconds, end_seconds} =
            case {t.start, t.end} do
              {%Time{} = start_time, %Time{} = end_time} ->
                # Convert Time struct to total seconds
                start_secs = start_time.hour * 3600 + start_time.minute * 60 + start_time.second
                end_secs = end_time.hour * 3600 + end_time.minute * 60 + end_time.second
                {start_secs, end_secs}

              {start_time, end_time} when is_binary(start_time) and is_binary(end_time) ->
                # Parse time strings if they're in format like "00:02:59"
                {parse_time_string(start_time), parse_time_string(end_time)}

              _ ->
                IO.inspect({t.start, t.end}, label: "Unexpected time format")
                {0, 0}
            end

          "#{start_seconds}s - #{end_seconds}s: #{t.text}"
        end)
        |> Enum.join("\n")

      # Create learning objectives JSON for the prompt
      learning_objectives_json = Jason.encode!(@learning_objectives)

      # Create the system prompt
      system_prompt = """
      You are creating interactive learning questions for a college-level rhetoric course.

      LEARNING OBJECTIVES:
      #{learning_objectives_json}

      TRANSCRIPT:
      #{formatted_transcripts}

      TASK:
      1. Find places in the transcript that directly map to the learning objectives above
      2. Create 3-4 STOP POINTS with questions that target specific learning objectives
      3. Each question MUST reference a learning objective by its "id" using the "ref_id" attribute
      4. Questions should be thought-provoking and appropriate for college rhetoric students
      5. Include rubrics that align with the referenced learning objective

      RETURN THIS AS A LIST OF JSON OBJECTS of the form:
      [
        {
          "time": 45,
          "type": "stop_prompt",
          "ref_id": "rhetorical_strategies",
          "prompt": "Identify the rhetorical strategy being used in this segment. Is this an appeal to ethos, pathos, or logos?",
          "rubric": "Student should correctly identify the rhetorical appeal and provide evidence from the transcript to support their analysis."
        },
        {
          "time": 120,
          "type": "stop_prompt",
          "ref_id": "bias_detection",
          "prompt": "What word choices or framing techniques do you notice that might influence the audience's perception?",
          "rubric": "Student should identify specific language choices and explain how they create bias or frame the message."
        }
      ]

      IMPORTANT:
      - Return ONLY the JSON array, no other text or formatting
      - Every question MUST have a "ref_id" that matches one of the learning objective IDs
      - Focus on segments of transcript that actually relate to rhetoric, persuasion, media analysis, etc.
      """

      # Get a service config for GenAI
      case get_service_config() do
        {:ok, service_config} ->
          # Create initial system message
          system_message = %Message{
            role: :system,
            content: system_prompt
          }

          # Create configuration for question generation
          config =
            Configuration.new(
              service_config,
              [system_message],
              [],
              pid
            )

          # Start the dialogue server
          case Server.new(config) do
            {:ok, server} ->
              # Send a user message to trigger the response
              Server.engage(server, %Message{role: :user, content: "Generate the questions now."})

              # Wait for the complete response (synchronously for this use case)
              receive_complete_response(pid, "")

            {:error, reason} ->
              send(
                pid,
                {:question_generation, :error,
                 "Failed to start dialogue server: #{inspect(reason)}"}
              )
          end

        {:error, reason} ->
          send(
            pid,
            {:question_generation, :error, "GenAI service not available: #{inspect(reason)}"}
          )
      end
    rescue
      error ->
        Logger.error("Error in question generation: #{inspect(error)}")
        send(pid, {:question_generation, :error, "Unexpected error: #{inspect(error)}"})
    end
  end

  # Helper to receive complete response from dialogue server
  defp receive_complete_response(pid, accumulated_content) do
    receive do
      {:dialogue_server, {:tokens_received, content}} ->
        receive_complete_response(pid, accumulated_content <> content)

      {:dialogue_server, {:tokens_finished}} ->
        send(pid, {:question_generation, :success, accumulated_content})

      {:dialogue_server, {:error, reason}} ->
        send(pid, {:question_generation, :error, reason})
    after
      # 30 second timeout
      30_000 ->
        send(pid, {:question_generation, :error, "Response timeout"})
    end
  end

  # Helper to parse time strings like "00:02:59" to seconds
  defp parse_time_string(time_string) do
    case String.split(time_string, ":") do
      [hours, minutes, seconds] ->
        String.to_integer(hours) * 3600 +
          String.to_integer(minutes) * 60 +
          String.to_integer(seconds)

      [minutes, seconds] ->
        String.to_integer(minutes) * 60 +
          String.to_integer(seconds)

      _ ->
        0
    end
  rescue
    _ -> 0
  end
end
