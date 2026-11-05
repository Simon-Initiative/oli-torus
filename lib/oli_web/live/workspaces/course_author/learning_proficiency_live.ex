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
        This project currently uses
        <strong>
          {case @project.learning_model_version do
            :naive -> "Legacy framework (v1)"
            :lkt_aoa -> "LKT-AOA framework (v2)"
          end}
        </strong>
        ({LearningProficiency.version_label(@project.learning_model_version)}).
      </p>
      <.framework_section
        id="legacy-framework"
        title="Legacy framework (v1)"
        current={@project.learning_model_version == :naive}
      >
        <p>
          The legacy framework estimates proficiency for each learning objective (LO) using weighted first-attempt outcomes.
          Each correct first attempt contributes 1, and each incorrect first attempt contributes 0.2; proficiency is their average.
          At least three first attempts are required for an LO before a proficiency level is shown; otherwise, there is not enough data.
          Scores are grouped as Low (40% or less), Medium (above 40% through 80%), or High (above 80%).
        </p>
        <.calculation_example id="legacy-proficiency-example" title="Calculating proficiency levels">
          <.example_entry label="Scenario">
            A learner makes a first attempt on each of <strong>four different questions</strong>
            tagged to the sub-objective <strong>"Calculate the mean of a dataset."</strong>
          </.example_entry>
          <.example_entry label="What counts as a question">
            Each question is counted separately. In activities with multiple answer fields, each independently evaluated field counts separately.
          </.example_entry>
          <.example_group title="One correct and three incorrect">
            <.example_entry label="Calculation">(1 + 0.2 + 0.2 + 0.2) / 4 = 40%</.example_entry>
            <.example_entry label="Result"><strong>Low</strong> proficiency.</.example_entry>
          </.example_group>
          <.example_group title="Three correct and one incorrect">
            <.example_entry label="Calculation">(1 + 1 + 1 + 0.2) / 4 = 80%</.example_entry>
            <.example_entry label="Result"><strong>Medium</strong> proficiency.</.example_entry>
          </.example_group>
          <.example_group title="All four correct">
            <.example_entry label="Calculation">(1 + 1 + 1 + 1) / 4 = 100%</.example_entry>
            <.example_entry label="Result"><strong>High</strong> proficiency.</.example_entry>
          </.example_group>
        </.calculation_example>
        <.calculation_example id="legacy-insufficient-example" title="Not enough data">
          <.example_group title="After two first attempts">
            <.example_entry label="Attempts">
              <strong>Two different questions</strong>, both correct on their first attempts.
            </.example_entry>
            <.example_entry label="Calculation">(1 + 1) / 2 = 100%</.example_entry>
            <.example_entry label="Result">
              <strong>Not enough data</strong>. Fewer than three first attempts have been made.
            </.example_entry>
          </.example_group>
          <.example_group title="After answering either question again">
            <.example_entry label="Attempts">
              Answering either question again does not add another first attempt. The count remains <strong>two</strong>.
            </.example_entry>
            <.example_entry label="Result">
              Still <strong>Not enough data</strong>. A first attempt on a third different question is required to reach the minimum.
            </.example_entry>
          </.example_group>
          <.example_group title="After a first attempt on a third different question">
            <.example_entry label="Attempts">
              <strong>Three first attempts</strong>: two correct and the third incorrect.
            </.example_entry>
            <.example_entry label="Calculation">
              (1 + 1 + 0.2) / 3 = approximately 73.3%
            </.example_entry>
            <.example_entry label="Result"><strong>Medium</strong> proficiency.</.example_entry>
          </.example_group>
        </.calculation_example>
        <.calculation_example id="legacy-repeat-example" title="Answering the same question again">
          <.example_entry label="First attempts">
            <strong>Three correct</strong> and <strong>one incorrect</strong>.
          </.example_entry>
          <.example_entry label="Calculation">(1 + 1 + 1 + 0.2) / 4 = 80%</.example_entry>
          <.example_entry label="Result"><strong>Medium</strong> proficiency.</.example_entry>
          <.example_group title="After answering the incorrect question again">
            <.example_entry label="New response">
              The learner answers the previously incorrect question <strong>correctly on a second attempt</strong>.
            </.example_entry>
            <.example_entry label="Calculation">(1 + 1 + 1 + 0.2) / 4 = 80%</.example_entry>
            <.example_entry label="Result">
              Still <strong>Medium</strong>. Only first attempts contribute, so proficiency does not change.
            </.example_entry>
          </.example_group>
        </.calculation_example>
        <.calculation_example id="legacy-parent-example" title="Combining sub-objectives">
          <.example_entry label="Parent LO">
            <strong>One correct first attempt</strong> tagged directly to the parent.
          </.example_entry>
          <.example_entry label="Sub-objective">
            <strong>Two first attempts</strong>: one correct and one incorrect.
          </.example_entry>
          <.example_entry label="Calculation">(1 + 1 + 0.2) / 3 = approximately 73.3%</.example_entry>
          <.example_entry label="Result">
            <strong>Medium</strong>
            proficiency for the parent, combining its own evidence with its sub-objective's evidence.
          </.example_entry>
          <.example_entry label="Sub-objective result">
            <strong>Not enough data</strong>
            on its own, but its two first attempts still contribute to the parent.
          </.example_entry>
        </.calculation_example>
      </.framework_section>
      <.framework_section
        id="lkt-aoa-framework"
        title="LKT-AOA framework (v2)"
        current={@project.learning_model_version == :lkt_aoa}
      >
        <p>
          LKT-AOA uses logistic regression trained on historical learner responses to estimate the probability of answering correctly.
          It combines learned difficulty parameters for each LO and question or answer field with the learner's amount of practice and recent performance.
          Recent successes and failures carry more weight than older ones when predicting the next response.
        </p>
        <p>
          Proficiency is the average of these predictions across all attempts, including repeated attempts.
          For an individual LO, at least three attempts are required before a level is shown: Low (below 40%), Medium (40% through 80%), or High (above 80%).
        </p>
        <.calculation_example
          id="lkt-aoa-proficiency-example"
          title="Averaging predicted probabilities"
        >
          <.example_entry label="Scenario">
            A learner makes <strong>three attempts on different questions</strong>
            tagged to the sub-objective <strong>"Calculate the mean of a dataset."</strong>
          </.example_entry>
          <.example_entry label="What counts as a question">
            Each question is counted separately. In activities with multiple answer fields, each independently evaluated field counts separately.
          </.example_entry>
          <.example_entry label="Predictions">
            <strong>40%, 60%, and 80%</strong>
            chance of answering correctly, predicted before each attempt.
          </.example_entry>
          <.example_entry label="Calculation">(0.4 + 0.6 + 0.8) / 3 = 60%</.example_entry>
          <.example_entry label="Result"><strong>Medium</strong> proficiency.</.example_entry>
          <.example_entry label="Interpretation">
            Each prediction is made before the learner's response is incorporated.
            The response influences later predictions; the proficiency estimate is <strong>not the percentage of answers that were correct</strong>.
            At exactly 40%, this framework reports Medium; below 40% is Low, and above 80% is High.
          </.example_entry>
          <.example_entry label="Note">
            These predictions are illustrative; actual values depend on the questions or answer fields and the learner's history.
          </.example_entry>
        </.calculation_example>
        <.calculation_example id="lkt-aoa-insufficient-example" title="Not enough data">
          <.example_group title="After two evaluated attempts">
            <.example_entry label="Predictions"><strong>80% and 90%</strong>.</.example_entry>
            <.example_entry label="Calculation">(0.8 + 0.9) / 2 = 85%</.example_entry>
            <.example_entry label="Result">
              <strong>Not enough data</strong>. Fewer than three attempts have been made.
            </.example_entry>
          </.example_group>
          <.example_group title="After answering a previously attempted question again">
            <.example_entry label="Attempts">
              <strong>Three evaluated attempts</strong>. This repetition counts toward the minimum of three attempts.
            </.example_entry>
            <.example_entry label="New prediction">
              <strong>70%</strong> before the third attempt.
            </.example_entry>
            <.example_entry label="Calculation">(0.8 + 0.9 + 0.7) / 3 = 80%</.example_entry>
            <.example_entry label="Result"><strong>Medium</strong> proficiency.</.example_entry>
            <.example_entry label="Confidence">
              Confidence does not increase because the learner has not attempted a different question or answer field.
            </.example_entry>
          </.example_group>
          <.example_entry label="Note">
            These probabilities are illustrative, not fixed values assigned to responses.
          </.example_entry>
        </.calculation_example>
        <.calculation_example id="lkt-aoa-parent-example" title="Combining sub-objectives">
          <.example_entry label="Scenario">
            A parent LO has <strong>two sub-objectives</strong>.
          </.example_entry>
          <.example_entry label="Sub-objective A">
            An average prediction of <strong>80%</strong> across <strong>four attempts</strong>.
          </.example_entry>
          <.example_entry label="Sub-objective B">
            A prediction of <strong>40%</strong> from <strong>one attempt</strong>.
          </.example_entry>
          <.example_entry label="Calculation">(0.8 × 4 + 0.4 × 1) / 5 = 72%</.example_entry>
          <.example_entry label="Parent result">
            <strong>Medium</strong>
            proficiency. The parent has <strong>five attempts in total</strong>, so a proficiency level can be shown.
          </.example_entry>
          <.example_entry label="Sub-objective B result">
            <strong>Not enough data</strong>
            on its own, but its attempt still contributes to the parent.
          </.example_entry>
          <.example_entry label="Note">
            Only sub-objective evidence contributes to this parent calculation; attempts tagged only to the parent do not contribute.
          </.example_entry>
        </.calculation_example>
        <section
          id="understanding-confidence"
          aria-labelledby="confidence-title"
          class="space-y-2 pt-4"
        >
          <h3 id="confidence-title" class="text-lg font-semibold">Understanding confidence</h3>
          <p>
            LKT-AOA also calculates confidence separately from proficiency. Confidence describes how much breadth of evidence supports an LO's estimate, based on the number of different questions or answer fields the learner has attempted.
            Confidence increases as the learner attempts more different questions or answer fields, following a configurable curve.
            Answering the same question or answer field again contributes to proficiency but does not increase confidence.
            High confidence can support either a low or a high proficiency estimate; it does not mean the learner has mastered the objective.
          </p>
          <.calculation_example id="lkt-aoa-repeat-example" title="Repeated attempts and confidence">
            <.example_group title="Initially" heading_level={4}>
              <.example_entry label="Attempts">
                <strong>Three attempts on three different questions</strong>.
              </.example_entry>
              <.example_entry label="Predictions">
                <strong>40%, 60%, and 80%</strong>, for illustration.
              </.example_entry>
              <.example_entry label="Calculation">(0.4 + 0.6 + 0.8) / 3 = 60%</.example_entry>
              <.example_entry label="Result"><strong>Medium</strong> proficiency.</.example_entry>
            </.example_group>
            <.example_group title="After answering the same question again" heading_level={4}>
              <.example_entry label="Attempts">
                <strong>Four attempts</strong>, still on <strong>three different questions</strong>.
              </.example_entry>
              <.example_entry label="New prediction">
                <strong>80%</strong> before the fourth attempt, for illustration.
              </.example_entry>
              <.example_entry label="Calculation">(0.4 + 0.6 + 0.8 + 0.8) / 4 = 65%</.example_entry>
              <.example_entry label="Proficiency"><strong>65%, still Medium</strong>.</.example_entry>
              <.example_entry label="Confidence">
                <strong>Unchanged</strong>, because the learner has not attempted a different question or answer field.
              </.example_entry>
            </.example_group>
            <.example_group title="After attempting a different question" heading_level={4}>
              <.example_entry label="Attempts">
                <strong>Five attempts across four different questions</strong>, all tagged to the same sub-objective.
              </.example_entry>
              <.example_entry label="Confidence">
                <strong>Increases</strong>, because the learner has now attempted a different question linked to the same sub-objective.
              </.example_entry>
            </.example_group>
          </.calculation_example>
        </section>
      </.framework_section>
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

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :current, :boolean, required: true
  slot :inner_block, required: true

  defp framework_section(assigns) do
    ~H"""
    <section
      id={@id}
      aria-labelledby={"#{@id}-title"}
      class={[
        "space-y-3 rounded-xl border p-5",
        @current && "border-Border-border-active bg-Fill-Accent-fill-accent-blue",
        !@current && "border-Border-border-default"
      ]}
    >
      <div class="flex flex-wrap items-center gap-3">
        <h2 id={"#{@id}-title"} class="text-xl font-semibold">{@title}</h2>
        <span
          :if={@current}
          data-current-framework
          class="rounded-full bg-Fill-fill-info-dropdown px-3 py-1 text-sm font-semibold"
        >
          Current framework
        </span>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp calculation_example(assigns) do
    ~H"""
    <details id={@id} class="rounded-xl bg-Fill-fill-info-dropdown-expanded p-4">
      <summary class="w-fit cursor-pointer rounded-3xl bg-Fill-fill-info-dropdown px-3 py-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">
        View Example: {@title}
      </summary>
      <div class="mt-4 space-y-5 font-medium leading-relaxed">
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  attr :title, :string, required: true
  attr :heading_level, :integer, default: 3, values: [3, 4]
  slot :inner_block, required: true

  defp example_group(assigns) do
    ~H"""
    <div class="space-y-3">
      <.dynamic_tag
        tag_name={"h#{@heading_level}"}
        class="text-base font-bold text-Text-text-button"
      >
        {@title}
      </.dynamic_tag>
      <div class="space-y-2 pl-4">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp example_entry(assigns) do
    ~H"""
    <p>
      <strong class="font-bold">{@label}:</strong>
      <span class="font-medium">{render_slot(@inner_block)}</span>
    </p>
    """
  end
end
