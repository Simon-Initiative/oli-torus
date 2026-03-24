defmodule Oli.Delivery.TemplatePreviewTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.TemplatePreview

  @requested_event [:oli, :template_preview, :requested]
  @enrollment_ensured_event [:oli, :template_preview, :enrollment_ensured]
  @launch_succeeded_event [:oli, :template_preview, :launch_succeeded]
  @launch_failed_event [:oli, :template_preview, :launch_failed]

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

    test "treats an existing hidden instructor current_user as hidden-instructor fallback" do
      author = insert(:author)
      project = insert(:project, authors: [author])
      section = insert(:section, base_project: project, type: :blueprint, status: :active)

      {:ok, %{user: hidden_user}} = Oli.Delivery.Sections.ensure_hidden_instructor(section.id)

      assert {:ok, %{launch_identity: :hidden_instructor, hidden_instructor_outcome: :reused}} =
               TemplatePreview.prepare_launch(section, hidden_user, author)
    end

    test "uses any current user for learner enrollment" do
      %{author: author, section: section} = blueprint_fixture()
      other_user = insert(:user)

      assert {:ok,
              %{
                launch_identity: :current_user,
                enrollment_outcome: :created,
                hidden_instructor_outcome: nil
              }} = TemplatePreview.prepare_launch(section, other_user, author)
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

    test "emits request, enrollment ensured, and success telemetry with id-only metadata" do
      %{author: author, user: user, section: section} = blueprint_fixture()

      handler =
        attach_telemetry([@requested_event, @enrollment_ensured_event, @launch_succeeded_event])

      assert {:ok, %{launch_identity: :current_user, enrollment_outcome: :created}} =
               TemplatePreview.prepare_launch(section, user, author)

      assert_receive {:telemetry_event, @requested_event, %{count: 1}, requested_metadata}
      assert requested_metadata.section_id == section.id
      assert requested_metadata.section_slug == section.slug
      assert requested_metadata.product_id == section.id
      assert requested_metadata.user_id == user.id
      assert requested_metadata.author_id == author.id
      assert requested_metadata.tenant_id == section.institution_id

      assert_receive {:telemetry_event, @enrollment_ensured_event, %{count: 1}, ensured_metadata}

      assert ensured_metadata.section_id == section.id
      assert ensured_metadata.product_id == section.id
      assert ensured_metadata.user_id == user.id
      assert ensured_metadata.author_id == author.id
      assert ensured_metadata.launch_identity == "current_user"
      assert ensured_metadata.enrollment_outcome == :created
      assert ensured_metadata.hidden_instructor_outcome == nil
      refute Map.has_key?(ensured_metadata, :email)

      assert_receive {:telemetry_event, @launch_succeeded_event, %{count: 1}, success_metadata}
      assert success_metadata.launch_identity == "current_user"
      assert success_metadata.user_id == user.id
      assert success_metadata.enrollment_outcome == :created

      :telemetry.detach(handler)
    end

    test "emits hidden instructor telemetry on no-current-user fallback" do
      author = insert(:author)
      project = insert(:project, authors: [author])
      section = insert(:section, base_project: project, type: :blueprint, status: :active)
      handler = attach_telemetry([@enrollment_ensured_event, @launch_succeeded_event])

      assert {:ok,
              %{
                launch_identity: :hidden_instructor,
                hidden_instructor_outcome: :created,
                enrollment_outcome: nil
              }} = TemplatePreview.prepare_launch(section, nil, author)

      assert_receive {:telemetry_event, @enrollment_ensured_event, %{count: 1}, ensured_metadata}

      assert ensured_metadata.launch_identity == "hidden_instructor"
      assert ensured_metadata.hidden_instructor_outcome == :created
      assert ensured_metadata.enrollment_outcome == nil
      assert is_integer(ensured_metadata.user_id)
      refute Map.has_key?(ensured_metadata, :email)

      assert_receive {:telemetry_event, @launch_succeeded_event, %{count: 1}, success_metadata}
      assert success_metadata.launch_identity == "hidden_instructor"
      assert success_metadata.hidden_instructor_outcome == :created

      :telemetry.detach(handler)
    end

    test "emits failure telemetry with categorical error metadata only" do
      %{user: user, section: section} = blueprint_fixture()
      other_author = insert(:author)
      handler = attach_telemetry([@requested_event, @launch_failed_event])

      assert {:error, :unauthorized} =
               TemplatePreview.prepare_launch(section, user, other_author)

      assert_receive {:telemetry_event, @requested_event, %{count: 1}, requested_metadata}
      assert requested_metadata.section_id == section.id
      assert requested_metadata.user_id == user.id

      assert_receive {:telemetry_event, @launch_failed_event, %{count: 1}, failed_metadata}
      assert failed_metadata.section_id == section.id
      assert failed_metadata.user_id == user.id
      assert failed_metadata.author_id == other_author.id
      assert failed_metadata.error_category == "unauthorized"
      refute Map.has_key?(failed_metadata, :launch_identity)
      refute Map.has_key?(failed_metadata, :email)

      :telemetry.detach(handler)
    end
  end

  defp blueprint_fixture do
    author = insert(:author)
    user = insert(:user, author: author, email: author.email)
    project = insert(:project, authors: [author])
    section = insert(:section, base_project: project, type: :blueprint, status: :active)

    %{author: author, user: user, section: section}
  end

  defp attach_telemetry(events) do
    handler_id = "template-preview-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

    handler_id
  end
end
