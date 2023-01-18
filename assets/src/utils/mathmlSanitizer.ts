import sanitizeHtml, { IOptions } from 'sanitize-html';

/**
 *  sanitizeMathML can strip a mathML block down to a white-listed set of tags and attributes.
 *  This is useful to allow authors to directly author MathML tags, but since those tags must
 *  be output raw to the html dom, we need to prevent malicious authors from inserting XSS based
 *  attacks.
 *
 * List of tags & attributes retrieved from https://developer.mozilla.org/en-US/docs/Web/MathML/Element
 *
 * !!! IF YOU CHANGE THIS FILE, YOU SHOULD UPDATE lib/oli/rendering/content/mathml_sanitizer.ex AS WELL !!!
 *
 */

const commonAttributes = [
  'class',
  'id',
  'style',
  'mathbackground',
  'mathcolor',
  'displaystyle',
  'mathsize',
];

const mstyleAttributes = [
  'accent',
  'accentunder',
  'actiontype',
  'align ',
  'altimg',
  'altimg-width',
  'altimg-height',
  'altimg-valign',
  'alttext',
  'bevelled ',
  'charalign',
  'close',
  'columnalign',
  'columnlines',
  'columnspacing',
  'columnspan',
  'crossout',
  'denomalign ',
  'depth',
  'dir',
  'display',
  'edge',
  'fence',
  'frame',
  'framespacing',
  'groupalign',
  'height',
  'indentalign',
  'indentalignfirst',
  'indentalignlast',
  'indentshift',
  'indentshiftfirst',
  'indentshiftlast',
  'indenttarget',
  'infixlinebreakstyle',
  'length',
  'linebreak',
  'linebreakmultchar',
  'linebreakstyle',
  'lineleading',
  'linethickness',
  'location',
  'longdivstyle',
  'lspace',
  'lquote',
  'mathvariant',
  'maxsize',
  'minsize',
  'movablelimits',
  'notation',
  'numalign ',
  'open',
  'position',
  'rowalign',
  'rowlines',
  'rowspacing',
  'rowspan',
  'rspace',
  'rquote',
  'scriptlevel',
  'scriptminsize',
  'scriptsizemultiplier',
  'selection',
  'separator',
  'separators',
  'shift',
  'stackalign',
  'stretchy',
  'subscriptshift ',
  'supscriptshift ',
  'symmetric',
  'voffset',
  'width',
];

const allowedAttributes = {
  maction: ['actiontype', 'selection', ...commonAttributes],

  math: ['dir', 'display', 'mode', ...mstyleAttributes, ...commonAttributes],

  menclose: ['notation', ...commonAttributes],

  merror: commonAttributes,

  mfenced: ['close', 'open', 'separators', ...commonAttributes],

  mfrac: ['bevelled', 'denomalign', 'linethickness', 'numalign', ...commonAttributes],

  mi: ['dir', 'mathvariant', ...commonAttributes],

  mmultiscripts: ['subscriptshift', 'superscriptshift', ...commonAttributes],

  mn: ['dir', 'mathvariant', ...commonAttributes],

  mo: [
    'accent',
    'fence',
    'lspace',
    'mathvariant',
    'maxsize',
    'minsize',
    'movablelimits',
    'rspace',
    'separator',
    'stretchy',
    'symmetric',
    ...commonAttributes,
  ],

  mover: ['accent', 'align', ...commonAttributes],

  mpadded: ['depth', 'height', 'lspace', 'voffset', 'width', ...commonAttributes],

  mphantom: commonAttributes,

  mroot: commonAttributes,

  mrow: ['dir', ...commonAttributes],

  ms: ['dir', 'lquote', 'mathvariant', 'rquote', ...commonAttributes],

  mspace: ['depth', 'height', 'width', ...commonAttributes],

  msqrt: commonAttributes,

  mstyle: [...mstyleAttributes, ...commonAttributes],

  msub: ['subscriptshift', ...commonAttributes],

  msubsup: ['subscriptshift', 'superscriptshift', ...commonAttributes],

  msup: ['superscriptshift', ...commonAttributes],

  mtable: [
    'align',
    'columnalign',
    'columnlines',
    'columnspacing',
    'frame',
    'framespacing',
    'rowalign',
    'rowlines',
    'width',

    ...commonAttributes,
  ],

  mtd: ['columnalign', 'columnspan', 'rowalign', 'rowspan', ...commonAttributes],

  mtext: ['dir', 'mathvariant', ...commonAttributes],

  mtr: ['columnalign', 'rowalign', ...commonAttributes],

  munder: ['accentunder', 'align', ...commonAttributes],

  munderover: ['accent', 'accentunder', 'align', ...commonAttributes],

  semantics: ['src', 'definitionurl', 'encoding', 'cd', 'name', ...commonAttributes],

  'm:maction': ['actiontype', 'selection', ...commonAttributes],

  'm:math': ['dir', 'display', 'mode', ...mstyleAttributes, ...commonAttributes],

  'm:menclose': ['notation', ...commonAttributes],

  'm:merror': commonAttributes,

  'm:mfenced': ['close', 'open', 'separators', ...commonAttributes],

  'm:mfrac': ['bevelled', 'denomalign', 'linethickness', 'numalign', ...commonAttributes],

  'm:mi': ['dir', 'mathvariant', ...commonAttributes],

  'm:mmultiscripts': ['subscriptshift', 'superscriptshift', ...commonAttributes],

  'm:mn': ['dir', 'mathvariant', ...commonAttributes],

  'm:mo': [
    'accent',
    'fence',
    'lspace',
    'mathvariant',
    'maxsize',
    'minsize',
    'movablelimits',
    'rspace',
    'separator',
    'stretchy',
    'symmetric',
    ...commonAttributes,
  ],

  'm:mover': ['accent', 'align', ...commonAttributes],

  'm:mpadded': ['depth', 'height', 'lspace', 'voffset', 'width', ...commonAttributes],

  'm:mphantom': commonAttributes,

  'm:mroot': commonAttributes,

  'm:mrow': ['dir', ...commonAttributes],

  'm:ms': ['dir', 'lquote', 'mathvariant', 'rquote', ...commonAttributes],

  'm:mspace': ['depth', 'height', 'width', ...commonAttributes],

  'm:msqrt': commonAttributes,

  'm:mstyle': [...mstyleAttributes, ...commonAttributes],

  'm:msub': ['subscriptshift', ...commonAttributes],

  'm:msubsup': ['subscriptshift', 'superscriptshift', ...commonAttributes],

  'm:msup': ['superscriptshift', ...commonAttributes],

  'm:mtable': [
    'align',
    'columnalign',
    'columnlines',
    'columnspacing',
    'frame',
    'framespacing',
    'rowalign',
    'rowlines',
    'width',

    ...commonAttributes,
  ],

  'm:mtd': ['columnalign', 'columnspan', 'rowalign', 'rowspan', ...commonAttributes],

  'm:mtext': ['dir', 'mathvariant', ...commonAttributes],

  'm:mtr': ['columnalign', 'rowalign', ...commonAttributes],

  'm:munder': ['accentunder', 'align', ...commonAttributes],

  'm:munderover': ['accent', 'accentunder', 'align', ...commonAttributes],

  'm:semantics': ['src', 'definitionurl', 'encoding', 'cd', 'name', ...commonAttributes],
};

const config: IOptions = {
  allowedTags: Object.keys(allowedAttributes),
  disallowedTagsMode: 'discard',
  allowedAttributes,
  selfClosing: [],
  allowedSchemes: ['http', 'https'],
  allowedSchemesByTag: {},
  allowedSchemesAppliedToAttributes: ['href', 'src', 'definitionurl'],
  allowProtocolRelative: true,
  enforceHtmlBoundary: false,
};

export const sanitizeMathML = (src: string) => sanitizeHtml(src, config);
