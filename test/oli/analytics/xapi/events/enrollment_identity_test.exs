defmodule Oli.Analytics.XAPI.Events.EnrollmentIdentityTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.XAPI.Events.Attempt.TutorMessage
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Analytics.XAPI.Events.Video.{Completed, Paused, Played, Seeked}
  alias Oli.Delivery.Attempts.Core.ActivityAttempt

  @enrollment_extension "http://oli.cmu.edu/extensions/enrollment_id"

  test "video statements include pseudonymous enrollment identity" do
    context = context()

    common_details = %{
      attempt_guid: "page-attempt-guid",
      attempt_number: 1,
      resource_id: 88,
      timestamp: ~U[2026-08-20 13:17:58Z],
      video_url: "https://example.edu/video.mp4",
      video_title: "Example video",
      content_element_id: "video-1"
    }

    statements = [
      Played.new(context, Map.merge(common_details, %{video_length: 60, video_play_time: 1})),
      Paused.new(
        context,
        Map.merge(common_details, %{
          video_length: 60,
          video_played_segments: "0[.]1",
          video_progress: 0.1,
          video_time: 1
        })
      ),
      Seeked.new(
        context,
        Map.merge(common_details, %{video_seek_from: 1, video_seek_to: 5})
      ),
      Completed.new(
        context,
        Map.merge(common_details, %{
          video_length: 60,
          video_played_segments: "0[.]60",
          video_progress: 1.0,
          video_time: 60
        })
      )
    ]

    for statement <- statements do
      extensions = get_in(statement, ["context", "extensions"])
      assert extensions[@enrollment_extension] == 55
      refute Map.has_key?(extensions, "http://oli.cmu.edu/extensions/user_id")
    end
  end

  test "tutor-message statements include pseudonymous enrollment identity" do
    activity_attempt = %ActivityAttempt{
      attempt_guid: "activity-attempt-guid",
      attempt_number: 2,
      resource_id: 66,
      revision_id: 77
    }

    statement =
      TutorMessage.new(context(), activity_attempt, %{
        attempt_guid: "page-attempt-guid",
        attempt_number: 1,
        resource_id: 88,
        message: "<message>Hint requested</message>",
        timestamp: ~U[2026-08-20 13:17:58Z]
      })

    extensions = get_in(statement, ["context", "extensions"])
    assert extensions[@enrollment_extension] == 55
    refute Map.has_key?(extensions, "http://oli.cmu.edu/extensions/user_id")
  end

  defp context do
    %Context{
      user_id: 11,
      host_name: "https://example.edu",
      section_id: 22,
      project_id: 33,
      publication_id: 44,
      enrollment_id: 55
    }
  end
end
