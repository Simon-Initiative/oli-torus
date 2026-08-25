defmodule Oli.AutomationSetup.ProjectTeardownWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  @moduletag capture_log: true

  alias Oli.AutomationSetup.ProjectTeardownWorker

  test "treats an already deleted project as a successful retry" do
    assert :ok =
             perform_job(ProjectTeardownWorker, %{
               "project_slug" => "missing-automation-project"
             })
  end

  test "cancels teardown when the project still has authors" do
    project = insert(:project, allow_duplication: false)

    assert {:cancel, "Can only delete projects with no authors"} =
             perform_job(ProjectTeardownWorker, %{
               "project_slug" => project.slug
             })
  end

  test "cancels teardown when the project allows duplicates" do
    project = insert(:project, authors: [], allow_duplication: true)

    assert {:cancel, "Project allows duplicates"} =
             perform_job(ProjectTeardownWorker, %{
               "project_slug" => project.slug
             })
  end
end
