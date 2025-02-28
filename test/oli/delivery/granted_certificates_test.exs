defmodule Oli.Delivery.GrantedCertificatesTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Mox
  import Oli.Factory

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.Workers.GeneratePdf
  alias Oli.Delivery.Sections.GrantedCertificate

  describe "has_qualified/2" do
    setup [:create_elixir_project]

    test "grants a certificate based on discussion posts, class notes, and graded assessments",
         ctx do
      %{student: student, section: section, page_1: page_1, page_2: page_2, page_3: page_3} = ctx
      student_id = student.id

      _certificate =
        insert(:certificate,
          section: section,
          required_discussion_posts: 1,
          required_class_notes: 1,
          min_percentage_for_completion: 50,
          min_percentage_for_distinction: 100,
          assessments_apply_to: :all
        )

      # Student makes a class note (annotated post) but hasn't met the discussion post requirement
      # {notes, posts} -> {1, 0}
      insert(:post, user: student, section: section, annotated_resource_id: page_1.resource_id)

      assert {:ok, :no_change} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # Student makes a course discussion post
      # {notes, posts} -> {1, 1} (now meets the discussion and note requirements)
      insert(:post, user: student, section: section, annotated_resource_id: nil)

      # Student still does not qualify for a certificate because they haven't completed the required graded work.
      assert {:failed_min_percentage_for_completion, :failed_min_percentage_for_distinction} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # There are 3 graded pages.
      # The student completes one graded page with a perfect score.
      insert(:resource_access,
        user: student,
        section: section,
        resource: page_1.resource,
        score: 4.0,
        out_of: 4.0
      )

      # Student completes a second graded page with a perfect score.
      insert(:resource_access,
        user: student,
        section: section,
        resource: page_2.resource,
        score: 4.0,
        out_of: 4.0
      )

      # Student still does not qualify for a certificate because they haven't completed the required graded work.
      assert {:failed_min_percentage_for_completion, :failed_min_percentage_for_distinction} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # Verify that the student has not yet been granted a certificate.
      refute Oli.Repo.get_by(GrantedCertificate, %{user_id: student_id})

      # The student accesses the third graded page but does not yet have a score.
      access_page_3 =
        insert(:resource_access,
          user: student,
          section: section,
          resource: page_3.resource,
          score: nil,
          out_of: nil
        )

      # Since the student has accessed all required graded pages but has not yet earned a score for the third page,
      # they still fail to meet both the completion and distinction percentage requirements.
      assert {:failed_min_percentage_for_completion, :failed_min_percentage_for_distinction} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # Verify that the student has not yet been granted a certificate.
      refute Oli.Repo.get_by(GrantedCertificate, %{user_id: student_id})

      # The student's score for the third graded page is updated to 1.0 out of 4.0, which is very low.
      Oli.Delivery.Attempts.Core.update_resource_access(access_page_3, %{score: 1.0, out_of: 4.0})

      # The student still does not meet the minimum completion thresholds.
      assert {:failed_min_percentage_for_completion, :failed_min_percentage_for_distinction} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # The student's score for the third graded page is now updated to 2.0 out of 4.0, improving their performance.
      Oli.Delivery.Attempts.Core.update_resource_access(access_page_3, %{score: 2.0, out_of: 4.0})

      # Now, the student has met the minimum percentage for course completion but still falls short of the distinction threshold.
      assert {:passed_min_percentage_for_completion, :failed_min_percentage_for_distinction} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # A certificate is granted to the student, but it is without distinction since they have not yet met the higher threshold.
      assert %GrantedCertificate{with_distinction: false} =
               Oli.Repo.get_by(GrantedCertificate, %{user_id: student_id})

      # The student's score for the third graded page is updated to 4.0 out of 4.0 (a perfect score).
      Oli.Delivery.Attempts.Core.update_resource_access(access_page_3, %{score: 4.0, out_of: 4.0})

      # Now that the student has met both the minimum completion and distinction thresholds,
      # they earn a certificate with distinction.
      assert {:certificate_earned, :passed_min_percentage_for_distinction} =
               Oli.Delivery.GrantedCertificates.has_qualified(student_id, section.id)

      # The previously granted certificate is updated, now indicating that the student has earned it with distinction.
      assert %GrantedCertificate{with_distinction: true} =
               Oli.Repo.get_by(GrantedCertificate, %{user_id: student_id})

      # Assert that email notification is correctly enqueued
      # TODO https://eliterate.atlassian.net/browse/MER-4107
    end
  end

  describe "with_distinction_exists?/2" do
    test "returns false when no granted certificate is associated with a certificate" do
      user = insert(:user)
      section = insert(:section)
      _certificate = insert(:certificate, section: section)

      refute GrantedCertificates.with_distinction_exists?(user.id, section.id)
    end

    test "returns false when granted certificate is not with distinction" do
      user = insert(:user)
      section = insert(:section)
      certificate = insert(:certificate, section: section)

      _gc =
        insert(:granted_certificate,
          user: user,
          certificate: certificate,
          with_distinction: false
        )

      refute GrantedCertificates.with_distinction_exists?(user.id, section.id)
    end

    test "returns true when granted certificate is with distinction" do
      user = insert(:user)
      section = insert(:section)
      certificate = insert(:certificate, section: section)

      _gc =
        insert(:granted_certificate,
          user: user,
          certificate: certificate,
          with_distinction: true
        )

      assert GrantedCertificates.with_distinction_exists?(user.id, section.id)
    end
  end

  describe "generate_pdf/1" do
    test "generates a pdf certificate in a lambda function and stores the url" do
      gc = insert(:granted_certificate)

      assert gc.url == nil

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      assert {:ok, _multi} = GrantedCertificates.generate_pdf(gc.id)
      assert Repo.get(GrantedCertificate, gc.id).url =~ "/certificates/#{gc.guid}.pdf"
    end

    test "fails if aws operation fails" do
      gc = insert(:granted_certificate)

      expect(Oli.Test.MockAws, :request, 1, fn _operation ->
        {:ok, %{"statusCode" => 500, "body" => %{"error" => "Internal server error"}}}
      end)

      assert {:error, :error_generating_pdf, _} = GrantedCertificates.generate_pdf(gc.id)
    end
  end

  describe "create_granted_certificate/1" do
    setup do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      [user_1, user_2] = insert_pair(:user)

      %{section: section, certificate: certificate, user_1: user_1, user_2: user_2}
    end

    test "creates a new granted certificate (no oban job) when state is not :earned", %{
      certificate: certificate,
      user_1: user_1,
      user_2: user_2
    } do
      attrs = %{
        state: :denied,
        user_id: user_1.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      assert {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)
      assert gc.state == :denied
      refute gc.with_distinction

      refute_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id}
      )

      attrs_2 = %{
        state: :pending,
        user_id: user_2.id,
        certificate_id: certificate.id,
        with_distinction: true,
        guid: UUID.uuid4()
      }

      assert {:ok, gc_2} = GrantedCertificates.create_granted_certificate(attrs_2)
      assert gc_2.state == :pending
      assert gc_2.with_distinction

      refute_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id}
      )
    end

    test "creates a new granted certificate and an oban job is enqueued when state is :earned", %{
      certificate: certificate,
      user_1: user_1
    } do
      attrs = %{
        state: :earned,
        user_id: user_1.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      assert {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)
      assert gc.state == :earned
      refute gc.with_distinction

      # this oban job will enqueue another job to send an email to the student
      # after creating the pdf
      assert_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id, "send_email?" => true}
      )
    end

    test "returns an error-changeset when the attrs are invalid", %{certificate: certificate} do
      attrs = %{
        state: :denied,
        user_id: nil,
        certificate_id: certificate.id,
        with_distinction: false
      }

      assert {:error, changeset} = GrantedCertificates.create_granted_certificate(attrs)
      assert changeset.errors[:user_id] == {"can't be blank", [validation: :required]}
    end
  end

  describe "update_granted_certificate/2" do
    test "updates a granted certificate with the given attributes" do
      gc = insert(:granted_certificate, state: :denied)

      assert {:ok, gc} = GrantedCertificates.update_granted_certificate(gc.id, %{state: :earned})
      assert gc.state == :earned
    end

    test "returns an error-changeset when the attrs are invalid" do
      gc = insert(:granted_certificate, state: :denied)

      assert {:error, changeset} =
               GrantedCertificates.update_granted_certificate(gc.id, %{state: nil})

      assert changeset.errors[:state] == {"can't be blank", [validation: :required]}
    end
  end

  describe "send_certificate_email/3" do
    test "schedules an oban job to send the corresponding email" do
      granted_certificate = insert(:granted_certificate)

      GrantedCertificates.send_certificate_email(
        granted_certificate.guid,
        "some@email.com",
        :certificate_approval
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => granted_certificate.id,
          "to" => "some@email.com",
          "template" => "certificate_approval"
        }
      )
    end
  end

  describe "bulk_send_certificate_status_email/1" do
    test "schedules oban jobs to send the corresponding email to all students that haven't yet received the notification" do
      section = insert(:section)
      certificate = insert(:certificate, section: section)

      [gc_1, gc_2] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: false
        )

      [gc_3, gc_4] =
        insert_pair(:granted_certificate,
          state: :denied,
          certificate: certificate,
          student_email_sent: false
        )

      [gc_5, gc_6] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: true
        )

      GrantedCertificates.bulk_send_certificate_status_email(section.slug)

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_1.id,
          "to" => gc_1.user.email,
          "template" => "certificate_approval"
        }
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_2.id,
          "to" => gc_2.user.email,
          "template" => "certificate_approval"
        }
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_3.id,
          "to" => gc_3.user.email,
          "template" => "certificate_denial"
        }
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_4.id,
          "to" => gc_4.user.email,
          "template" => "certificate_denial"
        }
      )

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_5.id,
          "to" => gc_5.user.email,
          "template" => "certificate_approval"
        }
      )

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_6.id,
          "to" => gc_6.user.email,
          "template" => "certificate_approval"
        }
      )
    end
  end

  describe "certificate_pending_email_notification_count/1" do
    test "returns the count of granted certificates that have not been emailed to the students yet" do
      section = insert(:section)
      certificate = insert(:certificate, section: section)

      [_gc_1, _gc_2] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: false
        )

      [_gc_3, _gc_4] =
        insert_pair(:granted_certificate,
          state: :denied,
          certificate: certificate,
          student_email_sent: false
        )

      [_gc_5, _gc_6] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: true
        )

      assert GrantedCertificates.certificate_pending_email_notification_count(section.slug) == 4
    end
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page 1",
        graded: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page 3",
        graded: true
      )

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          page_1_revision.resource_id,
          page_2_revision.resource_id,
          page_3_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2,
        certificate_enabled: true
      )

    {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_pages(section)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_objectives(section)

    # enroll a student
    student = insert(:user)
    enroll_user_to_section(student, section, :context_learner)

    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      student: student
    }
  end
end
