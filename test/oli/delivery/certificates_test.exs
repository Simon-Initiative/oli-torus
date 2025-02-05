defmodule Oli.Delivery.CertificatesTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.Sections.Certificate

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
end
