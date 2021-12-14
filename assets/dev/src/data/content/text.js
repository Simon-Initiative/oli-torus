export function toSimpleText(node) {
    return toSimpleTextHelper(node, '');
}
function toSimpleTextHelper(node, text) {
    return node.children.reduce((p, c) => {
        let updatedText = p;
        if (c.text) {
            updatedText += c.text;
        }
        if (c.children) {
            return toSimpleTextHelper(c, updatedText);
        }
        return updatedText;
    }, text);
}
//# sourceMappingURL=text.js.map