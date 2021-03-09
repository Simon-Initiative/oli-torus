defmodule Oli.Interop.LegacySupport do

  @resources [
    "x-oli-workbook_page",
    "x-oli-inline-assessment"
  ]

  @supported [
    "activity_link",
    "link",
    "sym",
    "em",
    "sub",
    "sup",
    "term",
    "var",
    "code",
    "codeblock",
    "p",
    "ul",
    "ol",
    "dl",
    "dd",
    "dt",
    "li",
    "iframe",
    "audio",
    "youtube",
    "table",
    "th",
    "td",
    "tr",
    "title",
    "caption",
    "materials",
    "quote",
    "image",
    "example",
    "section",
    "wb:inline"
  ]
  @converted [
    "sym",
    "materials",
    "material",
    "pullout",
    "anchor",
    "extra"
  ]

  @unsupported [
    "applet",
    "director",
    "flash",
    "mathematica",
    "panopto",
    "unity",
    "video",
    "vimeo",
    "custom"
  ]

  @pending [
    "labels",
    "preconditions",
    "supplements",
    "unordered",
    "schedule",
    "include",
    "progress_constraints",
    "essay",
    "introduction",
    "conclusion",
    "embed_activity",
    "fill_in_the_blank",
    "ordering",
    "numeric",
    "short_answer",
    "image_hotspot",
    "variable",
    "page",
    "pool_ref",
    "pool",
    "cite",
    "foreign",
    "ipa",
    "bdo",
    "formula",
    "alternatives",
    "alternative",
    "composite",
    "conjugation",
    "dialog",
    "definition",
    "figure",
    "inquiry",
    "theorem",
    "command",
    "dependencies",
    "activity",
    "activity_report",
    "multipanel",
    "xref",
    "pref:choose",
    "pref:when",
    "pref:otherwise",
    "pref:if",
    "pref:label",
    "pref:value",
    "bib:entry"
  ]

  # The legacy resource types that Torus supports (beyond project and organization)
  def resources, do: @resources

  # The content elements that Torus provides direct support for.
  def supported, do: @supported

  # The content elements that Torus supports by converting these elements into
  # elements that Torus does support.  This conversion could be a mapping, or
  # simply the removal of the element (leaving behind the content of the element)
  def converted, do: @converted

  # These are elements that Torus will never support, and that a Legacy course must
  # replace or remove prior to conversion
  def unsupported, do: @unsupported

  # These are the elements that Torus plans to support in some way (either directly or
  # via conversion) but that currently does not.
  def pending, do: @pending


end
