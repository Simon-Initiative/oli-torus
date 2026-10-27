defmodule OliWeb.Components.SecureAssessment do
  @moduledoc "Assessment-only chrome shared by secure delivery and review."
  use OliWeb, :html

  @doc "Returns whether the authenticated session requires assessment-only navigation."
  @spec restrict_navigation?(map() | nil) :: boolean()
  def restrict_navigation?(session), do: match?(%{scope: %{}}, session)

  @doc "Confines adaptive delivery destinations to the session's assessment."
  @spec adaptive_params(map(), map() | nil) :: map()
  def adaptive_params(params, session) do
    case restrict_navigation?(session) do
      true ->
        assessment_path =
          OliWeb.Delivery.Student.Utils.prologue_live_path(params.sectionSlug, params.pageSlug)

        params
        |> Map.merge(%{
          restrictNavigation: true,
          overviewURL: assessment_path,
          signoutUrl: assessment_path,
          previousPageURL: nil,
          nextPageURL: nil
        })
        |> Map.update!(:content, &Map.put(&1, "displayApplicationChrome", false))

      false ->
        params
    end
  end

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
