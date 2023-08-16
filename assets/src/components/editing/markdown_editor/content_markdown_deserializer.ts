import { Text } from 'slate';
import {
  AllModelElements,
  Caption,
  Inline,
  ListItem,
  OrderedList,
  Paragraph,
  UnorderedList,
} from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';

type ListType = 'ul' | 'ol';

export interface DeserializationContext {
  listStack: ListType[];
  nodeStack: AllModelElements[];
}

/*
  Takes our content model, and converts it to a markdown string representation.
*/
export const contentMarkdownDeserializer = (
  content: (FormattedText | AllModelElements | Inline)[] | undefined | Caption,
  context: DeserializationContext = { listStack: [], nodeStack: [] },
  parent?: AllModelElements,
): string => {
  if (!content) return '';
  if (typeof content === 'string') return content;
  return content
    .map(deserializeNode(context))
    .filter((line) => typeof line === 'string')
    .join('');
};

export const deserializeNode =
  (context: DeserializationContext) =>
  (node: AllModelElements | Text): string | null => {
    if ('text' in node && node.text) {
      return node.text;
    }

    const model = node as AllModelElements;

    const newContext = {
      ...context,
      nodeStack: [...context.nodeStack, model],
    };

    switch (model.type) {
      case 'h1':
        return `# ${contentMarkdownDeserializer(model.children, newContext, model)}\n\n`;
      case 'h2':
        return `## ${contentMarkdownDeserializer(model.children, newContext, model)}\n\n`;
      case 'h3':
        return `### ${contentMarkdownDeserializer(model.children, newContext, model)}\n\n`;
      case 'h4':
        return `#### ${contentMarkdownDeserializer(model.children, newContext, model)}\n\n`;
      case 'h5':
        return `##### ${contentMarkdownDeserializer(model.children, newContext, model)}\n\n`;
      case 'h6':
        return `###### ${contentMarkdownDeserializer(model.children, newContext, model)}\n\n`;
      case 'p':
        return paragraph(model, newContext);
      case 'ul':
      case 'ol':
        return list(model, newContext);

      case 'li':
        return listItem(model, 0, newContext); // Shouldn't really get bare list items, maybe this isn't neccessary

      case 'code':
        return `\`${contentMarkdownDeserializer(model.children, newContext, model)}\`\n\n`;
      case 'blockquote':
        return blockquote(model, newContext);
      case 'a':
        return `[${contentMarkdownDeserializer(model.children, newContext, model)}](${model.href})`;
      case 'img':
        return `![${contentMarkdownDeserializer(model.caption, newContext, model)}](${model.src})`;
    }

    if ('children' in node && node.children) {
      // Unknown nodes with children
      console.info('Unknown node', node);
      return contentMarkdownDeserializer(node.children as AllModelElements[]);
    }

    return null;
  };

const blockquote = (model: AllModelElements, context: DeserializationContext): string => {
  const includeBlankLine = !isParent(context, ['li', 'ul', 'ol', 'blockquote']);
  const lines = contentMarkdownDeserializer(model.children, context, model).split('\n');
  const indentedLines = lines.map((line) => (line === '' ? line : `> ${line}`)).join('\n');

  const newLine = includeBlankLine ? '\n' : '';

  return `${indentedLines}${newLine}`;
};

const list = (model: OrderedList | UnorderedList, context: DeserializationContext): string => {
  const isNestedList = hasAncestor(context, ['ul', 'ol']);

  const endingNewline = isNestedList ? '' : '\n'; // For nested lists, don't need an extra blank line

  const newContext = {
    ...context,
    listStack: [...context.listStack, model.type],
  };

  return (
    model.children
      .map((li, index) => {
        if (isListItem(li)) {
          return listItem(li, index, newContext);
        }
        if (isList(li)) {
          return list(li, {
            ...newContext,
            nodeStack: [...newContext.nodeStack, li],
          });
        }
        console.warn('Invalid child of list', li);
        return null;
      })
      .join('') + endingNewline
  );
};

const isList = (node: AllModelElements | Text): node is OrderedList | UnorderedList =>
  'type' in node && (node.type === 'ul' || node.type === 'ol');

const isListItem = (node: AllModelElements | Text): node is ListItem =>
  'type' in node && node.type === 'li';

const paragraph = (model: Paragraph, context: DeserializationContext): string => {
  const includeLineBreak = !isParent(context, ['img']);
  const includeBlankLine = !isParent(context, ['li', 'ul', 'ol', 'blockquote']);

  const linebreak = includeLineBreak ? '\n' : '';
  const newLine = includeBlankLine ? '\n' : '';
  const newlines = `${linebreak}${newLine}`;
  return `${contentMarkdownDeserializer(model.children, context, model)}${newlines}`;
};

const listItem = (model: ListItem, index: number, context: DeserializationContext) => {
  const indent = '  '.repeat(context.listStack.length - 1);
  const marker = context.listStack[context.listStack.length - 1] === 'ul' ? '-' : `${index + 1}.`;

  context = {
    ...context,
    nodeStack: [...context.nodeStack, model],
  };

  const children = contentMarkdownDeserializer(model.children, context);
  // If we have multiple lines in the children, everyone one but the first should be indented.
  const indentedChildren = children
    .split('\n')
    .map((line, lineIndex) => {
      if (lineIndex === 0) return line;
      if (line === '') return line;
      return `${indent}${line}`;
    })
    .join('\n');

  return `${indent}${marker} ${indentedChildren}`;
};

const hasAncestor = (context: DeserializationContext, types: AllModelElements['type'][]) => {
  return context.nodeStack.slice(0, -1).some((node) => types.includes(node.type));
};

// Our current node is already on the stack, so we need to go back one
const parentNode = (context: DeserializationContext) => {
  return context.nodeStack[context.nodeStack.length - 2];
};

const isParent = (context: DeserializationContext, types: AllModelElements['type'][]) => {
  return types.includes(parentNode(context)?.type || '');
};
