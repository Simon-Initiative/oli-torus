defmodule Oli.CertificationEligibilityTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  alias Oli.CertificationEligibility
  alias Oli.Resources.Collaboration.Post

  describe "create_post_and_verify_qualification/2 (require_certification_check = false)" do
    setup do
      user = insert(:user)
      section = insert(:section, certificate_enabled: true)
      {:ok, user: user, section: section}
    end

    test "returns a post and does not trigger a CheckCertification job", ctx do
      %{user: user, section: section} = ctx

      attrs = %{user_id: user.id, section_id: section.id}

      assert {:ok, %Post{}} =
               CertificationEligibility.create_post_and_verify_qualification(attrs, false)

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end
  end

  describe "create_post_and_verify_qualification/2 (require_certification_check = true)" do
    setup do
      user = insert(:user)
      section = insert(:section, certificate_enabled: true)
      {:ok, user: user, section: section}
    end

    test "returns a post and triggers a CheckCertification job (case: Discussion)", ctx do
      %{user: user, section: section} = ctx
      attrs = %{user_id: user.id, section_id: section.id, annotated_resource_id: nil}

      assert {:ok, %Post{}} =
               CertificationEligibility.create_post_and_verify_qualification(attrs, true)

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "returns a post and triggers a CheckCertification job (case: Note)", ctx do
      %{user: user, section: section} = ctx

      attrs = %{
        user_id: user.id,
        section_id: section.id,
        annotated_resource_id: insert(:resource).id,
        visibility: :public
      }

      assert {:ok, %Post{}} =
               CertificationEligibility.create_post_and_verify_qualification(attrs, true)

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "does not trigger CheckCertification for non-Discussion, non-Note posts", ctx do
      %{user: user, section: section} = ctx

      attrs = %{
        user_id: user.id,
        section_id: section.id,
        annotated_resource_id: insert(:resource).id,
        visibility: :private
      }

      assert {:ok, %Post{}} =
               CertificationEligibility.create_post_and_verify_qualification(attrs, true)

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "check uniqueness when eligibility check is trigger twice", ctx do
      %{user: user, section: section} = ctx
      attrs = %{user_id: user.id, section_id: section.id, annotated_resource_id: nil}

      assert {:ok, %Post{id: post_id_1}} =
               CertificationEligibility.create_post_and_verify_qualification(attrs, true)

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )

      assert {:ok, %Post{id: post_id_2}} =
               CertificationEligibility.create_post_and_verify_qualification(attrs, true)

      assert post_id_1 != post_id_2

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )

      assert Oli.Repo.all(Oban.Job) |> Enum.count() == 1
    end
  end
end
