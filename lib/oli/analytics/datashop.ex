defmodule Oli.Analytics.Datashop do
  @moduledoc """
  https://pslcdatashop.web.cmu.edu/dtd/guide/tutor_message_dtd_guide_v4.pdf
  https://pslcdatashop.web.cmu.edu/help?page=logging
  https://pslcdatashop.web.cmu.edu/help?page=importFormatTd

  QA: https://pslc-qa.andrew.cmu.edu/datashop/Project?id=250
  """

  import XmlBuilder
  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Delivery.Attempts
  alias Oli.Publishing.AuthoringResolver

  def export(project_id) do
    project_id
    |> elements
    |> tutor_related_message_sequence
    |> document
    |> generate
    |> write_file
  end

  def write_file(xml, file_name \\ "test") do
    file_name = file_name <> ".xml"
    path = Path.expand(__DIR__) <> "/"

    File.write(path <> file_name, xml)
  end

  def elements(project_id) do
    project = Course.get_project!(project_id)
    pub = Publishing.get_latest_published_publication_by_slug!(project.slug)
    Attempts.get_part_attempts_and_users_for_publication(pub.id)
    |> Enum.group_by(
      & {&1.user.email, &1.part_attempt.activity_attempt.revision.slug, &1.part_attempt.part_id},
      & &1.part_attempt)
    # now we have a list of keys of `revision_slug-user_email`, each of which has a list of part attempts
    |> Enum.map(fn {user_attempt, part_attempts} -> {email, activity_slug, part_id} = user_attempt
      [part_attempt_1 | _rest] = part_attempts
      {:ok, time} = format_date(part_attempt_1.inserted_at)

      context_message_id = make_id(email, activity_slug, part_id)
      problem_name = activity_slug <> "-part" <> part_id
      problem_name_element = element(:problem_name, problem_name)

      # meta element must be present on all tutor/tool messages even if it's present in the context message
      meta_element = element(:meta, %{}, [
        element(:user_id, email),
        element(:session_id, email <> time),
        element(:time, time),
        element(:time_zone, "GMT")
      ])

      # context message. skills should be present in tutor message, unused in context message
      # <context_message context_message_id="mary-smith-MAJOR-ARC-BFD-2-0" name="START_PROBLEM">
      #   <meta>
      #     <user_id >mary-smith</user_id>
      #     <session_id>mary-smith-2006-07-22</session_id>
      #     <time>2006-07-22 12:55:00 EST</time>
      #     <time_zone>EST</time_zone>
      #   </meta>
      #   <class>
      #     <school>PSLC</school>
      #   </class>
      #   <dataset>
      #     <name>Example Lab Study Summer 2006</name>
      #     <level type="Lesson">
      #       <name>CIRCLE-SECTION6-PROBLEM</name>
      #       <level type="Section">
      #         <name>CIRCLE-INTERIOR-EXTERIOR-1</name>
      #         <problem tutorFlag="tutor">
      #           <name>MAJOR-ARC-BFD-2-0</name>
      #         </problem>
      #       </level>
      #     </level>
      #   </dataset>
      # </context_message>
      context_message = element(:context_message,
        %{
          context_message_id: context_message_id,
          name: "START_PROBLEM"
        }, [
          meta_element,
          element(:dataset, %{}, [
            element(:name, dataset_name(project)),
            element(:level, %{type: "Page"}, [
              element(:name, activity_slug),
              element(:problem, [
                element(:name, problem_name)])
            ])
          ])
        ])


      # tool/tutor pairs
      pairs = part_attempts
      |> Enum.flat_map(
        fn part_attempt ->
          #create the attempts/hint messages

          # The part should be able to be found assuming that it adheres to OLI's activity authoring model
          # If it's a third-party custom activity, the part might not be under the authoring key
          part = part_attempt.activity_attempt.transformed_model["authoring"]["parts"]
          |> Enum.find(%{}, & &1["id"] == part_attempt.part_id)

          skill_ids = part_attempt.activity_attempt.revision.objectives[part_attempt.part_id] || []

          total_hints_available = try do
            {:ok, part
            |> Map.get("hints")
            |> length}
          rescue _e -> {:error}
          end

          hint_message_pairs = part_attempt.hints
          |> Enum.with_index()
          |> Enum.flat_map(
            fn {hint_id, i} ->
              # transaction id connects tool and tutor messages
              {:ok, uuid} = ShortUUID.encode(UUID.uuid4())
              transaction_id = context_message_id <> uuid

              hint_text = try do
                part.hints
                |> Enum.find(& &1.id == hint_id)
                # Need a way to extract raw text from the slate data model here. This is just a heuristic
                |> Map.get("content")
                |> hd
                |> Map.get("children")
                |> hd
                |> Map.get("text")
              rescue _e -> "Unknown hint text"
              end

              # tool message
              # <tool_message context_message_id="mary-smith-MAJOR-ARC-BFD-2-0">
              #   <meta>
              #     <user_id >mary-smith</user_id>
              #     <session_id>mary-smith-2006-07-22</session_id>
              #     <time>2006-07-22 13:02:05 EST</time>
              #     <time_zone>EST</time_zone>
              #   </meta>
              #   <problem_name>MAJOR-ARC-BFD-2-0</problem_name>
              #   <semantic_event transaction_id="mary-smith-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-004s" name="HINT_REQUEST" subtype="HELP"/>
              #   <event_descriptor>
              #     <selection/>
              #     <action>HELP</action>
              #   </event_descriptor>
              # </tool_message>
              hint_tool_message = element(:tool_message, %{context_message_id: context_message_id}, [
                meta_element,
                problem_name_element,
                element(:semantic_event, %{
                  transaction_id: transaction_id,
                  name: "HINT_REQUEST"
                }),
                element(:event_descriptor, [
                  element(:selection),
                  element(:action, "HELP")
                ])
              ])

              # tutor message. this should contain the skills attached to the part. model name seems to be optional
              # <tutor_message context_message_id="mary-smith-MAJOR-ARC-BFD-2-0">
              #   <meta>
              #     <user_id >mary-smith</user_id>
              #     <session_id>mary-smith-2006-07-22</session_id>
              #     <time>2006-07-22 12:58:50 EST</time>
              #     <time_zone>EST</time_zone>
              #   </meta>
              #   <problem_name>MAJOR-ARC-BFD-2-0</problem_name>
              #   <semantic_event transaction_id="mary-smith-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-001s" name="HINT_MSG" subtype="HELP-TEXT"/>
              #   <event_descriptor>
              #     <selection>(ARC-BD-MEASURE QUESTION1 ANSWER)</selection>
              #     <action>INPUT-CELL-VALUE</action>
              #   </event_descriptor>
              #   <action_evaluation current_hint_number="1" total_hints_available="1" classification="HELP-TEXT">HINT</action_evaluation>
              #   <tutor_advice> Some useful information is highlighted in the problem statement. .</tutor_advice>
                # <skill>
                #   <name>WORKING-WITH-ANGLES-OUTSIDE-A-CIRCLE</name>
                #   <category/>
                #   <model_name>Manual Model</model_name>
                # </skill>
                # <skill>
                #   <name>WORKING-WITH-ARCS-THAT-FORM-A-CIRCLE</name>
                #   <category/>
                #   <model_name>Manual Model</model_name>
                # </skill>
              # </tutor_message>
              hint_tutor_message = element(:tutor_message, %{context_message_id: context_message_id}, [
                meta_element,
                problem_name_element,
                element(:semantic_event, %{transaction_id: transaction_id, name: "HINT_MSG"}),
                # Could add an event_descriptor here with the student's current answer input, but not sure that will be helpful
                element(:action_evaluation,
                  %{current_hint_number: i,
                    total_hints_available:
                      case total_hints_available do
                        {:ok, num} -> num
                        {:error} -> "Unknown"
                      end
                  }, "HINT"),
                element(:tutor_advice, hint_text)
                ++ make_skills(project.slug, skill_ids)
              ])

              [hint_tool_message, hint_tutor_message]
            end)



          {:ok, uuid} = ShortUUID.encode(UUID.uuid4())
          transaction_id = context_message_id <> "_" <> uuid

          # <tool_message context_message_id="student-p1-MAJOR-ARC-BFD-2-0">
          #   <meta>
          #     <user_id anonFlag="true">student-p1</user_id>
          #     <session_id>student-p1-2006-07-22</session_id>
          #     <time>2006-07-22 12:59:47 EST</time>
          #     <time_zone>EST</time_zone>
          #   </meta>
          #   <problem_name>MAJOR-ARC-BFD-2-0</problem_name>
          #   <semantic_event transaction_id="student-p1-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-003s" name="ATTEMPT" subtype="APPLY-ACTION"/>
          #   <event_descriptor>
          #     <selection>(ARC-BD-MEASURE QUESTION1 REASON)</selection>
          #     <action>INPUT-CELL-VALUE</action>
          #     <input>given</input>
          #   </event_descriptor>
          # </tool_message>
          attempt_tool_message = element(:tool_message, %{context_message_id: context_message_id}, [
            meta_element,
            problem_name_element,
            element(:semantic_event, %{transaction_id: transaction_id, name: "ATTEMPT"}),
            element(:event_descriptor, [
              element(:selection, problem_name),
              element(:action, get_action(part_attempt)),
              element(:input, Poison.encode!(get_input(part_attempt)))
            ])
          ])

          # <tutor_message context_message_id="student-p1-MAJOR-ARC-BFD-2-0">
          #   <meta>
          #     <user_id anonFlag="true">student-p1</user_id>
          #     <session_id>student-p1-2006-07-22</session_id>
          #     <time>2006-07-22 12:59:47 EST</time>
          #     <time_zone>EST</time_zone>
          #   </meta>
          #   <problem_name>MAJOR-ARC-BFD-2-0</problem_name>
          #   <semantic_event transaction_id="student-p1-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-003s" name="RESULT" subtype="GOOD-PATH"/>
          #   <event_descriptor>
          #     <selection>(ARC-BD-MEASURE QUESTION1 REASON)</selection>
          #     <action>INPUT-CELL-VALUE</action>
          #     <input>given</input>
          #   </event_descriptor>
          #   <action_evaluation classification="GOOD-PATH">CORRECT</action_evaluation>
          #   <skill>
          #     <name>Given-Reason</name>
          #     <category>Circles</category>
          #     <model_name>Manual Model</model_name>
          #   </skill>
          # </tutor_message>
          attempt_tutor_message = element(:tutor_message, %{context_message_id: context_message_id}, [
            meta_element,
            problem_name_element,
            element(:semantic_event, %{transaction_id: transaction_id, name: "RESULT"}),
            element(:event_descriptor, [
              element(:selection, problem_name),
              element(:action, get_action(part_attempt)),
              element(:input, Poison.encode!(part_attempt.feedback))
            ]),
            element(:action_evaluation, correctness(part_attempt))]
            ++ make_skills(project.slug, skill_ids))

          attempt_message_pair = [attempt_tool_message, attempt_tutor_message]

          hint_message_pairs ++ attempt_message_pair

        end)

      [context_message | pairs]
    end)

  end

  defp correctness(part_attempt) do
    if part_attempt.score == part_attempt.out_of
    do "CORRECT"
    else "INCORRECT"
    end
  end


  defp get_action(part_attempt) do
    case part_attempt.activity_attempt.revision.activity_type.slug do
      "oli_short_answer" -> "Short answer input"
      "oli_multiple_choice" -> "Multiple choice selection"
      _unregistered -> "Action in unregistered activity type"
    end
  end


  # get selection from "response" ->
    # if mult choice, look up id in transformed model
    # if short answer, return text at input
  defp get_input(part_attempt) do
    input = part_attempt.response["input"]
    choices = part_attempt.activity_attempt.transformed_model["choices"]

    case part_attempt.activity_attempt.revision.activity_type.slug do
      # for short answer questions, the input is the text the student entered in the field
      "oli_short_answer" -> input
      # for multiple choice questions, the input is a string id that refers to the selected choice
      "oli_multiple_choice" -> Enum.find(choices, & &1["id"] == input)["content"]
      _unregistered -> "Input in unregistered activity type"
    end
  end

  # Datashop only accepts certain date formats. We're not really using the date/timing curves,
  # so not a lot of thought was put into this part
  def format_date(date) do
    Timex.format(date, "{YYYY}-{0M}-{0D} {0h24}:{0m}")
  end

  # This should be refined as we get a better understanding of what Datashop projects will be created
  # for each Torus project (one single Datashop project for all torus projects? Or one for every individual
  # torus project?)
  def dataset_name(project) do
    "dataset-#{project.slug}"
  end

  # Datashop "contexts" are defined by a "session" of {user, problem, time} tuples
  # We don't really make use of the timing information, so it's omitted
  def make_id(email, activity_slug, part_id) do
    "#{email}-#{activity_slug}-part#{part_id}"
  end

  def make_skills(project_slug, skill_ids) do
    skill_ids
    |> Enum.map(& element(:skill, [make_skill(project_slug, &1)]))
  end

  def make_skill(project_slug, skill_id) do
    element(:name, AuthoringResolver.from_resource_id(project_slug, skill_id).title)
  end




      # Full set:
      # context message id1 (start problem) with user and start time
        # add "page" information in context message meta field?
        # objectives are attached to activity revisions keyed off of the part id.
        # create one context message for each `user + part` combo, then add the skills from the activity revision
      # n tool/tutor messages with attempts, linked to context id1
      # n tool/tutor messages with hints, linked to context id1
      # context message id1 (end problem) with user and end time

      # context_message(part_attempt_and_user) ++ attempts(part_attempt_and_user) ++ hints(part_attempt_and_user)
      # get skills from part_attempt.activity_attempt.revision -> parse "objectives"



    # end)

    # correct: part_attempt.score == part_attempt.out_of


    # attempt/result
    # hint request


    # for each part attempt, need:
    #   student
    #   time
    #   dataset it belongs do
    #   list of objectives the part belongs to for context message
    #   problem name (activity slug or + p1 / p2)
    #   answer choice selected
    #   the hint selected (if any)
    #   evaluation (correct/incorrect)
    #   feedback returned to student

    # for each part attempt, create a message pair
    # for each part attempt where a hint is requested, create a message pair

    # create a message pair for each attempt in a "problem"
    # publication will have multiple sections, each of which has students with activity attempts



  @doc """
  Creates wrapper of form:
  <tutor_related_message_sequence
    xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
    xsi:noNamespaceSchemaLocation='http://pslcdatashop.org/dtd/tutor_message_v4.xsd'
    version_number="4">
    {...children}
  </tutor_related_message_sequence>
  """
  def tutor_related_message_sequence(children) do
    element(:tutor_related_message_sequence,
      %{
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:noNamespaceSchemaLocation" => "http://pslcdatashop.org/dtd/tutor_message_v4.xsd",
        "version_number" => "4"
      },
      children)
  end

  defp make_context_id(user, activity) do
    user.email <> "-" <> activity.slug <> "-" <> ShortUUID.encode!(UUID.uuid4())
  end

end
