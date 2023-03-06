defmodule OliWeb.Experiments.ExperimentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Router.Helpers, as: Routes

  def mount(
        %{"project_id" => project_slug},
        _session,
        socket
      ) do

    {:ok, decision_points} = Oli.Resources.alternatives_groups(project_slug, Oli.Publishing.AuthoringResolver)

    has_decision_point = Enum.filter(decision_points, fn a -> a.strategy == "upgrade_decision_point" end)
    |> Enum.count() == 1

    user_url = Application.fetch_env!(:oli, :upgrade_experiment_provider)[:user_url]

    {:ok,
     assign(socket,
       has_decision_point: has_decision_point,
       project_slug: project_slug,
       user_url: user_url,
       title: "Experiments"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="content">

      <h3>Creating your experiment with Upgrade</h3>

      <p>Follow these steps to conduct an Upgrade-based experiment:</p>

      <ol class="list-decimal">
        <li>Create an Upgrade account at <a href={@user_url}><%= @user_url %></a></li>
        <li>Frome
        <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Resources.AlternativesEditor, @project_slug)}>Manage Alternatives</a>,
          create one "decision point" and add two or more conditions (i.e. options)</li>
        <li>Place instances of the decision point, with corresponding content for each condition, in pages in this course project</li>
        <li><b>After</b> steps 1 - 3, generate and download Upgrade segment and experiment JSON files. Import those into Upgrade as
        a new segment and new experiment.</li>
        <li>From Upgrade, schedule or enable enrollment for your experiment.</li>
        <li>Publish your course, and create course sections which will enroll students</li>
        <li>Monitor the progress of your experiment within Upgrade</li>
      </ol>

      <%= if @has_decision_point do %>
        <a class="btn btn-primary" href={Routes.experiment_path(OliWeb.Endpoint, :segment_download, @project_slug)}>Download Segment JSON</a>
        <a class="btn btn-primary" href={Routes.experiment_path(OliWeb.Endpoint, :experiment_download, @project_slug)}>Download Experiment JSON</a>
      <% else %>
        <strong>You can only generate and download these Upgrade files after you have created a decision point</strong>
        <a class="btn btn-primary" href="#">Download Segment JSON</a>
        <a class="btn btn-primary" href="#">Download Experiment JSON</a>
      <% end %>

    </div>
    """
  end

end
