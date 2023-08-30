defmodule Oli.Analytics.XAPI.Statement do

  # XAPI statements get stored in a hierarchy of folders in S3
  # bucket/<category>/<category_id>/<type>/<type_id>.json
  #
  # Where category is "section" or "project" to differentiate broadly between authoring
  # and delivery xAPI statements. The category_id is the slug of the section or project.
  # The type is the type of statement, such as "part_attempt_evaluated" or "attempt_evaluated". The

  defstruct [
    :category,
    :category_id,
    :type_id,
    :type,
    :body
  ]

end
