defmodule Oli.Analytics.XAPI.StatementBundle do
  # XAPI statements get bundled and stored in S3 in JSON Lines format.

  # The pathing structure is:
  # bucket/<partition>/<partition_id>/<category>/<timestamp>_<bundle_id>.jsonl
  #
  # Where partition is :section or :project to differentiate broadly between authoring
  # and delivery statement bundles. The partition_id is the id of the section or project.
  # The category is the type of statement bundle (which itself can contain xapi messages of various
  # sub types), such as :attempt_evaluated or :page_viewed.

  @derive {Jason.Encoder, only: [:partition, :partition_id, :category, :bundle_id, :body]}
  defstruct [
    :partition,
    :partition_id,
    :category,
    :bundle_id,
    :body
  ]

end
