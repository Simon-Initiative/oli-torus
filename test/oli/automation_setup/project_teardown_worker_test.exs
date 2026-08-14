defmodule Oli.AutomationSetup.ProjectTeardownWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  @moduletag capture_log: true

  alias Oli.AutomationSetup.ProjectTeardownWorker

  test "treats an already deleted project as a successful retry" do
    assert :ok =
             perform_job(ProjectTeardownWorker, %{
               "project_slug" => "missing-automation-project"
             })
  end
end
