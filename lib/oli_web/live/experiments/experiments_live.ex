defmodule OliWeb.Experiments.ExperimentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Router.Helpers, as: Routes

  def mount(
        %{"project_id" => project_slug},
        _session,
        socket
      ) do

    {:ok, decision_points} = Oli.Resources.alternatives_groups(project_slug, Oli.Publishing.AuthoringResolver)

    user_url = Application.fetch_env!(:oli, :upgrade_experiment_provider)[:user_url]

    {:ok,
     assign(socket,
       sync_result: :default,
       decision_points: decision_points,
       project_slug: project_slug,
       user_url: user_url,
       title: "Experiments"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="content">

      <h3>Creating your experiment with Upgrade</h3>

      <h4>Overview</h4>

      <p>The following is the high-level process to run an A/B experiment with the Upgrade system integration:</p>

      <ol class="list-decimal">
        <li>From "Manage Alternatives", create a decision point and two or more conditions</li>
        <li>Author instances of those decision points, with corresponding content, in pages in this course project</li>
        <li><b>After</b> steps 1 and 2, generate and download Upgrade
        <a href={Routes.experiment_path(OliWeb.Endpoint, :segment_download, @project_slug)}>segment</a> and
        <a href={Routes.experiment_path(OliWeb.Endpoint, :experiment_download, @project_slug)}>experiment</a> files, import them into Upgrade</li>
        <li>Publish your course, and create course sections that enroll students</li>
        <li>Monitor progress of the experiment and access metrics within Upgrade</li>
      </ol>

    </div>
    """
  end


  def handle_event("sync", _params, socket) do

    case Oli.Delivery.Experiments.synchronize_metrics(socket.assigns.project_slug, socket.assigns.decision_points) do
      {:ok, _} -> {:noreply, assign(socket, sync_result: :success)}
      _ -> {:noreply, assign(socket, sync_result: :failed)}
    end

  end


end
