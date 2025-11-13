defmodule Oli.GoogleDocs.Warnings do
  @moduledoc """
  Central catalogue of warning codes and human-readable templates for the
  Google Docs import pipeline.

  Each entry contains a severity tag and a template that supports simple
  `%{placeholder}` substitution using metadata supplied at runtime.
  """

  @type code ::
          :download_failed
          | :download_too_large
          | :markdown_parse_error
          | :unsupported_block
          | :custom_element_unknown
          | :custom_element_invalid_shape
          | :mcq_missing_correct
          | :mcq_choice_missing
          | :mcq_feedback_missing
          | :mcq_activity_creation_failed
          | :cata_missing_correct
          | :cata_choice_missing
          | :cata_activity_creation_failed
          | :short_answer_invalid_shape
          | :short_answer_activity_creation_failed
          | :media_upload_failed
          | :media_oversized
          | :media_decode_failed
          | :media_dedupe_warning
          | :download_redirect
          | :dropdown_missing_markers
          | :dropdown_missing_input_data
          | :dropdown_insufficient_choices
          | :dropdown_missing_correct
          | :dropdown_choice_missing
          | :dropdown_feedback_missing
          | :dropdown_activity_creation_failed

  @catalogue %{
    download_failed: %{
      severity: :error,
      template: "Failed to download Google Doc `%{file_id}`: %{reason}."
    },
    download_too_large: %{
      severity: :error,
      template: "Google Doc `%{file_id}` exceeded the %{limit_mb} MB size limit."
    },
    markdown_parse_error: %{
      severity: :error,
      template: "Unable to parse Markdown content near `%{context}`; falling back to plain text."
    },
    unsupported_block: %{
      severity: :warn,
      template:
        "Encountered unsupported block `%{block_type}`; content preserved as raw Markdown."
    },
    custom_element_unknown: %{
      severity: :warn,
      template: "CustomElement `%{element_type}` is not supported; rendered as table."
    },
    custom_element_invalid_shape: %{
      severity: :warn,
      template:
        "CustomElement table under header `%{element_type}` is missing required key/value pairs."
    },
    mcq_missing_correct: %{
      severity: :warn,
      template:
        "MCQ CustomElement missing `correct` key or referencing an unknown choice; rendered as table."
    },
    mcq_choice_missing: %{
      severity: :warn,
      template: "MCQ CustomElement choice `%{choice_key}` has no value; omitted from activity."
    },
    mcq_feedback_missing: %{
      severity: :warn,
      template: "MCQ CustomElement feedback `%{feedback_key}` missing; default feedback applied."
    },
    mcq_activity_creation_failed: %{
      severity: :error,
      template: "Failed to create MCQ activity: %{reason}."
    },
    cata_missing_correct: %{
      severity: :warn,
      template:
        "CheckAllThatApply CustomElement missing valid `correct` entries; rendered as table."
    },
    cata_choice_missing: %{
      severity: :warn,
      template: "CheckAllThatApply choice `%{choice_key}` has no value; omitted from activity."
    },
    cata_activity_creation_failed: %{
      severity: :error,
      template: "Failed to create CheckAllThatApply activity: %{reason}."
    },
    short_answer_invalid_shape: %{
      severity: :warn,
      template: "ShortAnswer CustomElement is missing required data."
    },
    short_answer_activity_creation_failed: %{
      severity: :error,
      template: "Failed to create Short Answer activity: %{reason}."
    },
    media_upload_failed: %{
      severity: :warn,
      template: "Image upload failed (`%{reason}`); retained external data URL instead."
    },
    media_oversized: %{
      severity: :warn,
      template:
        "Image `%{filename}` skipped because it exceeded the %{limit_mb} MB per-image budget."
    },
    media_decode_failed: %{
      severity: :warn,
      template: "Could not decode base64 payload for image `%{filename}`; image left unchanged."
    },
    media_dedupe_warning: %{
      severity: :info,
      template: "Duplicate image detected (hash %{hash_prefix}); reusing existing asset."
    },
    download_redirect: %{
      severity: :error,
      template:
        "Google Docs redirected the request (HTTP %{status}) to `%{location}`. Verify the document is shared publicly and try again."
    },
    dropdown_missing_markers: %{
      severity: :warn,
      template: "Dropdown CustomElement stem must reference at least one [dropdownN] marker; rendered as table."
    },
    dropdown_missing_input_data: %{
      severity: :warn,
      template: "Dropdown CustomElement missing choice rows for `%{input}`; rendered as table."
    },
    dropdown_insufficient_choices: %{
      severity: :warn,
      template: "Dropdown `%{input}` must define at least two choices; rendered as table."
    },
    dropdown_missing_correct: %{
      severity: :warn,
      template: "Dropdown `%{input}` is missing a valid `-correct` entry; rendered as table."
    },
    dropdown_choice_missing: %{
      severity: :warn,
      template: "Dropdown entry `%{choice_key}` has no text; omitted from the activity."
    },
    dropdown_feedback_missing: %{
      severity: :warn,
      template: "Dropdown feedback `%{feedback_key}` missing; default feedback applied."
    },
    dropdown_activity_creation_failed: %{
      severity: :error,
      template: "Failed to create dropdown activity: %{reason}."
    }
  }

  @doc """
  Returns the raw warning definition for the given code or `nil` if not defined.
  """
  @spec definition(code) :: map() | nil
  def definition(code), do: Map.get(@catalogue, code)

  @doc """
  Renders the template for `code` using the provided metadata.
  Raises `KeyError` if the code is unknown.
  """
  @spec render(code, map()) :: String.t()
  def render(code, metadata \\ %{}) do
    template = @catalogue |> Map.fetch!(code) |> Map.fetch!(:template)
    interpolate(template, metadata)
  end

  @doc """
  Returns all catalogue entries as a keyword list, preserving insertion order.
  """
  @spec catalogue :: keyword()
  def catalogue do
    Enum.map(@catalogue, fn {code, definition} -> {code, definition} end)
  end

  @doc """
  Returns the severity for the warning code, defaulting to `:warn`.
  """
  @spec severity(code) :: atom()
  def severity(code) do
    case definition(code) do
      nil -> :warn
      %{severity: severity} -> severity
    end
  end

  @doc """
  Produces a normalised warning map with interpolated message, code, severity, and metadata.
  """
  @spec build(code, map()) :: %{
          code: code,
          message: String.t(),
          severity: atom(),
          metadata: map()
        }
  def build(code, metadata \\ %{}) do
    %{
      code: code,
      message: render(code, metadata),
      severity: severity(code),
      metadata: metadata
    }
  end

  defp interpolate(template, metadata) do
    Enum.reduce(metadata, template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
