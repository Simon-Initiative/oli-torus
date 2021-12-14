const toObj = (arr) => arr.reduce((p, c) => {
    p[c] = true;
    return p;
}, {});
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
export const schema = {
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
        isVoid: false,
        isBlock: true,
        isTopLevel: true,
        validChildren: toObj(['code_line']),
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
//# sourceMappingURL=schema.js.map