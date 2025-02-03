defmodule Oli.Delivery.Sections.CertificateTest do
  use Oli.DataCase, async: true

  alias Oli.Delivery.Sections.Certificate

  describe "changeset/2" do
    setup [:valid_params]

    test "success: with valid params", %{params: params} do
      changeset = %Ecto.Changeset{} = Certificate.changeset(params)

      assert changeset.valid?
    end

    test "check: assessments_apply_to default value", %{params: params} do
      params = Map.delete(params, :assessments_apply_to)
      refute Map.has_key?(params, :assessments_apply_to)

      certificate = Certificate.changeset(params) |> apply_changes()

      assert certificate.assessments_apply_to == :all
    end

    test "check: custom_assessments default value", %{params: params} do
      params = Map.delete(params, :custom_assessments)
      refute Map.has_key?(params, :custom_assessments)

      certificate = Certificate.changeset(params) |> apply_changes()

      assert certificate.custom_assessments == []
    end

    test "check: requires_instructor_approval default value", %{params: params} do
      params = Map.delete(params, :requires_instructor_approval)
      refute Map.has_key?(params, :requires_instructor_approval)

      certificate = Certificate.changeset(params) |> apply_changes()

      assert certificate.requires_instructor_approval == false
    end

    test "error: fails when doesn't have the required fields" do
      params = %{}

      changeset = %Ecto.Changeset{errors: errors} = Certificate.changeset(params)

      refute changeset.valid?
      assert length(errors) == 7

      assert %{title: ["can't be blank"]} = errors_on(changeset)
      assert %{description: ["can't be blank"]} = errors_on(changeset)
      assert %{section_id: ["can't be blank"]} = errors_on(changeset)
      assert %{required_discussion_posts: ["can't be blank"]} = errors_on(changeset)
      assert %{required_class_notes: ["can't be blank"]} = errors_on(changeset)
      assert %{min_percentage_for_completion: ["can't be blank"]} = errors_on(changeset)
      assert %{min_percentage_for_distinction: ["can't be blank"]} = errors_on(changeset)
    end

    test "success: when distinction > completion", %{params: params} do
      params = %{params | min_percentage_for_distinction: 0.7, min_percentage_for_completion: 0.6}

      changeset = %Ecto.Changeset{} = Certificate.changeset(params)

      assert changeset.valid?
    end

    test "success: when distinction = completion", %{params: params} do
      params = %{params | min_percentage_for_distinction: 0.7, min_percentage_for_completion: 0.7}

      changeset = %Ecto.Changeset{} = Certificate.changeset(params)

      assert changeset.valid?
    end

    test "success: a certificate has a one-to-one association with a granted certificate" do
      assert Map.has_key?(%Certificate{}, :granted_certificate)
    end

    test "error: when distinction < completion", %{params: params} do
      params = %{params | min_percentage_for_distinction: 0.6, min_percentage_for_completion: 0.7}

      changeset = %Ecto.Changeset{} = Certificate.changeset(params)

      refute changeset.valid?

      assert %{
               min_percentage_for_completion: [
                 "Min percentage for distinction must be greater than Min percentage for completion"
               ]
             } = errors_on(changeset)
    end

    test "error: incorrect assessments_apply_to type definition", %{params: params} do
      params = %{params | assessments_apply_to: "incorrect_type"}

      changeset = %Ecto.Changeset{} = Certificate.changeset(params)

      refute changeset.valid?

      assert %{assessments_apply_to: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "insert" do
    setup [:valid_params]

    test "error: missing section association", %{params: params} do
      {:error, changeset = %Ecto.Changeset{}} = Certificate.changeset(params) |> Oli.Repo.insert()

      refute changeset.valid?

      assert %{section: ["does not exist"]} = errors_on(changeset)
    end
  end

  defp valid_params(_) do
    params = %{
      required_discussion_posts: 11,
      min_percentage_for_completion: 0.6,
      min_percentage_for_distinction: 0.7,
      required_class_notes: 12,
      title: "My Certificate",
      description: "Some description",
      section_id: 123,
      assessments_apply_to: :all
    }

    %{params: params}
  end
end
