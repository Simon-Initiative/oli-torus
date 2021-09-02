defmodule Oli.Interop.CustomActivities.Instructors do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{User}

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :instructors,
      context.instructors
      |> Enum.map(
           fn user ->
             User.setup(
               %{
                 context: %{
                   user: user
                 }
               }
             )
           end
         )
    )
  end
end
