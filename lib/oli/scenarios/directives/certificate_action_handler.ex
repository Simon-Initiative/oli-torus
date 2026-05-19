defmodule Oli.Scenarios.Directives.CertificateActionHandler do
  @moduledoc """
  Applies instructor certificate approve or deny actions below the UI boundary.
  """

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Scenarios.DirectiveTypes.{CertificateActionDirective, ExecutionState}
  alias Oli.Scenarios.Engine
  alias Oli.Repo

  def handle(
        %CertificateActionDirective{
          instructor: instructor_name,
          section: section_name,
          student: student_name,
          action: action
        },
        %ExecutionState{} = state
      ) do
    with {:ok, instructor} <- fetch_user(state, instructor_name),
         {:ok, student} <- fetch_user(state, student_name),
         {:ok, section} <- fetch_section(state, section_name),
         certificate when not is_nil(certificate) <-
           Certificates.get_certificate_by(%{section_id: section.id}) do
      apply_action(certificate, student, instructor, action)
      {:ok, state}
    else
      nil ->
        {:error, "Certificate not found for section '#{section_name}'"}

      {:error, reason} ->
        {:error, "Failed to apply certificate action: #{inspect(reason)}"}
    end
  end

  defp apply_action(certificate, student, instructor, action) do
    required_state = if action == :approve, do: :earned, else: :denied

    existing =
      Repo.get_by(GrantedCertificate,
        certificate_id: certificate.id,
        user_id: student.id
      )

    case existing do
      nil ->
        GrantedCertificates.create_granted_certificate(
          %{
            user_id: student.id,
            certificate_id: certificate.id,
            state: required_state,
            with_distinction: false,
            guid: UUID.uuid4(),
            issued_by: instructor.id,
            issued_by_type: :user,
            issued_at: DateTime.utc_now(),
            url: nil
          },
          send_email?: false
        )

      granted_certificate ->
        GrantedCertificates.update_granted_certificate(granted_certificate.id, %{
          state: required_state,
          url: nil,
          student_email_sent: false,
          guid: UUID.uuid4()
        })
    end
  end

  defp fetch_user(state, name) do
    case Engine.get_user(state, name) do
      nil -> {:error, "User '#{name}' not found"}
      user -> {:ok, user}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end
end
