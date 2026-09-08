defmodule OliWeb.Workspaces.CourseAuthor.LearningProficiencyLive do
  @moduledoc "Temporary learning proficiency documentation until the full guides are available."
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
      <p class="text-Text-text-low">
        Full documentation is being prepared. This page provides a brief overview in the meantime.
      </p>
      <section class="space-y-2">
        <h2 class="text-xl font-semibold">Legacy framework</h2>
        <p>
          The original learning proficiency framework remains available for existing projects until an author or administrator chooses to upgrade.
        </p>
      </section>
      <section class="space-y-2">
        <h2 class="text-xl font-semibold">LKT-AOA framework</h2>
        <p>
          The latest framework uses learned learning objective and activity-part parameters when calculating proficiency. New projects use this framework by default.
        </p>
      </section>
      <p>
        Upgrading a project updates all its existing templates and is permanent. Newly created course sections from the project or its templates will use the new framework. Existing course sections keep their current framework. The upgrade does not recalculate existing learner proficiency or change project content.
      </p>
    </article>
    """
  end
end
