defmodule Oli.Delivery.Sections.InvitePartitioner do
  @moduledoc """
  Canonical partitioning for invite candidate emails.
  """

  alias Oli.Accounts
  alias Oli.Delivery.Sections

  @spec partition(String.t(), [String.t()]) :: %{
          enrolled: [String.t()],
          non_existing_users: [String.t()],
          not_enrolled_users: [String.t()],
          pending_confirmation: [String.t()],
          rejected: [String.t()],
          suspended: [String.t()]
        }
  def partition(section_slug, emails) do
    candidate_emails = normalize_emails(emails)

    existing_users =
      candidate_emails
      |> Accounts.get_users_by_email()
      |> Enum.map(&normalize_email(&1.email))
      |> MapSet.new()

    existing_emails = MapSet.to_list(existing_users)

    enrollments_by_emails =
      Sections.get_independent_enrollments_by_emails(section_slug, existing_emails)

    enrollments_by_status =
      enrollments_by_emails
      |> Enum.group_by(& &1.status, fn enrollment -> normalize_email(enrollment.user.email) end)
      |> Map.new(fn {status, status_emails} -> {status, Enum.uniq(status_emails)} end)

    enrolled_emails =
      enrollments_by_emails
      |> Enum.map(&normalize_email(&1.user.email))
      |> MapSet.new()

    existing_without_enrollment =
      candidate_emails
      |> Enum.filter(
        &(MapSet.member?(existing_users, &1) and !MapSet.member?(enrolled_emails, &1))
      )

    non_existing_users =
      candidate_emails
      |> Enum.reject(&MapSet.member?(existing_users, &1))

    %{
      non_existing_users: non_existing_users,
      not_enrolled_users: existing_without_enrollment,
      pending_confirmation: Map.get(enrollments_by_status, :pending_confirmation, []),
      rejected: Map.get(enrollments_by_status, :rejected, []),
      suspended: Map.get(enrollments_by_status, :suspended, []),
      enrolled: Map.get(enrollments_by_status, :enrolled, [])
    }
  end

  @spec normalize_emails([String.t()]) :: [String.t()]
  def normalize_emails(emails) do
    emails
    |> Enum.map(&normalize_email/1)
    |> Enum.uniq()
  end

  defp normalize_email(email) do
    email
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end
