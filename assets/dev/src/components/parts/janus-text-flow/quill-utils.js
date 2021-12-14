import Delta from 'quill-delta';
const appendToStringProperty = (append, str) => {
    if (!str) {
        return append;
    }
    return `${str} ${append}`;
};
const convertFontName = (fontCode) => {
    const result = fontCode
        .split('-')
        .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
        .join(' ');
    return result;
};
export const convertQuillToJanus = (delta) => {
    const doc = new Delta().compose(delta);
    const nodes = [];
    let listParent = null;
    doc.eachLine((line, attrs) => {
        const nodeStyle = {};
        const node = {
            tag: 'p',
            style: nodeStyle,
            children: [],
        };
        if (attrs.fontSize) {
            nodeStyle.fontSize = attrs.fontSize;
        }
        if (attrs.indent) {
            nodeStyle.paddingLeft = `${attrs.indent * 3}em`;
            node.customCssClass = appendToStringProperty(`ql-indent-${attrs.indent}`, node.customCssClass);
        }
        if (attrs.align) {
            nodeStyle.textAlign = attrs.align;
        }
        if (attrs.list) {
            if (!listParent) {
                listParent = {
                    tag: attrs.list === 'ordered' ? 'ol' : 'ul',
                    style: {},
                    children: [],
                };
                nodes.push(listParent);
            }
            node.tag = 'li';
        }
        else if (listParent) {
            listParent = null;
        }
        if (attrs.blockquote) {
            node.tag = 'blockquote';
        }
        if (attrs.header) {
            node.tag = `h${attrs.header}`;
        }
        line.forEach((op) => {
            var _a, _b, _c;
            if (typeof op.insert === 'object') {
                const imageDetails = op.insert;
                const child = {
                    tag: 'img',
                    style: {
                        height: '100%',
                        width: '100%',
                    },
                    src: `${imageDetails.image}`,
                    children: [],
                };
                node.children.push(child);
            }
            else if (typeof op.insert === 'string') {
                const style = {};
                if (op.attributes) {
                    if (op.attributes.font) {
                        style.fontFamily = convertFontName(op.attributes.font);
                    }
                    if (op.attributes.bold) {
                        style.fontWeight = 'bold';
                    }
                    if (op.attributes.italic) {
                        style.fontStyle = 'italic';
                    }
                    if (op.attributes.size) {
                        style.fontSize = op.attributes.size;
                    }
                    if (op.attributes.underline) {
                        style.textDecoration = appendToStringProperty('underline', style.textDecoration);
                    }
                    if (op.attributes.strike) {
                        style.textDecoration = appendToStringProperty('line-through', style.textDecoration);
                    }
                    if (op.attributes.color) {
                        style.color = op.attributes.color;
                    }
                    if (op.attributes.background) {
                        style.backgroundColor = op.attributes.background;
                    }
                }
                const child = {
                    tag: 'span',
                    style,
                    children: [
                        {
                            tag: 'text',
                            style: {},
                            text: op.insert,
                            children: [],
                        },
                    ],
                };
                if (style.fontFamily) {
                    child.customCssClass = appendToStringProperty(`ql-font-${(_a = op.attributes) === null || _a === void 0 ? void 0 : _a.font}`, child.customCssClass);
                }
                if ((_b = op.attributes) === null || _b === void 0 ? void 0 : _b.script) {
                    if (op.attributes.script === 'sub') {
                        child.tag = 'sub';
                    }
                    if (op.attributes.script === 'super') {
                        child.tag = 'sup';
                    }
                }
                if ((_c = op.attributes) === null || _c === void 0 ? void 0 : _c.link) {
                    child.tag = 'a';
                    child.href = op.attributes.link;
                }
                node.children.push(child);
            }
        });
        if (listParent) {
            listParent.children.push(node);
        }
        else {
            nodes.push(node);
        }
    });
    /* console.log('Q -> J', { doc, nodes }); */
    return nodes;
};
const processJanusChildren = (node, doc, parentAttrs = {}) => {
    var _a, _b, _c, _d, _e, _f;
    const attrs = {};
    if (((_a = node.style) === null || _a === void 0 ? void 0 : _a.fontWeight) === 'bold') {
        attrs.bold = true;
    }
    if ((_b = node.style) === null || _b === void 0 ? void 0 : _b.fontSize) {
        let size = node.style.fontSize;
        if (typeof size === 'number' || !size.endsWith('px')) {
            size = `${size}px`;
        }
        attrs.size = size;
    }
    if ((_c = node.style) === null || _c === void 0 ? void 0 : _c.textDecoration) {
        if (node.style.textDecoration.includes('underline')) {
            attrs.underline = true;
        }
        if (node.style.textDecoration.includes('line-through')) {
            attrs.strike = true;
        }
    }
    if (((_d = node.style) === null || _d === void 0 ? void 0 : _d.fontStyle) === 'italic') {
        attrs.italic = true;
    }
    if ((_e = node.style) === null || _e === void 0 ? void 0 : _e.color) {
        attrs.color = node.style.color;
    }
    if ((_f = node.style) === null || _f === void 0 ? void 0 : _f.backgroundColor) {
        attrs.background = node.style.backgroundColor;
    }
    if (node.href) {
        attrs.link = node.href;
    }
    if (node.tag === 'sub') {
        attrs.script = 'sub';
    }
    if (node.tag === 'sup') {
        attrs.script = 'super';
    }
    if (node.children && node.children.length && node.children[0].tag === 'text') {
        const textNode = node.children[0];
        doc.insert(textNode.text, Object.assign(Object.assign({}, parentAttrs), attrs));
    }
    else {
        node.children.forEach((child, index) => {
            var _a, _b;
            const line = new Delta();
            if (blockTags.includes(child.tag) || ((_a = child.style) === null || _a === void 0 ? void 0 : _a.textAlign)) {
                if ((child.tag === 'p' && index > 0) || child.tag !== 'p') {
                    const lineAttrs = {};
                    if (child.tag.startsWith('h')) {
                        lineAttrs.header = parseInt(child.tag.substring(1), 10);
                    }
                    if (child.tag === 'blockquote') {
                        lineAttrs.blockquote = true;
                    }
                    if (child.tag === 'ol') {
                        parentAttrs.list = 'ordered';
                    }
                    if (child.tag === 'ul') {
                        parentAttrs.list = 'bullet';
                    }
                    if (child.tag === 'li') {
                        if (index === 0) {
                            doc.insert('\n');
                        }
                        lineAttrs.list = parentAttrs.list;
                    }
                    if ((_b = child.style) === null || _b === void 0 ? void 0 : _b.textAlign) {
                        lineAttrs.align = child.style.textAlign;
                    }
                    if (child.tag === 'img') {
                        doc.insert({ image: child.src });
                    }
                    line.insert('\n', lineAttrs);
                }
            }
            const childLine = processJanusChildren(child, new Delta(), attrs);
            doc = line.compose(childLine).compose(doc);
        });
    }
    return doc;
};
const blockTags = ['p', 'blockquote', 'ol', 'ul', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'img'];
export const convertJanusToQuill = (nodes) => {
    let doc = new Delta();
    const parentAttrs = {};
    nodes.forEach((node, index) => {
        var _a, _b;
        const line = new Delta();
        if (blockTags.includes(node.tag) || ((_a = node.style) === null || _a === void 0 ? void 0 : _a.textAlign)) {
            if ((node.tag === 'p' && index > 0) || node.tag !== 'p') {
                const attrs = {};
                if (node.tag.startsWith('h')) {
                    attrs.header = parseInt(node.tag.substring(1), 10);
                }
                if (node.tag === 'blockquote') {
                    attrs.blockquote = true;
                }
                if (node.tag === 'ol') {
                    parentAttrs.list = 'ordered';
                }
                if (node.tag === 'ul') {
                    parentAttrs.list = 'bullet';
                }
                if (node.tag === 'li') {
                    attrs.list = parentAttrs.list;
                }
                if ((_b = node.style) === null || _b === void 0 ? void 0 : _b.textAlign) {
                    if (index === 1) {
                        doc.insert('\n');
                    }
                    attrs.align = node.style.textAlign;
                }
                line.insert('\n', attrs);
            }
        }
        const childLine = processJanusChildren(node, new Delta(), parentAttrs);
        doc = line.compose(childLine).compose(doc);
    });
    /*   console.log('J -> Q', { nodes, doc }); */
    return doc;
};
//# sourceMappingURL=quill-utils.js.map