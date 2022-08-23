import { StructuredContent } from 'data/content/resource';
import { clone } from 'utils/common';

// recursively ensure that all children are not empty and at least have a {text: ''}
export const slateFixer = (content: StructuredContent) => {
  const result = clone(content);
  if (result.children) {
    if (result.children.length === 0) {
      result.children = [{ text: '' }];
    } else {
      result.children = result.children.map(slateFixer);
    }
  }
  return result;
};
