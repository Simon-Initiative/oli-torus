import { Descendant, Editor, Element, createEditor } from 'slate';
import { withHistory } from 'slate-history';
import { withReact } from 'slate-react';
import {
  NormalizerOptions,
  installNormalizer,
} from 'components/editing/editor/normalizers/normalizer';
import { withInlines } from 'components/editing/editor/overrides/inlines';
import { withTables } from 'components/editing/editor/overrides/tables';
import { withVoids } from 'components/editing/editor/overrides/voids';

export const expectAnyEmptyParagraph = {
  type: 'p',
  id: expect.any(String),
  children: [{ text: '' }],
} as Descendant;

export const expectConsoleMessage = (
  message: string | string[],
  calls: jest.SpyInstance['mock']['calls'],
) => {
  expect(calls).toContainEqual([message]);
};

/**
 * Utility function to help test our normalizer suite. This will mock out console.warn and console.error
 * so you can test if the normalizer is generating the expected debug output as well.
 *
 * @param content Slate content to normalize
 * @returns The editor, and the console.warn and console.error calls that were made during normalization
 */
export const runNormalizer = (
  content: Descendant[],
  {
    showLogs = false,
    normalizerOptions = {},
  }: {
    showLogs?: boolean;
    normalizerOptions?: Partial<NormalizerOptions>;
  } = {},
): {
  editor: Editor;
  consoleErrorCalls: jest.SpyInstance['mock']['calls'];
  consoleWarnCalls: jest.SpyInstance['mock']['calls'];
} => {
  const warn = jest.spyOn(console, 'warn').mockImplementation((...args) => {
    if (showLogs) {
      console.log('console.warn', ...args);
    }
  });
  const error = jest.spyOn(console, 'error').mockImplementation((...args) => {
    if (showLogs) {
      console.log('console.error', ...args);
    }
  });

  jest.useFakeTimers();
  const editor = withReact(withHistory(withTables(withInlines(withVoids(createEditor())))));
  editor.children = [...content];
  installNormalizer(editor, {}, normalizerOptions);
  Editor.normalize(editor, { force: true });

  jest.runAllTimers();
  jest.runAllImmediates();

  const consoleWarnCalls = warn.mock.calls;
  const consoleErrorCalls = error.mock.calls;
  jest.resetAllMocks();
  jest.useRealTimers();

  return {
    editor,
    consoleWarnCalls,
    consoleErrorCalls,
  };
};

/* Replaces {id: "xxxx"} with {id: expect.any(String)} */
export const expectAnyId = (content: Descendant | Descendant[]): Descendant | Descendant[] => {
  if (!Array.isArray(content)) {
    const [first] = expectAnyId([content]) as Descendant[];
    return first;
  }

  return content.map((node) => {
    if (Element.isElement(node) && 'id' in node) {
      return {
        ...node,
        id: expect.any(String),
        children: expectAnyId(node.children),
      };
    }
    return node;
  }) as Descendant[];
};
