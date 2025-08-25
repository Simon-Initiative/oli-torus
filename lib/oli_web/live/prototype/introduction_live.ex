defmodule OliWeb.Prototype.IntroductionLive do
  use OliWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("get_started", _params, socket) do
    {:noreply, redirect(socket, to: "/prototype/authoring_stop_prompts")}
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
      .text-netflix-primary {
        color: #fff;
      }
      .text-netflix-secondary {
        color: #b3b3b3;
      }
      .hero-gradient {
        background: linear-gradient(135deg, #141414 0%, #222 50%, #141414 100%);
      }
    </style>

    <div class="prototype-fullscreen min-h-screen text-netflix-primary">
      <div class="hero-gradient min-h-screen flex items-center justify-center p-6">
        <div class="max-w-4xl mx-auto text-center">
          <!-- Main Title -->
          <h1 class="text-5xl md:text-6xl font-bold mb-6 text-white">
            Torus AI Video Learning
          </h1>

          <!-- Subtitle -->
          <p class="text-xl md:text-2xl text-netflix-secondary mb-12 max-w-2xl mx-auto leading-relaxed">
            Transform any YouTube video into an interactive, native Torus activity with AI-generated questions that target course learning objectives
          </p>

          <!-- Feature Bullets -->
          <div class="mb-12 space-y-6 max-w-3xl mx-auto">
            <div class="flex items-start text-left space-x-4">
              <div class="flex-shrink-0 w-8 h-8 bg-red-600 rounded-full flex items-center justify-center mt-1">
                <i class="fas fa-puzzle-piece text-white text-sm"></i>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-white mb-2">Native Torus Integration</h3>
                <p class="text-netflix-secondary">
                  Can map cleanly to existing Torus activity and part models, leveraging the full attempt structure and delivery pipeline
                </p>
              </div>
            </div>

            <div class="flex items-start text-left space-x-4">
              <div class="flex-shrink-0 w-8 h-8 bg-red-600 rounded-full flex items-center justify-center mt-1">
                <i class="fas fa-bullseye text-white text-sm"></i>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-white mb-2">Automatic Learning Objective Detection</h3>
                <p class="text-netflix-secondary">
                  AI extracts transcripts and creates questions and attaches relevant learning objectives from your course
                </p>
              </div>
            </div>

            <div class="flex items-start text-left space-x-4">
              <div class="flex-shrink-0 w-8 h-8 bg-red-600 rounded-full flex items-center justify-center mt-1">
                <i class="fas fa-comments text-white text-sm"></i>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-white mb-2">Interactive Stop Prompts with AI Feedback</h3>
                <p class="text-netflix-secondary">
                  Videos pause at key moments for student responses, followed by personalized AI feedback and optional dialogue
                </p>
              </div>
            </div>

            <div class="flex items-start text-left space-x-4">
              <div class="flex-shrink-0 w-8 h-8 bg-red-600 rounded-full flex items-center justify-center mt-1">
                <i class="fas fa-chart-line text-white text-sm"></i>
              </div>
              <div>
                <h3 class="text-xl font-semibold text-white mb-2">Self-Improving Feedback Loop</h3>
                <p class="text-netflix-secondary">
                  "Was this helpful?" feedback transforms zero-shot AI responses into N-shot self-improvement, continuously enhancing educational quality
                </p>
              </div>
            </div>
          </div>

          <!-- Call to Action -->
          <button
            phx-click="get_started"
            class="px-12 py-4 netflix-button text-xl font-bold flex items-center justify-center mx-auto transform transition-all hover:scale-105"
          >
            <i class="fas fa-rocket mr-3"></i> Let's Get Started!
          </button>

          <!-- Demo Note -->
          <p class="text-netflix-secondary text-sm mt-6 opacity-75">
            This is a prototype demonstrating AI-powered video integration within the Torus learning platform
          </p>
        </div>
      </div>
    </div>
    """
  end
end
