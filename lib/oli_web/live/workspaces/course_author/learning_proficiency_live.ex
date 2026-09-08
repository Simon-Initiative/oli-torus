defmodule OliWeb.Workspaces.CourseAuthor.LearningProficiencyLive do
  @moduledoc "Author-facing explanations of learning proficiency frameworks and upgrades."
  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Components.Project.LearningProficiency

  @impl true
  def mount(_params, _session, socket) do
    project = socket.assigns.project

    {:ok,
     assign(socket,
       page_title: "Learning Proficiency",
       resource_slug: project.slug,
       resource_title: project.title,
       breadcrumbs: [
         Breadcrumb.new(%{
           full_title: "Project Overview",
           link: ~p"/workspaces/course_author/#{project.slug}/overview"
         }),
         Breadcrumb.new(%{full_title: "Learning Proficiency"})
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="mx-auto max-w-3xl space-y-6 p-8 text-Text-text-high">
      <h1 class="text-2xl font-bold">Learning Proficiency</h1>
      <p>
        Current learning proficiency framework: {LearningProficiency.version_label(
          @project.learning_model_version
        )}
      </p>
      <section class="space-y-2">
        <h2 class="text-xl font-semibold">Legacy framework (v1)</h2>
        <p>
          The legacy framework estimates proficiency for each learning objective (LO) using the percentage correct on first attempts.
          At least three first attempts are required for an LO before a proficiency level is shown; otherwise, there is not enough data.
          Scores are grouped as Low (40% or less), Medium (above 40% through 80%), or High (above 80%).
        </p>
      </section>
      <section class="space-y-2">
        <h2 class="text-xl font-semibold">LKT-AOA framework (v2)</h2>
        <p>
          LKT-AOA uses logistic regression trained on historical learner responses to estimate the probability of answering correctly.
          It combines learned difficulty parameters for each LO and activity part with the learner's amount of practice and recent performance.
          Recent successes and failures carry more weight than older ones when predicting the next response.
        </p>
        <p>
          Proficiency is the average of these predictions across all attempts, including repeated attempts.
          For an individual LO, at least three attempts are required before a level is shown: Low (below 40%), Medium (40% through 80%), or High (above 80%).
        </p>
      </section>
      <section class="space-y-2">
        <h2 class="text-xl font-semibold">Understanding confidence</h2>
        <p>
          LKT-AOA also calculates confidence separately from proficiency. Confidence describes how much breadth of evidence supports an LO's estimate, based on the number of distinct activity parts the learner has attempted.
          It rises quickly with the first few distinct parts, then increases more gradually as additional evidence accumulates.
          Repeating the same part contributes to proficiency but does not increase confidence.
          High confidence can support either a low or a high proficiency estimate; it does not mean the learner has mastered the objective.
        </p>
      </section>
      <section class="space-y-2">
        <h2 class="text-xl font-semibold">Updating the framework</h2>
        <p>
          New projects use LKT-AOA by default. Existing projects keep the legacy framework until an authorized author or administrator upgrades them.
          Upgrading a project updates all its existing templates and is permanent. Newly created course sections from the project or its templates will use the new framework.
          Existing course sections keep their current framework. The upgrade does not recalculate existing learner proficiency or change project content.
        </p>
      </section>
    </article>
    """
  end
end
