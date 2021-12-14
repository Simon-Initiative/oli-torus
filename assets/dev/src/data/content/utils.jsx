import { toSimpleText } from 'components/editing/utils';
import { isContentItem } from 'data/content/writers/writer';
import * as React from 'react';
import { Element } from 'slate';
// float_left and float_right no longer supported as options
export function displayModelToClassName(display) {
    switch (display) {
        case 'float_left':
        case 'float_right':
        case 'block':
            return 'd-block';
        default:
            return 'd-block';
    }
}
export function getContentDescription(content) {
    let simpleText;
    if (content.children.length > 0) {
        let i = 0;
        while (i < content.children.length) {
            const item = content.children[i];
            switch (item.type) {
                case 'audio':
                    return <i>Audio Clip</i>;
                case 'code':
                    return <i>Code Block</i>;
                case 'img':
                    return <i>Image</i>;
                case 'youtube':
                    return <i>YouTube Video</i>;
                case 'table':
                    return <i>Table</i>;
                case 'math':
                    return <i>Math Expression</i>;
                case 'ol':
                case 'ul':
                    return <i>List</i>;
                case 'h1':
                case 'h2':
                case 'h3':
                case 'h4':
                case 'h5':
                case 'h6':
                case 'p':
                case 'blockquote':
                    simpleText = toSimpleText(item).trim();
                    if (simpleText !== '') {
                        return <span>{simpleText}</span>;
                    }
            }
            i = i + 1;
        }
    }
    return <i>Empty</i>;
}
export const centeredAbove = ({ popoverRect, childRect }, yOffset = 56) => {
    return {
        top: childRect.top + window.scrollY - yOffset,
        left: childRect.left + window.window.scrollX + childRect.width / 2 - popoverRect.width / 2,
    };
};
const contentBfs = (content, cb) => {
    if (Array.isArray(content)) {
        return content.forEach((c) => contentBfs(c, cb));
    }
    cb(content);
    if (isContentItem(content) || Element.isElement(content)) {
        const children = content.children;
        if (Array.isArray(children)) {
            return contentBfs(children.filter((c) => c.type !== 'input_ref'), cb);
        }
    }
};
export const elementsOfType = (content, type) => {
    const elements = [];
    contentBfs(content, (elem) => {
        if (Element.isElement(elem) && elem.type === type) {
            elements.push(elem);
        }
    });
    return elements;
};
//# sourceMappingURL=utils.jsx.map