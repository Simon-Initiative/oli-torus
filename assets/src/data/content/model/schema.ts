const toObj = (arr: string[]): Record<string, boolean> =>
  arr.reduce((p, c) => {
    p[c] = true;
    return p;
  }, {} as Record<string, boolean>);

const header = {
  isVoid: false,
  isBlock: true,
  isTopLevel: true,
  validChildren: {},
};

const media = {
  isVoid: true,
  isBlock: true,
  isTopLevel: true,
  validChildren: {},
};

const tableCell = {
  isVoid: false,
  isBlock: true,
  isTopLevel: false,
  validChildren: toObj(['p', 'img', 'youtube', 'audio', 'math']),
};

const list = {
  isVoid: false,
  isBlock: true,
  isTopLevel: true,
  validChildren: toObj(['li', 'ol', 'ul']),
};

export interface SchemaConfig {
  isVoid: boolean;
  isBlock: boolean;
  isTopLevel: boolean;
  validChildren: Record<string, boolean>;
}

interface Schema
  extends Record<
    string,
    {
      isVoid: boolean;
      isBlock: boolean;
      isTopLevel: boolean;
      validChildren: Record<string, boolean>;
      isSimpleText?: boolean;
    }
  > {}
export const schema: Schema = {
  p: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['input_ref']),
  },
  h1: header,
  h2: header,
  h3: header,
  h4: header,
  h5: header,
  h6: header,
  img: media,
  youtube: media,
  audio: media,
  iframe: media,
  table: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['tr']),
  },
  tr: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(['td', 'th']),
  },
  th: tableCell,
  td: tableCell,
  ol: list,
  ul: list,
  li: {
    isVoid: false,
    isBlock: true,
    isTopLevel: false,
    validChildren: toObj(['ol', 'ul']),
  },
  math: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['math_line']),
  },
  math_line: {
    isVoid: false,
    isBlock: true,
    isSimpleText: true,
    isTopLevel: false,
    validChildren: {},
  },
  code: {
    isVoid: true,
    isBlock: true,
    isTopLevel: true,
    validChildren: {},
  },
  code_line: {
    isVoid: false,
    isBlock: true,
    isSimpleText: true,
    isTopLevel: false,
    validChildren: {},
  },
  blockquote: {
    isVoid: false,
    isBlock: true,
    isTopLevel: true,
    validChildren: toObj(['p']),
  },
  a: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
  popup: {
    isVoid: false,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
  input_ref: {
    isVoid: true,
    isBlock: false,
    isTopLevel: false,
    validChildren: {},
  },
};
