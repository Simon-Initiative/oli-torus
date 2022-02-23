defmodule Oli.Interop.CustomActivities.Section do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{Instructors}

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :section,
      %{
        admit_code: "none",
        auto_validate: "true",
        date_created: DateTime.to_unix(context.section.inserted_at),
        date_updated: DateTime.to_unix(context.section.updated_at),
        duration: nil,
        end_date: context.section.end_date,
        guest_section: context.section.open_and_free,
        guid: context.section.id,
        institution: case context.section.institution do
          nil -> "none"
          _ -> context.section.institution.name
        end,
        registration_closed: context.section.registration_open,
        start_date: context.section.start_date,
        time_zone: context.section.timezone,
        title: context.section.title
      },
      [
        Instructors.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
