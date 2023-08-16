import { Editor } from 'slate';
import { onYouTubePaste } from 'components/editing/editor/paste/onYouTubePaste';
import { mockEditor, mockInsertNodes, simulateEvent } from './paste_test_utils';

describe('onYouTubePaste', () => {
  let editor: Editor;
  let insertNodesSpy: jest.SpyInstance;

  beforeEach(() => {
    editor = mockEditor();
    insertNodesSpy = mockInsertNodes();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should not do anything if no text is pasted', () => {
    const event = simulateEvent('', '');
    onYouTubePaste(event, editor);
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(insertNodesSpy).not.toHaveBeenCalled();
  });

  it('should insert a youtube node if a youtube link is pasted', () => {
    const event = simulateEvent('https://www.youtube.com/watch?v=my-video', '');
    onYouTubePaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertNodesSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'youtube',
        src: 'my-video',
        children: [{ text: '' }],
        id: expect.any(String),
      },
    ]);
  });

  it('should insert a youtube node if a youtu.be link is pasted', () => {
    const event = simulateEvent('https://www.youtu.be/watch?v=my-video', '');
    onYouTubePaste(event, editor);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(insertNodesSpy).toHaveBeenCalledWith(editor, [
      {
        type: 'youtube',
        src: 'my-video',
        children: [{ text: '' }],
        id: expect.any(String),
      },
    ]);
  });
});
