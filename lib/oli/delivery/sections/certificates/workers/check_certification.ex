defmodule Oli.Delivery.Sections.Certificates.Workers.CheckCertification do
  use Oban.Worker,
    queue: :certificate_eligibility,
    unique: [keys: [:user_id, :section_id]],
    max_attempts: 1

  alias Oli.Delivery.GrantedCertificates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "section_id" => section_id}}) do
    GrantedCertificates.has_qualified(user_id, section_id)

    :ok
  end
end
