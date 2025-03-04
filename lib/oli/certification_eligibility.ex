defmodule Oli.CertificationEligibility do
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.Workers.CheckCertification
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post

  def update_resource_access_and_verify_qualification(access, attrs) do
    %{user_id: user_id, section_id: section_id} = access
    result = Oli.Delivery.Attempts.Core.update_resource_access(access, attrs)

    pre_check_needed? = GrantedCertificates.pre_check_eligibility_needed?(user_id, section_id)

    if pre_check_needed? do
      case result do
        {:ok, resource_access} -> enqueue_certification_check_if_applicable(resource_access)
        _ -> :do_nothing
      end
    end

    result
  end

  @doc """
  Creates a post and optionally verifies the user's qualification.

  ## Parameters
    - `params` (map): The attributes for creating the post.
    - `verify_qualification` (boolean): If `true`, a background worker may be triggered
      to check the user's certification status.

  ## Returns
    - `{:ok, Post.t()}` if the post is created successfully.
    - `{:error, changeset}` if the post creation fails.
  """
  @spec create_post_and_verify_qualification(params, require_certification_check) ::
          {:ok, %Post{}} | {:error, %Ecto.Changeset{}}
        when params: map(), require_certification_check: boolean()
  def create_post_and_verify_qualification(params, false) do
    Collaboration.create_post(params)
  end

  def create_post_and_verify_qualification(params, true) do
    result = Collaboration.create_post(params)

    case result do
      {:ok, post} -> enqueue_certification_check_if_applicable(post)
    end

    result
  end

  _docp = """
  Determines whether to enqueue a certification check based on the type of post or resource.

  - **Discussion Post**: Runs the worker if `annotated_resource_id` is `nil`.
  - **Note**: Runs the worker if visibility is set to `:public`.
  - **Graded Page**: Runs the worker for `ResourceAccess` records.
  - **Global Bypass**: Does nothing for other cases.

  ## Parameters
    - `struct` (Post.t() | ResourceAccess.t()): The post or resource to evaluate.

  ## Returns
    - `:ok` if a worker is enqueued.
    - `:do_nothing` if no action is needed.
  """

  defp enqueue_certification_check(user_id, section_id) do
    CheckCertification.restart_certificate_check(user_id, section_id)
  end

  # Case: Discussion Post
  defp enqueue_certification_check_if_applicable(%Post{annotated_resource_id: nil} = post) do
    %{user_id: user_id, section_id: section_id} = post
    enqueue_certification_check(user_id, section_id)
  end

  # Case: Class Note
  defp enqueue_certification_check_if_applicable(%Post{visibility: :public} = post) do
    %{user_id: user_id, section_id: section_id} = post
    enqueue_certification_check(user_id, section_id)
  end

  # Case: Graded Page
  defp enqueue_certification_check_if_applicable(%ResourceAccess{} = resource_access) do
    %{user_id: user_id, section_id: section_id} = resource_access
    enqueue_certification_check(user_id, section_id)
  end

  # Case: Global bypass
  defp enqueue_certification_check_if_applicable(_struct) do
    :do_nothing
  end
end
