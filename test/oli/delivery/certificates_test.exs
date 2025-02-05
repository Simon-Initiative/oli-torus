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

  describe "browser_granted_certificates/4" do
    setup do
      section = insert(:section)
      certificate = insert(:certificate, section: section)
      instructor_1 = insert(:user, name: "Instructor_1")
      instructor_2 = insert(:user, name: "Instructor_2")
      author = insert(:author, name: "Admin_1")

      recipient_1 = insert(:user, name: "Student_1")
      recipient_2 = insert(:user, name: "Student_2")
      recipient_3 = insert(:user, name: "Student_3")

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      a_minute_ago = DateTime.add(now, -60, :second)
      an_hour_ago = DateTime.add(now, -60, :minute)

      gc_1 =
        insert(:granted_certificate,
          user: recipient_1,
          certificate: certificate,
          issued_by_type: :user,
          issued_by: instructor_1.id,
          issued_at: now
        )

      gc_2 =
        insert(:granted_certificate,
          user: recipient_2,
          certificate: certificate,
          issued_by_type: :author,
          issued_by: author.id,
          issued_at: a_minute_ago
        )

      gc_3 =
        insert(:granted_certificate,
          user: recipient_3,
          certificate: certificate,
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
        section_id: section.id,
        gc_1: gc_1,
        gc_2: gc_2,
        gc_3: gc_3
      }
    end

    test "applies limit but retains the total record count", ctx do
      %{sorting: sorting, section_id: section_id} = ctx
      paging = %{ctx.paging | limit: 1}

      assert [%{total_count: 2}] =
               Certificates.browser_granted_certificates(paging, sorting, "Instru", section_id)
    end

    test "filters by recipient type user", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx
      gc = Certificates.browser_granted_certificates(paging, sorting, "Instru", section_id)
      assert length(gc) == 2
    end

    test "filters by recipient type author", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx
      gc = Certificates.browser_granted_certificates(paging, sorting, "Adm", section_id)
      assert length(gc) == 1
    end

    test "filters by target student", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx

      [%{recipient: %{name: "Student_2"}}] =
        Certificates.browser_granted_certificates(paging, sorting, "Student_2", section_id)
    end

    test "gets all records when text_search is nil or an empty string", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx
      gc = Certificates.browser_granted_certificates(paging, sorting, " ", section_id)
      assert length(gc) == 3

      gc = Certificates.browser_granted_certificates(paging, sorting, nil, section_id)
      assert length(gc) == 3
    end

    test "sorts by issuer", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx
      sorting = %{sorting | field: :issuer, direction: :asc}

      assert [
               %{issuer: %{name: "Admin_1"}},
               %{issuer: %{name: "Instructor_1"}},
               %{issuer: %{name: "Instructor_2"}}
             ] =
               Certificates.browser_granted_certificates(paging, sorting, nil, section_id)

      sorting = %{sorting | field: :issuer, direction: :desc}

      assert [
               %{issuer: %{name: "Instructor_2"}},
               %{issuer: %{name: "Instructor_1"}},
               %{issuer: %{name: "Admin_1"}}
             ] =
               Certificates.browser_granted_certificates(paging, sorting, nil, section_id)
    end

    test "sorts by recipient", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx
      sorting = %{sorting | field: :recipient, direction: :asc}

      assert [
               %{recipient: %{name: "Student_1"}},
               %{recipient: %{name: "Student_2"}},
               %{recipient: %{name: "Student_3"}}
             ] =
               Certificates.browser_granted_certificates(paging, sorting, nil, section_id)

      sorting = %{sorting | field: :recipient, direction: :desc}

      assert [
               %{recipient: %{name: "Student_3"}},
               %{recipient: %{name: "Student_2"}},
               %{recipient: %{name: "Student_1"}}
             ] =
               Certificates.browser_granted_certificates(paging, sorting, nil, section_id)
    end

    test "sorts by issued_at", ctx do
      %{sorting: sorting, paging: paging, section_id: section_id} = ctx
      sorting = %{sorting | field: :issued_at, direction: :asc}
      issued_at_1 = ctx.gc_1.issued_at
      issued_at_2 = ctx.gc_2.issued_at
      issued_at_3 = ctx.gc_3.issued_at

      assert [
               %{issued_at: ^issued_at_3},
               %{issued_at: ^issued_at_2},
               %{issued_at: ^issued_at_1}
             ] =
               Certificates.browser_granted_certificates(paging, sorting, nil, section_id)

      sorting = %{sorting | field: :issued_at, direction: :desc}

      assert [
               %{issued_at: ^issued_at_1},
               %{issued_at: ^issued_at_2},
               %{issued_at: ^issued_at_3}
             ] =
               Certificates.browser_granted_certificates(paging, sorting, nil, section_id)
    end
  end
end
