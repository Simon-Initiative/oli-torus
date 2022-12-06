defmodule Oli.Rendering.Content.MathMLSanitizer do
  @moduledoc """
  MathMLSanitizer can strip a mathML block down to a white-listed set of tags an attributes.
  This is useful to allow authors to directly author MathML tags, but since those tags must
  be output raw to the html dom, we need to prevent malicious authors from inserting XSS based
  attacks.

  List of tags & attributes retrieved from https://developer.mozilla.org/en-US/docs/Web/MathML/Element


  !!! IF YOU CHANGE THIS FILE, YOU SHOULD UPDATE assets/src/utils/mathmlSanitizer.ts AS WELL !!!

  """

  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  @valid_schemes ["http", "https"]

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  Meta.allow_tag_with_these_attributes("maction", [
    "actiontype",
    "selection",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("math", [
    "dir",
    "display",
    "mode",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize",
    "accent",
    "accentunder",
    "actiontype",
    "align ",
    "altimg",
    "altimg-width",
    "altimg-height",
    "altimg-valign",
    "alttext",
    "bevelled ",
    "charalign",
    "close",
    "columnalign",
    "columnlines",
    "columnspacing",
    "columnspan",
    "crossout",
    "denomalign ",
    "depth",
    "edge",
    "fence",
    "frame",
    "framespacing",
    "groupalign",
    "height",
    "indentalign",
    "indentalignfirst",
    "indentalignlast",
    "indentshift",
    "indentshiftfirst",
    "indentshiftlast",
    "indenttarget",
    "infixlinebreakstyle",
    "length",
    "linebreak",
    "linebreakmultchar",
    "linebreakstyle",
    "lineleading",
    "linethickness",
    "location",
    "longdivstyle",
    "lspace",
    "lquote",
    "mathvariant",
    "maxsize",
    "minsize",
    "movablelimits",
    "notation",
    "numalign ",
    "open",
    "position",
    "rowalign",
    "rowlines",
    "rowspacing",
    "rowspan",
    "rspace",
    "rquote",
    "scriptlevel",
    "scriptminsize",
    "scriptsizemultiplier",
    "selection",
    "separator",
    "separators",
    "shift",
    "stackalign",
    "stretchy",
    "subscriptshift ",
    "supscriptshift ",
    "symmetric",
    "voffset",
    "width"
  ])

  Meta.allow_tag_with_these_attributes("menclose", [
    "notation",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("merror", [
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mfenced", [
    "close",
    "open",
    "separators",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mfrac", [
    "bevelled",
    "denomalign",
    "linethickness",
    "numalign",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mi", [
    "dir",
    "mathvariant",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mmultiscripts", [
    "subscriptshift",
    "superscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mn", [
    "dir",
    "mathvariant",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes(
    "mo",
    [
      "accent",
      "fence",
      "lspace",
      "mathvariant",
      "maxsize",
      "minsize",
      "movablelimits",
      "rspace",
      "separator",
      "stretchy",
      "symmetric",
      "class",
      "id",
      "style",
      "mathbackground",
      "mathcolor",
      "displaystyle",
      "mathsize"
    ]
  )

  Meta.allow_tag_with_these_attributes("mover", [
    "accent",
    "align",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mpadded", [
    "depth",
    "height",
    "lspace",
    "voffset",
    "width",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mphantom", [
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mroot", [
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mrow", [
    "dir",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("ms", [
    "dir",
    "lquote",
    "mathvariant",
    "rquote",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mspace", [
    "depth",
    "height",
    "width",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("msqrt", [""])

  Meta.allow_tag_with_these_attributes("mstyle", [
    "accent",
    "accentunder",
    "actiontype",
    "align ",
    "altimg",
    "altimg-width",
    "altimg-height",
    "altimg-valign",
    "alttext",
    "bevelled ",
    "charalign",
    "close",
    "columnalign",
    "columnlines",
    "columnspacing",
    "columnspan",
    "crossout",
    "denomalign ",
    "depth",
    "dir",
    "display",
    "edge",
    "fence",
    "frame",
    "framespacing",
    "groupalign",
    "height",
    "indentalign",
    "indentalignfirst",
    "indentalignlast",
    "indentshift",
    "indentshiftfirst",
    "indentshiftlast",
    "indenttarget",
    "infixlinebreakstyle",
    "length",
    "linebreak",
    "linebreakmultchar",
    "linebreakstyle",
    "lineleading",
    "linethickness",
    "location",
    "longdivstyle",
    "lspace",
    "lquote",
    "mathvariant",
    "maxsize",
    "minsize",
    "movablelimits",
    "notation",
    "numalign ",
    "open",
    "position",
    "rowalign",
    "rowlines",
    "rowspacing",
    "rowspan",
    "rspace",
    "rquote",
    "scriptlevel",
    "scriptminsize",
    "scriptsizemultiplier",
    "selection",
    "separator",
    "separators",
    "shift",
    "stackalign",
    "stretchy",
    "subscriptshift ",
    "supscriptshift ",
    "symmetric",
    "voffset",
    "width"
  ])

  Meta.allow_tag_with_these_attributes("msub", [
    "subscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("msubsup", [
    "subscriptshift",
    "superscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("msup", [
    "superscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes(
    "mtable",
    [
      "align",
      "columnalign",
      "columnlines",
      "columnspacing",
      "frame",
      "framespacing",
      "rowalign",
      "rowlines",
      "width",
      "class",
      "id",
      "style",
      "mathbackground",
      "mathcolor",
      "displaystyle",
      "mathsize"
    ]
  )

  Meta.allow_tag_with_these_attributes("mtd", [
    "columnalign",
    "columnspan",
    "rowalign",
    "rowspan",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mtext", [
    "dir",
    "mathvariant",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("mtr", [
    "columnalign",
    "rowalign",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("munder", [
    "accentunder",
    "align",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("munderover", [
    "accent",
    "accentunder",
    "align",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("semantics", [
    "encoding",
    "cd",
    "name",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_uri_attributes("semantics", ["src", "definitionURL"], @valid_schemes)

  Meta.allow_tag_with_these_attributes("m:maction", [
    "actiontype",
    "selection",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:math", [
    "dir",
    "display",
    "mode",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize",
    "accent",
    "accentunder",
    "actiontype",
    "align ",
    "altimg",
    "altimg-width",
    "altimg-height",
    "altimg-valign",
    "alttext",
    "bevelled ",
    "charalign",
    "close",
    "columnalign",
    "columnlines",
    "columnspacing",
    "columnspan",
    "crossout",
    "denomalign ",
    "depth",
    "edge",
    "fence",
    "frame",
    "framespacing",
    "groupalign",
    "height",
    "indentalign",
    "indentalignfirst",
    "indentalignlast",
    "indentshift",
    "indentshiftfirst",
    "indentshiftlast",
    "indenttarget",
    "infixlinebreakstyle",
    "length",
    "linebreak",
    "linebreakmultchar",
    "linebreakstyle",
    "lineleading",
    "linethickness",
    "location",
    "longdivstyle",
    "lspace",
    "lquote",
    "mathvariant",
    "maxsize",
    "minsize",
    "movablelimits",
    "notation",
    "numalign ",
    "open",
    "position",
    "rowalign",
    "rowlines",
    "rowspacing",
    "rowspan",
    "rspace",
    "rquote",
    "scriptlevel",
    "scriptminsize",
    "scriptsizemultiplier",
    "selection",
    "separator",
    "separators",
    "shift",
    "stackalign",
    "stretchy",
    "subscriptshift ",
    "supscriptshift ",
    "symmetric",
    "voffset",
    "width"
  ])

  Meta.allow_tag_with_these_attributes("m:menclose", [
    "notation",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:merror", [
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mfenced", [
    "close",
    "open",
    "separators",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mfrac", [
    "bevelled",
    "denomalign",
    "linethickness",
    "numalign",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mi", [
    "dir",
    "mathvariant",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mmultiscripts", [
    "subscriptshift",
    "superscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mn", [
    "dir",
    "mathvariant",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes(
    "m:mo",
    [
      "accent",
      "fence",
      "lspace",
      "mathvariant",
      "maxsize",
      "minsize",
      "movablelimits",
      "rspace",
      "separator",
      "stretchy",
      "symmetric",
      "class",
      "id",
      "style",
      "mathbackground",
      "mathcolor",
      "displaystyle",
      "mathsize"
    ]
  )

  Meta.allow_tag_with_these_attributes("m:mover", [
    "accent",
    "align",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mpadded", [
    "depth",
    "height",
    "lspace",
    "voffset",
    "width",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mphantom", [
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mroot", [
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mrow", [
    "dir",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:ms", [
    "dir",
    "lquote",
    "mathvariant",
    "rquote",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mspace", [
    "depth",
    "height",
    "width",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:msqrt", [""])

  Meta.allow_tag_with_these_attributes("m:mstyle", [
    "accent",
    "accentunder",
    "actiontype",
    "align ",
    "altimg",
    "altimg-width",
    "altimg-height",
    "altimg-valign",
    "alttext",
    "bevelled ",
    "charalign",
    "close",
    "columnalign",
    "columnlines",
    "columnspacing",
    "columnspan",
    "crossout",
    "denomalign ",
    "depth",
    "dir",
    "display",
    "edge",
    "fence",
    "frame",
    "framespacing",
    "groupalign",
    "height",
    "indentalign",
    "indentalignfirst",
    "indentalignlast",
    "indentshift",
    "indentshiftfirst",
    "indentshiftlast",
    "indenttarget",
    "infixlinebreakstyle",
    "length",
    "linebreak",
    "linebreakmultchar",
    "linebreakstyle",
    "lineleading",
    "linethickness",
    "location",
    "longdivstyle",
    "lspace",
    "lquote",
    "mathvariant",
    "maxsize",
    "minsize",
    "movablelimits",
    "notation",
    "numalign ",
    "open",
    "position",
    "rowalign",
    "rowlines",
    "rowspacing",
    "rowspan",
    "rspace",
    "rquote",
    "scriptlevel",
    "scriptminsize",
    "scriptsizemultiplier",
    "selection",
    "separator",
    "separators",
    "shift",
    "stackalign",
    "stretchy",
    "subscriptshift ",
    "supscriptshift ",
    "symmetric",
    "voffset",
    "width"
  ])

  Meta.allow_tag_with_these_attributes("m:msub", [
    "subscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:msubsup", [
    "subscriptshift",
    "superscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:msup", [
    "superscriptshift",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes(
    "m:mtable",
    [
      "align",
      "columnalign",
      "columnlines",
      "columnspacing",
      "frame",
      "framespacing",
      "rowalign",
      "rowlines",
      "width",
      "class",
      "id",
      "style",
      "mathbackground",
      "mathcolor",
      "displaystyle",
      "mathsize"
    ]
  )

  Meta.allow_tag_with_these_attributes("m:mtd", [
    "columnalign",
    "columnspan",
    "rowalign",
    "rowspan",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mtext", [
    "dir",
    "mathvariant",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:mtr", [
    "columnalign",
    "rowalign",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:munder", [
    "accentunder",
    "align",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:munderover", [
    "accent",
    "accentunder",
    "align",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_these_attributes("m:semantics", [
    "encoding",
    "cd",
    "name",
    "class",
    "id",
    "style",
    "mathbackground",
    "mathcolor",
    "displaystyle",
    "mathsize"
  ])

  Meta.allow_tag_with_uri_attributes("m:semantics", ["src", "definitionURL"], @valid_schemes)

  Meta.strip_everything_not_covered()
end
