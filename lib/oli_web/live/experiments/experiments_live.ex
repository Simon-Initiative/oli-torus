defmodule OliWeb.Experiments.ExperimentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  import OliWeb.Experiments.SyncButton
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
        <li>Design your experiment within Upgrade, with one or more decision points</li>
        <li>Create the equivalent decision points in this course project</li>
        <li>Author instances of those decision points, with corresponding content, in pages in this course project</li>
        <li>Synchronize the metrics setup within Upgrade, and apply those metrics to your Upgrade experiment</li>
        <li>Publish your course, and create course sections that enroll students</li>
        <li>Monitor progress of the experiment and access metrics within Upgrade</li>
      </ol>

      <h4>Creating your experiment with Upgrade</h4>

      <p>Note: You must first have an account at <a href="{@user_url}"><%= @user_url %></a></p>

      <ol class="list-disc">
        <li>Create a new segment named <code><%= @project_slug %></code>, with members set to "add-group1" named <code><%= @project_slug %></code></li>
        <li>Create a new experiment, with your own name and description, but with the following settings:
          <ul class="list-decimal">
            <li>App Context: <code>torus</code></li>
            <li>Unit of Assignment: <code>Individual</code></li>
            <li>Consistency Rule: <code>Individual</code></li>
            <li>Design Type: <code>Simple Experiment</code></li>
          </ul>
        </li>
        <li>Add one or more decision points, each with their own condition codes</li>
        <li>For Participants, set the Inclusion Criteria to be <code>Include Specific</code> and set the group name of <code><%= @project_slug %></code>.</li>
        <li>Configure the start and end time for the experiment, and how to continue afterwards</li>
      </ol>

      <h4>Create the equivalent decision points in this course project</h4>

      <p>For each decision point created in your Upgrade experiment, create a corresponding "Decision Point"
        from the Manage Alternatives view. Ensure the names of the options for each decision point match the condition codes within Upgrade</p>

      <h4>Author instances of those decision points, with corresponding content, in pages in this course project</h4>

      <p>For each place where you want to vary content based on the experiment group that a student gets assigned to, add an instance of the
      "Alternative" constructor for the relevant decision point that you created.  Create content for each option.</p>

      <h4>Synchronize the metrics setup within Upgrade, and apply those metrics to your Upgrade experiment</h4>

      <p>As a final step prior to deploying this course and starting the experiment, the Upgrade system has to be updated to know how to
      collect metrics on the activities present in this course project.  Click

      <.sync_button sync_result={@sync_result}/>

      to
      do this. You will need to synchronize the metrics after you change the decision points or conditions within this course project.</p>

      <p>After synchronizing the metrics, you will need to edit your Upgrade experiment to add one metric for each decision point in the
      experiemnt.  </p>

      <h4>Publish your course, and create course sections that enroll students</h4>

      <p>After publishing your course, you (or instructors) can create any number of course sections that will add students and enroll them
      into the Upgrade experiment.  </p>

      <h4>Monitor progress of the experiment and access metrics within Upgrade</h4>

      <p>From the Upgrade user interface, monitor the progress of the experiment and view the resultant metrics.</p>

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
