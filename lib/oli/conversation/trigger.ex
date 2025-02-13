defmodule Oli.Conversation.Trigger do
  @derive Jason.Encoder
  defstruct [
    :trigger_type,
    :section_id,
    :user_id,
    :resource_id,
    :data,
    :prompt
  ]

  @doc """
  Parse the trigger data from a regular map (as received from a client-side invocation).
  """
  def parse(map, section_id, user_id) do
    %__MODULE__{
      trigger_type: map["trigger_type"] |> String.to_existing_atom(),
      section_id: section_id,
      user_id: user_id,
      resource_id: map["resource_id"],
      data: map["data"],
      prompt: map["prompt"]
    }
  end

  def from_activity_model(%Oli.Activities.Model.Trigger{
        trigger_type: type,
        prompt: prompt,
        ref_id: ref_id
      }) do
    %__MODULE__{
      trigger_type: type,
      section_id: nil,
      user_id: nil,
      resource_id: nil,
      data: ref_id,
      prompt: prompt
    }
  end
end
