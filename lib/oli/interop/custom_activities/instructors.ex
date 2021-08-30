defmodule Oli.Interop.CustomActivities.Instructors do

  alias Oli.Interop.CustomActivities.{User}
  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :instructors,
      context.instructors
      |> Enum.map(
           fn e ->
             User.setup(
               %{
                 context: %{
                   user: e
                 }
               }
             )
           end
         )
    )
  end
end
