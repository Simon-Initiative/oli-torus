defmodule Oli.AutomationSetupTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Analytics.Summary.{ResourcePartResponse, StudentResponse}
  alias Oli.AutomationSetup
  alias Oli.Repo

  describe "teardown_author/2" do
    test "keeps the responses of a learner whose id matches the deleted author" do
      password = valid_author_password()
      author = author_fixture(%{given_name: "Test", family_name: "Author", password: password})
      learner = insert(:user, id: author.id)
      insert_response(learner.id)

      assert learner.id == author.id
      assert %{success: true} = AutomationSetup.teardown_author(author.email, password)

      assert response_count(learner.id) == 1
    end
  end

  describe "teardown_learner/2" do
    test "clears the deleted learner's responses" do
      password = valid_user_password()
      learner = user_fixture(%{given_name: "Test", family_name: "Learner", password: password})
      insert_response(learner.id)

      assert response_count(learner.id) == 1
      assert %{success: true} = AutomationSetup.teardown_learner(learner.email, password)

      assert response_count(learner.id) == 0
    end
  end

  defp insert_response(user_id) do
    section = insert(:section)
    page = insert(:resource)

    part_response =
      Repo.insert!(%ResourcePartResponse{
        resource_id: page.id,
        part_id: "1",
        response: "answer",
        label: "answer"
      })

    Repo.insert!(%StudentResponse{
      section_id: section.id,
      page_id: page.id,
      user_id: user_id,
      resource_part_response_id: part_response.id
    })
  end

  defp response_count(user_id) do
    Repo.aggregate(from(sr in StudentResponse, where: sr.user_id == ^user_id), :count)
  end
end
