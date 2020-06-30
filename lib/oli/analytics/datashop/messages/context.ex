
defmodule Oli.Analytics.Datashop.Messages.Context do
  @moduledoc """
  <context_message context_message_id="t.stark+0@avengers.com-one-part1" name="START_PROBLEM">
    <meta>
      <user_id>t.stark+0@avengers.com</user_id>
      <session_id>t.stark+0@avengers.com 2020-06-30 00:18</session_id>
      <time>2020-06-30 00:18</time>
      <time_zone>GMT</time_zone>
    </meta>
    <dataset>
      <name>example_open_and_free_course-XVeLxRjNVUdSnzsMuFeZNn</name>
      <name>Activity one</name>
      <problem_name>Activity one, part 1</problem_name>
    </dataset>
  </context_message>
  """
  import XmlBuilder
  alias Oli.Analytics.Datashop.Elements.{Meta, Dataset}

  def setup(%{
    name: name,
    context_message_id: context_message_id,
    meta_element_context: meta_element_context,
    dataset_element_context:  dataset_element_context
  }) do
    element(:context_message,
      %{
        context_message_id: context_message_id,
        name: name
      },
      [
        Meta.setup(meta_element_context),
        Dataset.setup(dataset_element_context)
      ])
  end
end
