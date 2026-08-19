defmodule OliWeb.Workspaces.CourseAuthor.ProjectRepairLive do
  @moduledoc """
  Thin LiveView wrapper for the authoring project repair context.

  The domain context owns every safety-sensitive rule: Basic-page filtering,
  missing-reference classification, shared-activity repair planning, locking, and
  mutation. This module only coordinates the authenticated project route, renders
  the content-free report structs, and starts an explicit server-side repair.
  """

  use OliWeb, :live_view

  alias Oli.Authoring.ProjectRepair

  alias Oli.Authoring.ProjectRepair.{
    MissingActivityReference,
    RepairFailure,
    RepairResult,
    Report,
    SharedActivityReference,
    Summary
  }

  @issue_preview_limit 500
  @group_page_preview_limit 100

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # The router places this LiveView behind both the normal project workspace
    # hooks and a system-admin pipeline. Calling the context with the server-side
    # project/author assigns keeps the same defense-in-depth authorization that
    # protects console or future non-web callers.
    %{current_author: author, project: project} = socket.assigns

    socket =
      socket
      |> assign(
        author: author,
        confirming_repair?: false,
        fatal_error: nil,
        page_title: "Project Repair Tool | #{project.title}",
        project: project,
        repairing?: false,
        report_loading?: true,
        repair_result: nil,
        repair_status_message: nil,
        report: nil,
        resource_slug: project.slug,
        resource_title: project.title
      )
      |> start_report_analysis()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("show_repair_confirmation", _params, socket) do
    # This first click is intentionally non-mutating. The tool changes authoring
    # state only after the administrator reviews the inline confirmation and
    # submits the separate parameter-free `make_changes` event below.
    {:noreply, assign(socket, confirming_repair?: true)}
  end

  def handle_event("cancel_repair_confirmation", _params, socket) do
    {:noreply, assign(socket, confirming_repair?: false)}
  end

  def handle_event("make_changes", _params, %{assigns: %{repairing?: true}} = socket) do
    # Duplicate clicks from the same socket should not queue multiple repair
    # attempts. Cross-socket and cross-node safety remains enforced by the context
    # resource locks; this guard is only local UI hygiene.
    {:noreply, socket}
  end

  def handle_event("make_changes", _params, %{assigns: %{confirming_repair?: true}} = socket) do
    # The browser sends no resource ids, activity ids, or serialized preview plan.
    # The repair process below recomputes fresh project state on the server before
    # acquiring locks and writing, so tampered or stale browser state is irrelevant.
    socket =
      socket
      |> assign(
        confirming_repair?: false,
        repairing?: true,
        repair_result: nil,
        repair_status_message: "Repair is running. This may take a moment."
      )
      |> start_repair()

    {:noreply, socket}
  end

  def handle_event("make_changes", _params, socket) do
    # Confirmation is enforced server-side, not only by hiding/showing buttons in
    # the DOM. A forged or stale LiveView event cannot start mutation unless this
    # socket has first entered the explicit confirmation state.
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(:load_report, {:ok, {:ok, %Report{} = report}}, socket) do
    {:noreply,
     assign(socket,
       fatal_error: nil,
       report: to_display_report(report),
       report_loading?: false
     )}
  end

  def handle_async(:load_report, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       fatal_error: humanize_error(reason),
       report_loading?: false
     )}
  end

  def handle_async(:load_report, {:exit, _reason}, socket) do
    {:noreply,
     assign(socket,
       fatal_error: "The project analysis task did not complete.",
       report_loading?: false
     )}
  end

  def handle_async(:repair_project, {:ok, {:ok, %RepairResult{} = result}}, socket) do
    {:noreply, assign_repair_result(socket, result)}
  end

  def handle_async(:repair_project, {:ok, {:error, %RepairResult{} = result}}, socket) do
    {:noreply, assign_repair_result(socket, result)}
  end

  def handle_async(:repair_project, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       fatal_error: humanize_error(reason),
       repairing?: false,
       repair_status_message: nil
     )}
  end

  def handle_async(:repair_project, {:exit, _reason}, socket) do
    {:noreply,
     assign(socket,
       fatal_error: "The repair task did not complete.",
       repairing?: false,
       repair_status_message: nil
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-8 project-repair-tool">
      <header class="mb-4">
        <p class="text-muted mb-1">System administration</p>
        <h1 class="display-6">Project Repair Tool</h1>
        <p class="lead">
          Preview Basic-page structural issues, then optionally repair only resolvable shared
          activity references. Missing activities are reported here but are not changed.
        </p>
      </header>

      <div :if={@fatal_error} class="alert alert-danger" role="alert">
        {@fatal_error}
      </div>

      <div
        :if={@repair_status_message}
        class="alert alert-info"
        role="status"
        aria-live="polite"
      >
        {@repair_status_message}
      </div>

      <.repair_result result={@repair_result} />

      <div :if={@report_loading?} class="alert alert-info" role="status" aria-live="polite">
        Analyzing current Basic pages…
      </div>

      <.report_preview
        :if={@report}
        report={@report}
        project_slug={@project.slug}
        confirming_repair?={@confirming_repair?}
        repairing?={@repairing?}
      />
    </div>
    """
  end

  attr :report, Report, required: true
  attr :project_slug, :string, required: true
  attr :confirming_repair?, :boolean, required: true
  attr :repairing?, :boolean, required: true

  defp report_preview(assigns) do
    ~H"""
    <section aria-labelledby="repair-summary-heading">
      <div class="d-flex align-items-start justify-content-between gap-3 flex-wrap mb-3">
        <div>
          <h2 id="repair-summary-heading" class="h4 mb-2">Current analysis</h2>
          <p class="text-muted mb-0">
            This analysis is read-only and reflects current unpublished authoring revisions.
          </p>
        </div>

        <button
          :if={repairable_shared_groups?(@report) and !@confirming_repair?}
          id="project-repair-show-confirmation"
          type="button"
          class="btn btn-danger"
          phx-click="show_repair_confirmation"
          disabled={@repairing?}
        >
          Repair shared activity references
        </button>
      </div>

      <.repair_confirmation
        :if={@confirming_repair?}
        report={@report}
        repairing?={@repairing?}
      />

      <.summary_cards summary={@report.summary} />

      <.missing_references
        references={@report.missing_activity_references}
        summary={@report.summary}
        project_slug={@project_slug}
      />

      <.shared_references
        groups={@report.shared_activity_references}
        summary={@report.summary}
        project_slug={@project_slug}
      />
    </section>
    """
  end

  attr :summary, Summary, required: true

  defp summary_cards(assigns) do
    ~H"""
    <ul class="row g-3 mb-4 list-unstyled">
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-scanned">
          <div class="card-body">
            <h3 id="repair-summary-scanned" class="h6 text-muted">Basic pages scanned</h3>
            <p class="h3 mb-0">{@summary.scanned_pages_count}</p>
          </div>
        </article>
      </li>
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-adaptive">
          <div class="card-body">
            <h3 id="repair-summary-adaptive" class="h6 text-muted">Adaptive pages skipped</h3>
            <p class="h3 mb-0">{@summary.skipped_adaptive_pages_count}</p>
          </div>
        </article>
      </li>
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-missing">
          <div class="card-body">
            <h3 id="repair-summary-missing" class="h6 text-muted">Missing references</h3>
            <p class="h3 mb-0">{@summary.missing_activity_reference_count}</p>
          </div>
        </article>
      </li>
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-missing-pages">
          <div class="card-body">
            <h3 id="repair-summary-missing-pages" class="h6 text-muted">
              Pages with missing references
            </h3>
            <p class="h3 mb-0">{@summary.missing_activity_affected_page_count}</p>
          </div>
        </article>
      </li>
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-shared">
          <div class="card-body">
            <h3 id="repair-summary-shared" class="h6 text-muted">
              Repairable shared activities
            </h3>
            <p class="h3 mb-0">{@summary.repairable_shared_activity_resource_count}</p>
          </div>
        </article>
      </li>
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-shared-pages">
          <div class="card-body">
            <h3 id="repair-summary-shared-pages" class="h6 text-muted">
              Pages with repairable shared activities
            </h3>
            <p class="h3 mb-0">{@summary.repairable_shared_activity_affected_page_count}</p>
          </div>
        </article>
      </li>
      <li class="col-md-4">
        <article class="card h-100" aria-labelledby="repair-summary-shared-missing">
          <div class="card-body">
            <h3 id="repair-summary-shared-missing" class="h6 text-muted">
              Shared missing activities
            </h3>
            <p class="h3 mb-0">
              {@summary.non_repairable_shared_missing_activity_resource_count}
            </p>
          </div>
        </article>
      </li>
    </ul>
    """
  end

  attr :report, Report, required: true
  attr :repairing?, :boolean, required: true

  defp repair_confirmation(assigns) do
    ~H"""
    <section
      id="project-repair-confirmation"
      class="alert alert-warning"
      role="region"
      aria-labelledby="project-repair-confirmation-heading"
      aria-describedby="project-repair-confirmation-description"
    >
      <h2 id="project-repair-confirmation-heading" class="h4">
        Confirm shared activity repair
      </h2>
      <p id="project-repair-confirmation-description">
        This will repair {@report.summary.repairable_shared_activity_resource_count} shared activity groups affecting {@report.summary.repairable_shared_activity_affected_page_count} Basic pages. Missing activity references will remain unchanged.
      </p>
      <div class="d-flex gap-2 flex-wrap">
        <button
          id="project-repair-confirm-make-changes"
          type="button"
          class="btn btn-danger"
          phx-click="make_changes"
          phx-disable-with="Repairing..."
          disabled={@repairing?}
        >
          Confirm repair shared activity references
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          phx-click="cancel_repair_confirmation"
          disabled={@repairing?}
        >
          Cancel
        </button>
      </div>
    </section>
    """
  end

  attr :references, :list, required: true
  attr :summary, Summary, required: true
  attr :project_slug, :string, required: true

  defp missing_references(assigns) do
    assigns = assign(assigns, :issue_preview_limit, @issue_preview_limit)

    ~H"""
    <section class="mb-5" aria-labelledby="missing-activity-heading">
      <h2 id="missing-activity-heading" class="h4">Missing activity references</h2>
      <p class="text-muted">
        These references are report-only. This tool does not remove missing activity nodes.
      </p>
      <p
        :if={@summary.missing_activity_reference_count > length(@references)}
        class="text-muted"
      >
        Showing the first {@issue_preview_limit} missing references. Summary counts above reflect
        the full analysis.
      </p>

      <p :if={Enum.empty?(@references)} class="alert alert-success">
        No missing activity references were found in Basic pages.
      </p>

      <div :if={!Enum.empty?(@references)} class="table-responsive">
        <table class="table table-striped align-middle">
          <caption class="visually-hidden">
            Basic pages containing activity references that do not resolve in this project.
          </caption>
          <thead>
            <tr>
              <th scope="col">Missing activity resource id</th>
              <th scope="col">Page</th>
              <th scope="col">Page resource id</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={%MissingActivityReference{} = reference <- @references}>
              <td>{reference.activity_resource_id}</td>
              <td>
                <.page_editor_link page={reference.page} project_slug={@project_slug} />
              </td>
              <td>{reference.page.resource_id}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  attr :groups, :list, required: true
  attr :summary, Summary, required: true
  attr :project_slug, :string, required: true

  defp shared_references(assigns) do
    assigns = assign(assigns, :issue_preview_limit, @issue_preview_limit)

    ~H"""
    <section aria-labelledby="shared-activity-heading">
      <h2 id="shared-activity-heading" class="h4">Shared activity references</h2>
      <p class="text-muted">
        Repairable groups will keep the lowest page resource id on the original activity and
        clone that activity for each other page. Groups whose activity is missing are not repaired.
      </p>
      <p
        :if={
          @summary.repairable_shared_activity_resource_count +
            @summary.non_repairable_shared_missing_activity_resource_count > length(@groups)
        }
        class="text-muted"
      >
        Showing the first {@issue_preview_limit} shared activity groups. Summary counts above
        reflect the full analysis.
      </p>

      <p :if={Enum.empty?(@groups)} class="alert alert-success">
        No cross-page shared activity references were found in Basic pages.
      </p>

      <div :for={%SharedActivityReference{} = group <- @groups} class="card mb-3">
        <div class="card-header d-flex align-items-center justify-content-between gap-3 flex-wrap">
          <h3 class="h5 mb-0">Activity resource {group.activity_resource_id}</h3>
          <span class={"badge #{repairability_badge_class(group)}"}>
            {repairability_label(group)}
          </span>
        </div>

        <div class="card-body">
          <p>
            Referenced by {group.page_count} Basic pages.
            <span :if={group.page_count > length(group.pages)}>
              Showing the first {length(group.pages)}.
            </span>
          </p>

          <ul class="mb-0">
            <li :for={page <- group.pages}>
              <.page_editor_link page={page} project_slug={@project_slug} />
              <span class="text-muted">(page resource {page.resource_id})</span>
            </li>
          </ul>
        </div>
      </div>
    </section>
    """
  end

  attr :page, :map, required: true
  attr :project_slug, :string, required: true

  defp page_editor_link(assigns) do
    ~H"""
    <.link
      href={~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@page.revision_slug}/edit"}
      aria-label={"Open page editor for #{@page.title}, page resource #{@page.resource_id}"}
    >
      {@page.title}
    </.link>
    """
  end

  attr :result, RepairResult, default: nil

  defp repair_result(%{result: nil} = assigns), do: ~H""

  defp repair_result(assigns) do
    ~H"""
    <section class={repair_result_alert_class(@result)} role="status" aria-live="polite">
      <h2 class="h4">{repair_result_heading(@result)}</h2>
      <p>
        Updated {@result.updated_page_count} pages and cloned {@result.cloned_activity_count} activities. The analysis below has been refreshed from current project state.
      </p>

      <ul :if={!Enum.empty?(@result.failures)}>
        <li :for={%RepairFailure{} = failure <- @result.failures}>
          {failure_message(failure)}
        </li>
      </ul>

      <p :if={!Enum.empty?(@result.warnings)} class="mb-0">
        Warnings: {Enum.map_join(@result.warnings, ", ", &humanize_atom/1)}
      </p>
    </section>
    """
  end

  defp start_report_analysis(socket) do
    %{author: author, project: project} = socket.assigns

    # Analysis can scan every Basic page in a project. Running it as a LiveView
    # async task renders the admin shell immediately and keeps the socket process
    # responsive while the context performs its bounded database stream. Preview
    # limits are passed only to this read-only display analysis; repair planning
    # always reanalyzes without display caps so no mutation work is hidden.
    start_async(socket, :load_report, fn ->
      ProjectRepair.analyze_project(project, author,
        preview_issue_limit: @issue_preview_limit,
        preview_group_page_limit: @group_page_preview_limit
      )
    end)
  end

  defp start_repair(socket) do
    %{author: author, project: project} = socket.assigns

    # Repair may re-analyze, lock resources, clone activities, and write revisions.
    # `start_async/3` avoids monopolizing the LiveView process while preserving
    # the context's authoritative locking and fresh-plan validation.
    start_async(socket, :repair_project, fn ->
      ProjectRepair.repair_project(project, author)
    end)
  end

  defp assign_repair_result(socket, %RepairResult{} = result) do
    assign(socket,
      fatal_error: nil,
      repairing?: false,
      repair_result: display_repair_result(result),
      repair_status_message: nil,
      report: to_display_report(result.report_after_repair)
    )
  end

  defp to_display_report(%Report{} = report) do
    # The domain report remains complete for context tests and repair safety, but
    # the LiveView keeps only a bounded preview in socket assigns. Summary counts
    # still reflect the full analysis, so administrators can see scale without a
    # very large issue list becoming one very large LiveView diff.
    %Report{
      report
      | missing_activity_references:
          Enum.take(report.missing_activity_references, @issue_preview_limit),
        shared_activity_references:
          report.shared_activity_references
          |> Enum.take(@issue_preview_limit)
          |> Enum.map(&limit_group_pages/1)
    }
  end

  defp limit_group_pages(%SharedActivityReference{} = group) do
    %SharedActivityReference{group | pages: Enum.take(group.pages, @group_page_preview_limit)}
  end

  defp display_repair_result(%RepairResult{} = result) do
    # The rendered result uses counts, failures, and warnings only. Dropping the
    # full before/after reports from this assign avoids retaining duplicate issue
    # lists; the bounded after-report is assigned separately as `:report`.
    %RepairResult{result | report_before_repair: nil, report_after_repair: nil}
  end

  defp repairable_shared_groups?(%Report{summary: %Summary{} = summary}) do
    summary.repairable_shared_activity_resource_count > 0
  end

  defp repairability_label(%SharedActivityReference{repairable?: true}), do: "Repairable"
  defp repairability_label(%SharedActivityReference{repairable?: false}), do: "Missing activity"

  defp repairability_badge_class(%SharedActivityReference{repairable?: true}),
    do: "text-bg-success"

  defp repairability_badge_class(%SharedActivityReference{repairable?: false}),
    do: "text-bg-warning"

  defp repair_result_heading(%RepairResult{status: :completed}), do: "Repair completed"
  defp repair_result_heading(%RepairResult{status: :partial}), do: "Repair partially completed"
  defp repair_result_heading(%RepairResult{status: :failed}), do: "Repair failed"

  defp repair_result_alert_class(%RepairResult{status: :completed}), do: "alert alert-success"
  defp repair_result_alert_class(%RepairResult{status: :partial}), do: "alert alert-warning"
  defp repair_result_alert_class(%RepairResult{status: :failed}), do: "alert alert-danger"

  defp failure_message(%RepairFailure{} = failure) do
    [
      "Stage: #{humanize_atom(failure.stage)}",
      "Reason: #{humanize_atom(failure.reason)}",
      scoped_id("page", failure.page_resource_id),
      scoped_id("activity", failure.activity_resource_id)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("; ")
  end

  defp scoped_id(_label, nil), do: nil
  defp scoped_id(label, id), do: "#{label} resource id: #{id}"

  defp humanize_error(:not_authorized), do: "You are not authorized to use this repair tool."
  defp humanize_error(:project_not_found), do: "The selected project could not be found."

  defp humanize_error(:working_publication_not_found),
    do: "The selected project does not have a working authoring publication."

  defp humanize_error({:invalid_page_content, page_resource_id}),
    do: "Analysis stopped because page resource #{page_resource_id} has invalid content."

  defp humanize_error({:invalid_options, _reason}),
    do: "The repair tool was invoked with invalid processing options."

  defp humanize_error(_reason), do: "The project repair tool could not complete the request."

  defp humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
  end
end
