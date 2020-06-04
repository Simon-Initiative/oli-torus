defmodule Oli.Analytics.Datashop do
  @moduledoc """
  https://pslcdatashop.web.cmu.edu/dtd/guide/tutor_message_dtd_guide_v4.pdf
  https://pslcdatashop.web.cmu.edu/help?page=logging
  https://pslcdatashop.web.cmu.edu/help?page=importFormatTd

  QA: https://pslc-qa.andrew.cmu.edu/datashop/Project?id=250
  """

  import XmlBuilder

  def wrap_document(elements) do
    elements
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

  def export do
    # write queries to get data
    # write functions to make action pairs

  end

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

  defp tutor_message do

  end

  defp tool_message do

  end

  defp context_message do

  end

end
