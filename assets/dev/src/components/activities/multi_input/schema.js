import { Maybe } from 'tsmonad';
import { assertNever } from 'utils/common';
export const multiInputTypes = ['dropdown', 'text', 'numeric'];
export const multiInputTypeFriendly = (type) => Maybe.maybe({
    dropdown: 'Dropdown',
    numeric: 'Number',
    text: 'Text',
}[type]).valueOr(assertNever(type));
//# sourceMappingURL=schema.js.map