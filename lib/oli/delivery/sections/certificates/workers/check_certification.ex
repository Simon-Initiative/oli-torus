defmodule Oli.Delivery.Sections.Certificates.Workers.CheckCertification do
  @moduledoc """
  Worker responsible for checking if a user qualifies for a certificate in a specific section.
  """
  use Oban.Worker,
    queue: :certificate_eligibility,
    unique: [
      keys: [:user_id, :section_id],
      # Prevents duplicate jobs in these states
      states: [:available, :scheduled, :retryable],
      period: :infinity
    ],
    max_attempts: 1

  alias Oli.Delivery.GrantedCertificates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "section_id" => section_id}}) do
    GrantedCertificates.has_qualified(user_id, section_id)

    :ok
  end
end
