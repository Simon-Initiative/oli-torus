defmodule Oli.Validation.ActivityContracts do
  @moduledoc "Trusted schema and domain policies for activity validation."

  @contracts %{
    "oli_multiple_choice" => %{schema: "multiple-choice.schema.json", domain: :responses},
    "oli_ordering" => %{schema: "ordering.schema.json", domain: :responses},
    "oli_check_all_that_apply" => %{
      schema: "check-all-that-apply.schema.json",
      domain: :responses
    },
    "oli_likert" => %{schema: "likert.schema.json", domain: :responses},
    "oli_file_upload" => %{schema: "file-upload.schema.json", domain: :responses},
    "oli_short_answer" => %{schema: "short-answer.schema.json", domain: :responses},
    "oli_multi_input" => %{schema: "multi-input.schema.json", domain: :responses},
    "oli_directed_discussion" => %{schema: "directed-discussion.schema.json", domain: :delegated},
    "oli_image_coding" => %{schema: "image-coding.schema.json", domain: :delegated},
    "oli_custom_dnd" => %{schema: "custom-dnd.schema.json", domain: :responses},
    "oli_response_multi" => %{schema: "response-multi.schema.json", domain: :responses},
    "oli_image_hotspot" => %{schema: "image-hotspot.schema.json", domain: :responses},
    "oli_embedded" => %{schema: "oli-embedded.schema.json", domain: :delegated},
    "lti_external_tool" => %{schema: "lti-external-tool.schema.json", domain: :delegated},
    "oli_logic_lab" => %{schema: "logic-lab.schema.json", domain: :delegated},
    "oli_vlab" => %{schema: "vlab.schema.json", domain: :responses},
    "oli_adaptive" => %{schema: "adaptive.schema.json", domain: :unsupported}
  }

  @doc "Returns the fixed contract for an exact manifest slug."
  def fetch(slug), do: Map.fetch(@contracts, slug)

  @doc "Returns every supported schema contract, including domain exclusions."
  def all, do: @contracts
end
