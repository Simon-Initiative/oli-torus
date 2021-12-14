import { schema } from 'data/content/model/schema';
import { Element } from 'slate';
// Override isVoid to incorporate our schema's opinion on which
export const withVoids = (editor) => {
    editor.isVoid = (element) => {
        try {
            if (Element.isElement(element)) {
                return schema[element.type].isVoid;
            }
            return false;
        }
        catch (e) {
            return false;
        }
    };
    return editor;
};
//# sourceMappingURL=voids.js.map