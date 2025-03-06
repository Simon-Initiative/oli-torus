defmodule Oli.Delivery.CertificatesTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting

  @valid_attrs %{
    required_discussion_posts: 1,
    required_class_notes: 1,
    min_percentage_for_completion: 70,
    min_percentage_for_distinction: 90,
    title: "Certificate Title",
    description: "Certificate Description"
  }

  @invalid_attrs %{field: nil}

  describe "create/1" do
    setup do
      {:ok, section: insert(:section)}
    end

    test "creates a certificate with valid attributes", %{section: section} do
      assert {:ok, %Certificate{} = certificate} =
               Map.put(@valid_attrs, :section_id, section.id)
               |> Certificates.create()

      assert certificate.title == "Certificate Title"
    end

    test "returns error changeset with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} = Certificates.create(@invalid_attrs)
    end
  end

  describe "get_certificate/1" do
    test "returns a certificate when given a valid ID" do
      certificate = insert(:certificate)
      fetched_certificate = Certificates.get_certificate(certificate.id)
      assert fetched_certificate.id == certificate.id
    end

    test "returns nil when given an invalid ID" do
      assert Certificates.get_certificate(-1) == nil
    end
  end

  describe "get_certificate_by/1" do
    test "retrieves a certificate by given parameters" do
      certificate = insert(:certificate, @valid_attrs)

      fetched_certificate = Certificates.get_certificate_by(%{title: "Certificate Title"})

      assert fetched_certificate.id == certificate.id
      assert fetched_certificate.title == "Certificate Title"
    end

    test "returns nil if no certificate matches the given parameters" do
      _certificate = insert(:certificate, @valid_attrs)

      refute Certificates.get_certificate_by(%{title: "Different Title"})
    end
  end

  describe "browse_granted_certificates/4" do
    setup [:build_granted_certificates]

    test "applies limit but retains the total record count", ctx do
      %{sorting: sorting, section: section} = ctx
      paging = %{ctx.paging | limit: 1}

      assert [%{total_count: 2}] =
               Certificates.browse_granted_certificates(paging, sorting, "Instru", section)
    end

    test "filters by recipient type user", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx
      gc = Certificates.browse_granted_certificates(paging, sorting, "Instru", section)
      assert length(gc) == 2
    end

    test "filters by recipient type author", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx
      gc = Certificates.browse_granted_certificates(paging, sorting, "Adm", section)
      assert length(gc) == 1
    end

    test "filters by target student", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx

      [%{recipient: %{name: "Student_2"}}] =
        Certificates.browse_granted_certificates(paging, sorting, "Student_2", section)
    end

    test "gets all records when text_search is nil or an empty string", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx
      gc = Certificates.browse_granted_certificates(paging, sorting, " ", section)
      assert length(gc) == 3

      gc = Certificates.browse_granted_certificates(paging, sorting, nil, section)
      assert length(gc) == 3
    end

    test "sorts by issuer", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx
      sorting = %{sorting | field: :issuer, direction: :asc}

      assert [
               %{issuer: %{name: "Admin_1"}},
               %{issuer: %{name: "Instructor_1"}},
               %{issuer: %{name: "Instructor_2"}}
             ] =
               Certificates.browse_granted_certificates(paging, sorting, nil, section)

      sorting = %{sorting | field: :issuer, direction: :desc}

      assert [
               %{issuer: %{name: "Instructor_2"}},
               %{issuer: %{name: "Instructor_1"}},
               %{issuer: %{name: "Admin_1"}}
             ] =
               Certificates.browse_granted_certificates(paging, sorting, nil, section)
    end

    test "sorts by recipient", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx
      sorting = %{sorting | field: :recipient, direction: :asc}

      assert [
               %{recipient: %{name: "Student_1"}},
               %{recipient: %{name: "Student_2"}},
               %{recipient: %{name: "Student_3"}}
             ] =
               Certificates.browse_granted_certificates(paging, sorting, nil, section)

      sorting = %{sorting | field: :recipient, direction: :desc}

      assert [
               %{recipient: %{name: "Student_3"}},
               %{recipient: %{name: "Student_2"}},
               %{recipient: %{name: "Student_1"}}
             ] =
               Certificates.browse_granted_certificates(paging, sorting, nil, section)
    end

    test "sorts by issued_at", ctx do
      %{sorting: sorting, paging: paging, section: section} = ctx
      sorting = %{sorting | field: :issued_at, direction: :asc}
      issued_at_1 = ctx.gc_1.issued_at
      issued_at_2 = ctx.gc_2.issued_at
      issued_at_3 = ctx.gc_3.issued_at

      assert [
               %{issued_at: ^issued_at_3},
               %{issued_at: ^issued_at_2},
               %{issued_at: ^issued_at_1}
             ] =
               Certificates.browse_granted_certificates(paging, sorting, nil, section)

      sorting = %{sorting | field: :issued_at, direction: :desc}

      assert [
               %{issued_at: ^issued_at_1},
               %{issued_at: ^issued_at_2},
               %{issued_at: ^issued_at_3}
             ] =
               Certificates.browse_granted_certificates(paging, sorting, nil, section)
    end

    test "lists certificates of courses based on that product", ctx do
      %{paging: paging, section: section, gc_from_another_product: gc_from_another_product} = ctx

      certificates =
        Certificates.browse_granted_certificates(
          paging,
          %Sorting{direction: :asc, field: :recipient},
          nil,
          section
        )

      assert length(certificates) == 3

      refute Enum.any?(certificates, fn gc ->
               gc.recipient.name == gc_from_another_product.user.name
             end)
    end

    test "does not list certificates with state != :earned", ctx do
      %{paging: paging, section: section, denied_gc: denied_gc} = ctx

      certificates =
        Certificates.browse_granted_certificates(
          paging,
          %Sorting{direction: :asc, field: :recipient},
          nil,
          section
        )

      assert length(certificates) == 3

      refute Enum.any?(certificates, fn gc ->
               gc.recipient.name == denied_gc.user.name
             end)
    end
  end

  describe "get_granted_certificates_by_section_id/1 and /2" do
    setup [:build_granted_certificates]

    test "returns the granted certificates for a given section", ctx do
      %{section: section} = ctx

      granted_certificates = Certificates.get_granted_certificates_by_section_id(section.id)

      # includes all granted certificates, despite its state
      # granted certificate 5 should not be listed since it does not belong to the section
      assert length(granted_certificates) == 4

      # granted certificate 4 should not be listed since it has been denied
      earned_granted_certificates =
        Certificates.get_granted_certificates_by_section_id(section.id,
          filter_by_state: [:earned]
        )

      assert length(earned_granted_certificates) == 3

      denied_granted_certificates =
        Certificates.get_granted_certificates_by_section_id(section.id,
          filter_by_state: [:denied]
        )

      assert length(denied_granted_certificates) == 1
    end

    test "returns the granted certificates for a given product", ctx do
      # when the section is a product, the function returns all granted certificates of the courses based on that product

      %{product: product} = ctx

      granted_certificates = Certificates.get_granted_certificates_by_section_id(product.id)

      # includes all granted certificates, despite its state
      # granted certificate 5 should not be listed since it does not belong to the product
      assert length(granted_certificates) == 4

      # granted certificate 4 should not be listed since it has been denied
      earned_granted_certificates =
        Certificates.get_granted_certificates_by_section_id(product.id,
          filter_by_state: [:earned]
        )

      assert length(earned_granted_certificates) == 3

      denied_granted_certificates =
        Certificates.get_granted_certificates_by_section_id(product.id,
          filter_by_state: [:denied]
        )

      assert length(denied_granted_certificates) == 1
    end
  end

  describe "user_certificate_discussion_posts_count/2" do
    test "returns the number of discussion posts for a user in a section" do
      user = insert(:user)
      section = insert(:section)
      another_section = insert(:section)

      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Other revision A"
        )

      insert(:post, user: user, section: section, annotated_resource_id: nil)
      insert(:post, user: user, section: section, annotated_resource_id: nil)
      insert(:post, user: user, section: section, annotated_resource_id: nil)
      insert(:post, user: user, section: another_section, annotated_resource_id: nil)

      insert(:post,
        user: user,
        section: section,
        annotated_resource_id: page_revision.resource_id
      )

      assert Certificates.user_certificate_discussion_posts_count(user.id, section.id) == 3
    end
  end

  describe "user_certificate_class_notes_count/2" do
    test "returns the number of class notes for a user in a section" do
      user = insert(:user)
      section = insert(:section)
      another_section = insert(:section)

      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Other revision A"
        )

      _student_note =
        insert(:post,
          user: user,
          section: section,
          annotated_resource_id: page_revision.resource_id,
          visibility: :private
        )

      insert(:post,
        user: user,
        section: section,
        annotated_resource_id: page_revision.resource_id,
        visibility: :public
      )

      insert(:post,
        user: user,
        section: section,
        annotated_resource_id: page_revision.resource_id,
        visibility: :public
      )

      insert(:post,
        user: user,
        section: another_section,
        annotated_resource_id: page_revision.resource_id,
        visibility: :public
      )

      assert Certificates.user_certificate_class_notes_count(user.id, section.id) == 2
    end
  end

  describe "completed_assignments_count/4" do
    test "returns the number of assignments that acomplish the required_percentage" do
      user = insert(:user)
      section = insert(:section)

      page_revision_1 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Other revision A",
          graded: true
        )

      page_revision_2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Other revision B",
          graded: true
        )

      page_revision_3 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Other revision C",
          graded: true
        )

      insert(:resource_access,
        user: user,
        section: section,
        resource: page_revision_1.resource,
        score: 3.0,
        out_of: 4.0
      )

      insert(:resource_access,
        user: user,
        section: section,
        resource: page_revision_2.resource,
        score: 2.0,
        out_of: 4.0
      )

      insert(:resource_access,
        user: user,
        section: section,
        resource: page_revision_3.resource,
        score: 4.0,
        out_of: 4.0
      )

      assert Certificates.completed_assignments_count(
               user.id,
               section.id,
               [
                 page_revision_1.resource_id,
                 page_revision_2.resource_id,
                 page_revision_3.resource_id
               ],
               75
             ) == 2

      assert Certificates.completed_assignments_count(
               user.id,
               section.id,
               [
                 page_revision_1.resource_id,
                 page_revision_2.resource_id,
                 page_revision_3.resource_id
               ],
               80
             ) == 1

      assert Certificates.completed_assignments_count(
               user.id,
               section.id,
               [
                 page_revision_1.resource_id,
                 page_revision_2.resource_id,
                 page_revision_3.resource_id
               ],
               49
             ) == 3

      assert Certificates.completed_assignments_count(
               user.id,
               section.id,
               [
                 page_revision_2.resource_id
               ],
               60
             ) == 0
    end
  end

  describe "raw_student_certificate_progress/2" do
    setup [:create_elixir_project]

    test "returns the raw progress considering the student progress and the certificate configuration",
         %{
           section: section,
           student: student,
           page_1: page_1,
           page_2: page_2
         } do
      certificate =
        insert(:certificate,
          section: section,
          required_discussion_posts: 2,
          required_class_notes: 10,
          min_percentage_for_completion: 70,
          min_percentage_for_distinction: 90,
          assessments_apply_to: :all
        )

      ## class note
      insert(:post, user: student, section: section, annotated_resource_id: page_1.resource_id)
      ## course discussion
      insert(:post, user: student, section: section, annotated_resource_id: nil)
      ## required assessments
      insert(:resource_access,
        user: student,
        section: section,
        resource: page_1.resource,
        score: 3.0,
        out_of: 4.0
      )

      # this one should not count since it has not acomplished the required percentage
      insert(:resource_access,
        user: student,
        section: section,
        resource: page_2.resource,
        score: 2.0,
        out_of: 4.0
      )

      raw_progress = Certificates.raw_student_certificate_progress(student.id, section.id)

      assert raw_progress.class_notes.total == certificate.required_class_notes
      assert raw_progress.discussion_posts.total == certificate.required_discussion_posts

      # matches the amount of graded pages in the curriculum (since no custom list of assignments was provided in the certificate)
      assert raw_progress.required_assignments.total == 3

      assert raw_progress.class_notes.completed == 1
      assert raw_progress.discussion_posts.completed == 1
      assert raw_progress.required_assignments.completed == 1
    end

    test "returns the raw progress considering the certificate configuration when a set of custom_assessments is provided",
         %{
           section: section,
           student: student,
           page_1: page_1,
           page_2: page_2
         } do
      certificate =
        insert(:certificate,
          section: section,
          required_discussion_posts: 2,
          required_class_notes: 10,
          min_percentage_for_completion: 70,
          min_percentage_for_distinction: 90,
          assessments_apply_to: :custom,
          custom_assessments: [
            page_1.resource_id,
            page_2.resource_id
          ]
        )

      ## class note
      insert(:post, user: student, section: section, annotated_resource_id: page_1.resource_id)
      ## course discussion
      insert(:post, user: student, section: section, annotated_resource_id: nil)
      ## required assessments
      insert(:resource_access,
        user: student,
        section: section,
        resource: page_1.resource,
        score: 3.0,
        out_of: 4.0
      )

      # this one should not count since it has not acomplished the required percentage
      insert(:resource_access,
        user: student,
        section: section,
        resource: page_2.resource,
        score: 2.0,
        out_of: 4.0
      )

      raw_progress = Certificates.raw_student_certificate_progress(student.id, section.id)

      assert raw_progress.class_notes.total == certificate.required_class_notes
      assert raw_progress.discussion_posts.total == certificate.required_discussion_posts

      # matches the amount of graded pages provided in the custom list of assignments
      assert raw_progress.required_assignments.total == 2

      assert raw_progress.class_notes.completed == 1
      assert raw_progress.discussion_posts.completed == 1
      assert raw_progress.required_assignments.completed == 1
    end

    test "returns the raw progress considering if the student has already a certificate :earned",
         %{
           section: section,
           student: student
         } do
      certificate =
        insert(:certificate,
          section: section,
          required_discussion_posts: 2,
          required_class_notes: 10,
          min_percentage_for_completion: 70,
          min_percentage_for_distinction: 90,
          assessments_apply_to: :all
        )

      insert(:granted_certificate, user: student, certificate: certificate, state: :earned)

      raw_progress =
        Certificates.raw_student_certificate_progress(student.id, section.id)

      assert raw_progress.class_notes.total == certificate.required_class_notes
      assert raw_progress.class_notes.completed == certificate.required_class_notes

      assert raw_progress.discussion_posts.total == certificate.required_discussion_posts
      assert raw_progress.discussion_posts.completed == certificate.required_discussion_posts

      assert raw_progress.required_assignments.total == 3
      assert raw_progress.required_assignments.completed == 3
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
        analytics_version: :v2
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

  defp build_granted_certificates(_) do
    product = insert(:section, type: :blueprint)

    section_based_on_product = insert(:section, type: :enrollable, blueprint_id: product.id)

    another_product = insert(:section, type: :blueprint)

    section_based_on_another_product =
      insert(:section, type: :enrollable, blueprint_id: another_product.id)

    certificate = insert(:certificate, section: section_based_on_product)

    certificate_from_another_product =
      insert(:certificate, section: section_based_on_another_product)

    instructor_1 = insert(:user, name: "Instructor_1")
    instructor_2 = insert(:user, name: "Instructor_2")
    author = insert(:author, name: "Admin_1")

    recipient_1 = insert(:user, name: "Student_1")
    recipient_2 = insert(:user, name: "Student_2")
    recipient_3 = insert(:user, name: "Student_3")
    recipient_4 = insert(:user, name: "Student_4")
    recipient_5 = insert(:user, name: "Student_5")

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    a_minute_ago = DateTime.add(now, -60, :second)
    an_hour_ago = DateTime.add(now, -60, :minute)

    gc_1 =
      insert(:granted_certificate,
        user: recipient_1,
        certificate: certificate,
        issued_by_type: :user,
        issued_by: instructor_1.id,
        issued_at: now,
        state: :earned
      )

    gc_2 =
      insert(:granted_certificate,
        user: recipient_2,
        certificate: certificate,
        issued_by_type: :author,
        issued_by: author.id,
        issued_at: a_minute_ago,
        state: :earned
      )

    gc_3 =
      insert(:granted_certificate,
        user: recipient_3,
        certificate: certificate,
        issued_by_type: :user,
        issued_by: instructor_2.id,
        issued_at: an_hour_ago,
        state: :earned
      )

    # this one should not be listed since it has been denied
    gc_4 =
      insert(:granted_certificate,
        user: recipient_4,
        certificate: certificate,
        issued_by_type: :user,
        issued_by: instructor_2.id,
        issued_at: an_hour_ago,
        state: :denied
      )

    # this one should not be listed since it belongs to another product
    gc_5 =
      insert(:granted_certificate,
        user: recipient_5,
        certificate: certificate_from_another_product,
        issued_by_type: :user,
        issued_by: instructor_2.id,
        issued_at: an_hour_ago
      )

    limit = 25
    offset = 0
    direction = :asc
    field = :issuer

    paging = %Paging{limit: limit, offset: offset}
    sorting = %Sorting{direction: direction, field: field}

    %{
      paging: paging,
      sorting: sorting,
      product: product,
      section: section_based_on_product,
      gc_1: gc_1,
      gc_2: gc_2,
      gc_3: gc_3,
      denied_gc: gc_4,
      gc_from_another_product: gc_5
    }
  end
end
