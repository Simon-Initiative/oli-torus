defmodule OliWeb.Workspaces.CourseAuthor.Datasets.JobShortcuts do
  alias Oli.Analytics.Datasets.JobConfig

  @shortcuts [
               %{
                 value: :datashop,
                 label: "Datashop (.xml)",
                 description:
                   "An XML file containing student interaction data, formatted for the Datashop data mining tool."
               },
               %{
                 value: :attempts_simple,
                 label: "Attempt performance data (.csv)",
                 description:
                   "A CSV file containing student attempt performance data for part, activity and page attempts."
               },
               %{
                 value: :attempts_extended,
                 label: "Attempt performance data, extended fields (.csv)",
                 description:
                   "A CSV file containing student attempt performance data for part, activity and page attempts, with additional (large) fields including student reponse and system feedback"
               },
               %{
                 value: :video,
                 label: "Video interaction data (.csv)",
                 description:
                   "A CSV file containing interaction data (play, pause, seek, complete) for course videos."
               },
               %{
                 value: :page_viewed,
                 label: "Page view data (.csv)",
                 description: "A CSV file containing student page view data."
               },
               %{
                 value: :required_survey,
                 label: "Required survey data (.csv)",
                 description:
                   "A CSV file containing student responses to the required course survey."
               }
             ]
             |> Enum.reduce(%{}, fn shortcut, acc -> Map.put(acc, shortcut.value, shortcut) end)

  def all do
    Map.values(@shortcuts)
  end

  def get(value) do
    Map.get(@shortcuts, value)
  end

  def configure(:datashop, section_ids) do
    {:datashop,
     %JobConfig{
       section_ids: section_ids,
       chunk_size: 500,
       event_type: "datashop",
       event_sub_types: ["datashop"],
       page_ids: [],
       ignored_student_ids: [],
       excluded_fields: []
     }}
  end

  def configure(:attempts_simple, section_ids) do
    {:custom,
     %JobConfig{
       section_ids: section_ids,
       chunk_size: 50_000,
       event_type: "attempt_evaluated",
       event_sub_types: [
         "part_attempt_evaluted",
         "activity_attempt_evaluated",
         "page_attempt_evaluted"
       ],
       page_ids: [],
       ignored_student_ids: [],
       excluded_fields: ["feedback", "response", "hints"]
     }}
  end

  def configure(:attempts_extended, section_ids) do
    {:custom,
     %JobConfig{
       section_ids: section_ids,
       chunk_size: 5_000,
       event_type: "attempt_evaluated",
       event_sub_types: [
         "part_attempt_evaluted",
         "activity_attempt_evaluated",
         "page_attempt_evaluted"
       ],
       page_ids: [],
       ignored_student_ids: [],
       excluded_fields: []
     }}
  end

  def configure(:video, section_ids) do
    {:custom,
     %JobConfig{
       section_ids: section_ids,
       chunk_size: 50_000,
       event_type: "video",
       event_sub_types: ["played", "paused", "seeked", "completed"],
       page_ids: [],
       ignored_student_ids: [],
       excluded_fields: []
     }}
  end

  def configure(:page_viewed, section_ids) do
    {:custom,
     %JobConfig{
       section_ids: section_ids,
       chunk_size: 50_000,
       event_type: "page_viewed",
       event_sub_types: ["page_viewed"],
       page_ids: [],
       ignored_student_ids: [],
       excluded_fields: []
     }}
  end

  def configure(:required_survey, section_ids) do
    {:custom,
     %JobConfig{
       section_ids: section_ids,
       chunk_size: 5_000,
       event_type: "attempt_evaluated",
       event_sub_types: ["part_attempt_evaluted"],
       page_ids: [],
       ignored_student_ids: [],
       excluded_fields: ["feedback", "hints"]
     }}
  end
end
