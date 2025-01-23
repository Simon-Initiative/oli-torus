defmodule Oli.Conversation.Trigger do

  defstruct [
    :type,
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
      type: map["trigger_type"] |> String.to_existing_atom,
      section_id: section_id,
      user_id: user_id,
      resource_id: map["resource_id"],
      data: map["data"],
      prompt: map["prompt"]
    }
  end

end
