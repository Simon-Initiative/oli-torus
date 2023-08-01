import { Editor, Transforms } from 'slate';

export const simulateEvent = (
  plainText: string,
  htmlText: string,
): React.ClipboardEvent<HTMLDivElement> => {
  return {
    preventDefault: jest.fn(),
    clipboardData: {
      getData: (dataType: string) => {
        if (dataType === 'text/html') {
          return htmlText;
        }
        return plainText;
      },
    },
  } as unknown as React.ClipboardEvent<HTMLDivElement>;
};

export const mockInsertNodes = () =>
  jest.spyOn(Transforms, 'insertNodes').mockImplementation(() => true);

export const mockEditor = () =>
  ({
    children: [],
    selection: null,
  } as unknown as Editor);
