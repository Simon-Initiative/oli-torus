defmodule Oli.Delivery.Sections.GrantedCertificateTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Oli.Delivery.Sections.GrantedCertificate

  describe "changeset" do
    setup [:valid_params]

    test "success: with valid params", %{params: params} do
      changeset = GrantedCertificate.changeset(params)

      assert changeset.valid?
    end

    test "check: issued_by_type default value", %{params: params} do
      params = Map.delete(params, :issued_by_type)
      refute Map.has_key?(params, :issued_by_type)

      granted_certificate = GrantedCertificate.changeset(params) |> apply_changes()

      assert granted_certificate.issued_by_type == :user
    end

    test "error: fails with invalid params" do
      params = %{}

      changeset = %Ecto.Changeset{errors: errors} = GrantedCertificate.changeset(params)

      refute changeset.valid?
      assert length(errors) == 5

      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
      assert %{certificate_id: ["can't be blank"]} = errors_on(changeset)
      assert %{state: ["can't be blank"]} = errors_on(changeset)
      assert %{with_distinction: ["can't be blank"]} = errors_on(changeset)
      assert %{guid: ["can't be blank"]} = errors_on(changeset)
    end

    test "error: incorrect state type definition", %{params: params} do
      params = %{params | state: "incorrect_state"}

      changeset = %Ecto.Changeset{} = GrantedCertificate.changeset(params)

      refute changeset.valid?

      assert %{state: ["is invalid"]} = errors_on(changeset)
    end

    test "error: incorrect issued_by_type type definition", %{params: params} do
      params = %{params | issued_by_type: "incorrect_issue_by_type"}

      changeset = %Ecto.Changeset{} = GrantedCertificate.changeset(params)

      refute changeset.valid?

      assert %{issued_by_type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "insert" do
    setup [:valid_params]

    test "error: missing certificate association", %{params: params} do
      user = insert(:user)
      params = %{params | user_id: user.id}

      {:error, changeset = %Ecto.Changeset{}} =
        GrantedCertificate.changeset(params) |> Oli.Repo.insert()

      refute changeset.valid?

      assert %{certificate: ["does not exist"]} = errors_on(changeset)
    end

    test "error: missing user association", %{params: params} do
      certificate = insert(:certificate)
      params = %{params | certificate_id: certificate.id}

      {:error, changeset = %Ecto.Changeset{}} =
        GrantedCertificate.changeset(params) |> Oli.Repo.insert()

      refute changeset.valid?

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "error: duplicate certificate is not allowed", %{params: params} do
      user = insert(:user)
      certificate = insert(:certificate)

      params = %{params | user_id: user.id, certificate_id: certificate.id}

      {:ok, %GrantedCertificate{}} = GrantedCertificate.changeset(params) |> Oli.Repo.insert()

      {:error, changeset = %Ecto.Changeset{}} =
        GrantedCertificate.changeset(params) |> Oli.Repo.insert()

      refute changeset.valid?

      assert %{user_id: ["has already been granted this type of certificate"]} =
               errors_on(changeset)
    end
  end

  defp valid_params(_) do
    params = %{
      state: :pending,
      with_distinction: false,
      guid: "some_guid",
      issued_by: 11,
      issued_by_type: :user,
      issued_at: DateTime.utc_now(),
      certificate_id: 123,
      user_id: 22
    }

    %{params: params}
  end
end
