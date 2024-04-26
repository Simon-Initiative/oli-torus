defmodule Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  alias Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker

  describe "perform/1" do
    test "runs logic when the host is the same" do
      section = insert(:section)
      %{id: last_grade_update_id} = insert(:lms_grade_update, score: 100, out_of: 120)

      %{id: resource_access_id} =
        insert(:resource_access,
          score: 5,
          out_of: 120,
          section: section,
          last_grade_update_id: last_grade_update_id
        )

      {:ok, updated_resource_access} =
        perform_job(GradeUpdateWorker, %{
          section_id: section.id,
          resource_access_id: resource_access_id,
          type: :manual_batch
        })

      assert updated_resource_access.id == resource_access_id
      refute updated_resource_access.last_grade_update_id == last_grade_update_id
    end

    test "doesn't run any logic when the host is different" do
      section = insert(:section)
      %{id: last_grade_update_id} = insert(:lms_grade_update, score: 100, out_of: 120)

      resource_access =
        insert(:resource_access,
          score: 5,
          out_of: 120,
          section: section,
          last_grade_update_id: last_grade_update_id
        )

      assert :ok =
               perform_job(GradeUpdateWorker, %{
                 section_id: section.id,
                 resource_access_id: resource_access.id,
                 type: :manual_batch,
                 host: "I_m_in_another_host"
               })

      # It doesn't update the last_grade_update_id because the host is different
      assert resource_access.last_grade_update_id == last_grade_update_id
    end
  end
end
