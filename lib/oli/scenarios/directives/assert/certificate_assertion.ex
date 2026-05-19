defmodule Oli.Scenarios.Directives.Assert.CertificateAssertion do
  @moduledoc """
  Handles certificate-specific assertions for section configuration and learner state.
  """

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers
  alias Oli.Scenarios.Directives.CertificateSupport

  def assert(%AssertDirective{certificate: certificate_data}, state)
      when is_map(certificate_data) do
    with {:ok, section} <- Helpers.get_section(state, certificate_data.section),
         {:ok, student} <- maybe_get_student(state, certificate_data.student),
         verification_result <- verify(section, student, certificate_data) do
      {:ok, state, verification_result}
    else
      {:error, reason} ->
        {:error, "Failed to assert certificate: #{reason}"}
    end
  end

  def assert(%AssertDirective{certificate: nil}, state), do: {:ok, state, nil}

  defp verify(section, student, certificate_data) do
    certificate = Certificates.get_certificate_by(%{section_id: section.id})

    progress =
      if student,
        do: Certificates.raw_student_certificate_progress(student.id, section.id),
        else: nil

    granted_certificate =
      if student && progress[:granted_certificate_guid],
        do:
          GrantedCertificates.get_granted_certificate_by_guid(progress[:granted_certificate_guid]),
        else: nil

    checks =
      [
        check_enabled(section, certificate_data),
        check_thresholds(certificate, certificate_data),
        check_design(certificate, certificate_data),
        check_progress(progress, certificate_data),
        check_state(granted_certificate, certificate_data),
        check_distinction(granted_certificate, certificate_data),
        check_scored_pages(section, certificate, certificate_data)
      ]
      |> Enum.reject(&(&1 == :ok))

    case checks do
      [] ->
        %VerificationResult{
          to: certificate_data.section,
          passed: true,
          message: "Certificate assertion passed for '#{certificate_data.section}'"
        }

      failures ->
        %VerificationResult{
          to: certificate_data.section,
          passed: false,
          message: Enum.join(failures, "; ")
        }
    end
  end

  defp maybe_get_student(_state, nil), do: {:ok, nil}
  defp maybe_get_student(state, student_name), do: Helpers.get_user(state, student_name)

  defp check_enabled(_section, %{enabled: nil}), do: :ok

  defp check_enabled(section, %{enabled: expected}) do
    if section.certificate_enabled == expected,
      do: :ok,
      else: "expected certificate_enabled=#{expected}, got #{section.certificate_enabled}"
  end

  defp check_thresholds(nil, certificate_data) do
    if expects_thresholds?(certificate_data), do: "certificate record not found", else: :ok
  end

  defp check_thresholds(certificate, certificate_data) do
    failures =
      [
        compare_field(
          certificate.required_discussion_posts,
          certificate_data.required_discussion_posts,
          "required_discussion_posts"
        ),
        compare_field(
          certificate.required_class_notes,
          certificate_data.required_class_notes,
          "required_class_notes"
        ),
        compare_field(
          certificate.min_percentage_for_completion,
          certificate_data.min_percentage_for_completion,
          "min_percentage_for_completion"
        ),
        compare_field(
          certificate.min_percentage_for_distinction,
          certificate_data.min_percentage_for_distinction,
          "min_percentage_for_distinction"
        ),
        compare_field(
          certificate.requires_instructor_approval,
          certificate_data.requires_instructor_approval,
          "requires_instructor_approval"
        ),
        compare_field(
          to_string(certificate.assessments_apply_to),
          certificate_data.assessments_apply_to,
          "assessments_apply_to"
        )
      ]
      |> Enum.reject(&is_nil/1)

    if failures == [], do: :ok, else: Enum.join(failures, ", ")
  end

  defp check_design(nil, certificate_data) do
    if expects_design?(certificate_data), do: "certificate record not found", else: :ok
  end

  defp check_design(certificate, certificate_data) do
    failures =
      [
        compare_field(certificate.title, certificate_data.title, "title"),
        compare_field(certificate.description, certificate_data.description, "description"),
        compare_field(certificate.admin_name1, certificate_data.admin_name1, "admin_name1"),
        compare_field(certificate.admin_title1, certificate_data.admin_title1, "admin_title1"),
        compare_field(certificate.admin_name2, certificate_data.admin_name2, "admin_name2"),
        compare_field(certificate.admin_title2, certificate_data.admin_title2, "admin_title2"),
        compare_field(certificate.admin_name3, certificate_data.admin_name3, "admin_name3"),
        compare_field(certificate.admin_title3, certificate_data.admin_title3, "admin_title3")
      ]
      |> Enum.reject(&is_nil/1)

    if failures == [], do: :ok, else: Enum.join(failures, ", ")
  end

  defp check_progress(nil, %{progress: nil}), do: :ok
  defp check_progress(nil, _certificate_data), do: "student certificate progress is unavailable"
  defp check_progress(_progress, %{progress: nil}), do: :ok

  defp check_progress(progress, %{progress: expected_progress}) do
    failures =
      [
        compare_progress_bucket(
          progress.discussion_posts,
          expected_progress[:discussion_posts],
          "discussion_posts"
        ),
        compare_progress_bucket(
          progress.class_notes,
          expected_progress[:class_notes],
          "class_notes"
        ),
        compare_progress_bucket(
          progress.required_assignments,
          expected_progress[:required_assignments],
          "required_assignments"
        )
      ]
      |> Enum.reject(&is_nil/1)

    if failures == [], do: :ok, else: Enum.join(failures, ", ")
  end

  defp check_state(_granted_certificate, %{state: nil}), do: :ok

  defp check_state(nil, %{state: :none}), do: :ok

  defp check_state(nil, %{state: expected}),
    do: "expected granted certificate state #{expected}, got none"

  defp check_state(granted_certificate, %{state: expected}) do
    if granted_certificate.state == expected,
      do: :ok,
      else: "expected granted certificate state #{expected}, got #{granted_certificate.state}"
  end

  defp check_distinction(_granted_certificate, %{with_distinction: nil}), do: :ok
  defp check_distinction(nil, _certificate_data), do: "granted certificate not found"

  defp check_distinction(granted_certificate, %{with_distinction: expected}) do
    if granted_certificate.with_distinction == expected,
      do: :ok,
      else: "expected with_distinction=#{expected}, got #{granted_certificate.with_distinction}"
  end

  defp check_scored_pages(_section, _certificate, %{scored_pages: nil}), do: :ok
  defp check_scored_pages(_section, nil, _certificate_data), do: "certificate record not found"

  defp check_scored_pages(section, certificate, %{scored_pages: expected_titles}) do
    actual_titles =
      CertificateSupport.resource_titles_for_ids(section, certificate.custom_assessments)

    if Enum.sort(actual_titles) == Enum.sort(expected_titles),
      do: :ok,
      else: "expected scored_pages=#{inspect(expected_titles)}, got #{inspect(actual_titles)}"
  end

  defp compare_progress_bucket(_actual, nil, _label), do: nil

  defp compare_progress_bucket(actual, expected, label) do
    [
      compare_field(actual.completed, expected.completed, "#{label}.completed"),
      compare_field(actual.total, expected.total, "#{label}.total")
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      failures -> Enum.join(failures, ", ")
    end
  end

  defp compare_field(_actual, nil, _label), do: nil

  defp compare_field(actual, expected, label) do
    if actual == expected,
      do: nil,
      else: "expected #{label}=#{inspect(expected)}, got #{inspect(actual)}"
  end

  defp expects_thresholds?(certificate_data) do
    Enum.any?([
      certificate_data.required_discussion_posts,
      certificate_data.required_class_notes,
      certificate_data.min_percentage_for_completion,
      certificate_data.min_percentage_for_distinction,
      certificate_data.requires_instructor_approval,
      certificate_data.assessments_apply_to,
      certificate_data.scored_pages
    ])
  end

  defp expects_design?(certificate_data) do
    Enum.any?([
      certificate_data.title,
      certificate_data.description,
      certificate_data.admin_name1,
      certificate_data.admin_title1,
      certificate_data.admin_name2,
      certificate_data.admin_title2,
      certificate_data.admin_name3,
      certificate_data.admin_title3
    ])
  end
end
