defmodule Oli.Analytics.Datashop.Messages.Tutor do
  @moduledoc """
    <tutor_message context_message_id="mary-smith-MAJOR-ARC-BFD-2-0">
      <meta>
       <user_id>mary-smith</user_id>
        <session_id>mary-smith-2006-07-22</session_id>
        <time>2006-07-22 12:58:50 EST</time>
        <time_zone>EST</time_zone>
      </meta>
      <problem_name>MAJOR-ARC-BFD-2-0</problem_name>
      <semantic_event transaction_id="mary-smith-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-001s" name="HINT_MSG" subtype="HELP-TEXT"/>
      <event_descriptor>
        <selection>(ARC-BD-MEASURE QUESTION1 ANSWER)</selection>
        <action>INPUT-CELL-VALUE</action>
      </event_descriptor>
      <action_evaluation current_hint_number="1" total_hints_available="1" classification="HELP-TEXT">HINT</action_evaluation>
      <tutor_advice> Some useful information is highlighted in the problem statement. .</tutor_advice>
    <skill>
      <name>WORKING-WITH-ANGLES-OUTSIDE-A-CIRCLE</name>
      <category/>
      <model_name>Manual Model</model_name>
    </skill>
    <skill>
      <name>WORKING-WITH-ARCS-THAT-FORM-A-CIRCLE</name>
      <category/>
      <model_name>Manual Model</model_name>
    </skill>
   </tutor_message>
  """

  import XmlBuilder

  alias Oli.Analytics.Datashop.Elements.{
    Meta,
    ProblemName,
    SemanticEvent,
    ActionEvaluation,
    EventDescriptor,
    TutorAdvice,
    Skills
  }

  def setup(message_type, context) do
    element(
      :tutor_message,
      %{context_message_id: context.context_message_id},
      [
        Meta.setup(context),
        ProblemName.setup(context),
        SemanticEvent.setup(message_type, context),
        EventDescriptor.setup(message_type, context),
        ActionEvaluation.setup(context)
      ] ++
        if message_type == "HINT_MSG" do
          [TutorAdvice.setup(context)]
        else
          []
        end ++
        Skills.setup(context)
    )
  end
end
