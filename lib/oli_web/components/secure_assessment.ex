defmodule OliWeb.Components.SecureAssessment do
  @moduledoc "Assessment-only chrome shared by secure delivery and review."
  use OliWeb, :html

  slot :inner_block, required: true

  @doc "Renders accessible assessment content and a current-session-only POST exit."
  def shell(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-slate-900 dark:bg-slate-950 dark:text-white">
      <a href="#secure-assessment-content" class="sr-only focus:not-sr-only focus:p-3">
        {gettext("Skip to assessment")}
      </a>
      <header class="flex flex-wrap items-center justify-between gap-3 border-b p-4">
        <span class="font-semibold">{gettext("Secure assessment")}</span>
        <form action="/secure-assessment/exit" method="post" target="_top">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <button
            type="submit"
            class="rounded border px-4 py-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
          >
            {gettext("Exit assessment")}
          </button>
        </form>
      </header>
      <main id="secure-assessment-content" tabindex="-1" class="relative min-w-0">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end
end
