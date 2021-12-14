import { schema } from 'data/content/model/schema';
import { Element } from 'slate';
export const withInlines = (editor) => {
    editor.isInline = (element) => {
        try {
            if (Element.isElement(element)) {
                return !schema[element.type].isBlock;
            }
            return false;
        }
        catch (e) {
            return false;
        }
    };
    return editor;
};
//# sourceMappingURL=inlines.js.map