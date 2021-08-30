defmodule Oli.Interop.CustomActivities.SuperActivityClient do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{ResourceType, ActivityBase, Authentication, Logging}

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :super_activity_client,
      %{
        server_time_zone: context.server_time_zone
      },
      [
        ResourceType.setup(
          %{
            id: context.activity_attempt.revision.activity_type.slug,
            name: context.activity_attempt.revision.activity_type.title
          }
        ),
        ActivityBase.setup(%{href: "https:/host/superactivity/embed/"}),
        Authentication.setup(%{user_guid: context.user.email}),
        Logging.setup(
          %{
            session_id: Base.encode64(context.section.slug),
            source_id: context.activity_attempt.revision.activity_type.slug,
            logging_url: "https://host/jcourse/dashboard/log/server"
          }
        )
      ]
    )
  end
end
