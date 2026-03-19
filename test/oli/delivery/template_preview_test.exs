defmodule Oli.Delivery.TemplatePreviewTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.TemplatePreview

  describe "prepare_launch/3" do
    test "creates a learner enrollment and returns the section slug" do
      %{author: author, user: user, section: section} = blueprint_fixture()

      assert {:ok,
              %{
                section_slug: section_slug,
                launch_identity: :current_user,
                enrollment_outcome: :created,
                hidden_instructor_outcome: nil
              }} =
               TemplatePreview.prepare_launch(section, user, author)

      assert section_slug == section.slug
    end

    test "reuses an existing learner enrollment" do
      %{author: author, user: user, section: section} = blueprint_fixture()

      assert {:ok, %{launch_identity: :current_user, enrollment_outcome: :created}} =
               TemplatePreview.prepare_launch(section, user, author)

      assert {:ok, %{launch_identity: :current_user, enrollment_outcome: :reused}} =
               TemplatePreview.prepare_launch(section, user, author)
    end

    test "creates a hidden instructor when no current user is present" do
      author = insert(:author)
      project = insert(:project, authors: [author])
      section = insert(:section, base_project: project, type: :blueprint, status: :active)

      assert {:ok,
              %{
                section_slug: section_slug,
                launch_identity: :hidden_instructor,
                enrollment_outcome: nil,
                hidden_instructor_outcome: :created
              }} =
               TemplatePreview.prepare_launch(section, nil, author)

      assert section_slug == section.slug
    end

    test "reuses the section hidden instructor when no current user is present" do
      author = insert(:author)
      project = insert(:project, authors: [author])
      section = insert(:section, base_project: project, type: :blueprint, status: :active)

      assert {:ok, %{launch_identity: :hidden_instructor, hidden_instructor_outcome: :created}} =
               TemplatePreview.prepare_launch(section, nil, author)

      assert {:ok, %{launch_identity: :hidden_instructor, hidden_instructor_outcome: :reused}} =
               TemplatePreview.prepare_launch(section, nil, author)
    end

    test "returns an error when the learner account is not linked to the author" do
      %{author: author, section: section} = blueprint_fixture()
      other_user = insert(:user)

      assert {:error, :missing_delivery_identity} =
               TemplatePreview.prepare_launch(section, other_user, author)
    end

    test "returns an error for unauthorized authors" do
      %{user: user, section: section} = blueprint_fixture()
      other_author = insert(:author)

      assert {:error, :unauthorized} =
               TemplatePreview.prepare_launch(section, user, other_author)
    end

    test "returns an error for archived template sections" do
      %{author: author, user: user, section: section} = blueprint_fixture()
      archived_section = %{section | status: :archived}

      assert {:error, :section_unavailable} =
               TemplatePreview.prepare_launch(archived_section, user, author)
    end
  end

  defp blueprint_fixture do
    author = insert(:author)
    user = insert(:user, author: author, email: author.email)
    project = insert(:project, authors: [author])
    section = insert(:section, base_project: project, type: :blueprint, status: :active)

    %{author: author, user: user, section: section}
  end
end
