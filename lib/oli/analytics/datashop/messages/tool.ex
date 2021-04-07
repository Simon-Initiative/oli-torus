defmodule Oli.Analytics.Datashop.Messages.Tool do
  @moduledoc """
    <tool_message context_message_id="student-p1-MAJOR-ARC-BFD-2-0">
      <meta>
        <user_id anonFlag="true">student-p1</user_id>
        <session_id>student-p1-2006-07-22</session_id>
        <time>2006-07-22 12:59:47 EST</time>
        <time_zone>EST</time_zone>
      </meta>
      <problem_name>MAJOR-ARC-BFD-2-0</problem_name>
      <semantic_event transaction_id="student-p1-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-003s" name="ATTEMPT"/>
      <event_descriptor>
        <selection>(ARC-BD-MEASURE QUESTION1 REASON)</selection>
        <action>INPUT-CELL-VALUE</action>
        <input>given</input>
      </event_descriptor>
    </tool_message>
  """
  # defstruct [:context_message_id, :meta_element, :problem_name, :transaction_id, :name, :selection, :action, :input]
  import XmlBuilder
  alias Oli.Analytics.Datashop.Elements.{Meta, ProblemName, SemanticEvent, EventDescriptor}

  def setup(%{
        # HINT or ATTEMPT
        type: type,
        context_message_id: context_message_id,
        meta_element_context: meta_element_context,
        semantic_event_context: semantic_event_context,
        part_attempt: part_attempt,
        problem_name: problem_name
      }) do
    element(:tool_message, %{context_message_id: context_message_id}, [
      Meta.setup(meta_element_context),
      ProblemName.setup(%{name: problem_name}),
      SemanticEvent.setup(semantic_event_context),
      EventDescriptor.setup(%{type: type, problem_name: problem_name, part_attempt: part_attempt})
    ])
  end
end
