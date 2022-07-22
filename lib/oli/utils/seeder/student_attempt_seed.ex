defmodule Oli.Utils.Seeder.StudentAttemptSeed do
  @moduledoc false
  defstruct [
    :user,
    :resource,
    :activity,
    :get_part_inputs,
    :transformed_model,
    :datashop_session_id,
    :resource_attempt_tag,
    :activity_attempt_tag,
    :part_attempt_tag
  ]
end
