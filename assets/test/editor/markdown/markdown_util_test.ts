import { getMarkdownWarnings } from 'components/editing/markdown_editor/markdown_util';

describe('markdown utils', () => {
  describe('getMarkdownWarnings', () => {
    it('should return an empty array for a valid model', () => {
      const model: any[] = [
        {
          type: 'p',
          id: '1',
          children: [{ text: 'This is a paragraph.' }],
        },
      ];
      expect(getMarkdownWarnings(model)).toEqual([]);
    });

    it('should only report on each unsupported element once', () => {
      const model: any[] = [
        {
          type: 'unsupported',
          id: '1',
          children: [{ text: 'This is an unsupported element.' }],
        },
        {
          type: 'unsupported',
          id: '2',
          children: [{ text: 'This is an unsupported element 2.' }],
        },
      ];
      expect(getMarkdownWarnings(model)).toEqual(['Unsupported']);
    });

    it('should return a warning for an unsupported element', () => {
      const model: any[] = [
        {
          type: 'unsupported',
          id: '1',
          children: [{ text: 'This is an unsupported element.' }],
        },
      ];
      expect(getMarkdownWarnings(model)).toEqual(['Unsupported']);
    });

    it('should return a warning for an unsupported text mark', () => {
      const model: any[] = [
        {
          type: 'p',
          id: '1',
          children: [{ text: 'This is ' }, { text: 'bold', bold: true }, { text: ' text.' }],
        },
      ];
      expect(getMarkdownWarnings(model)).toEqual(['Bold']);
    });

    it('should return multiple warnings for multiple unsupported elements and text marks', () => {
      const model: any[] = [
        {
          type: 'unsupported',
          id: '1',
          children: [{ text: 'This is an unsupported element.' }],
        },
        {
          type: 'p',
          id: '2',
          children: [{ text: 'This is ' }, { text: 'bold', bold: true }, { text: ' text.' }],
        },
      ];
      expect(getMarkdownWarnings(model)).toEqual(['Unsupported', 'Bold']);
    });

    it('should recursively check children for warnings', () => {
      const model: any[] = [
        {
          type: 'p',
          id: '1',
          children: [
            { text: 'This is a paragraph with ' },
            { text: 'bold', bold: true },
            { text: ' text.' },
          ],
        },
        {
          type: 'unsupported',
          id: '2',
          children: [{ text: 'This is an unsupported element.' }],
        },
      ];
      expect(getMarkdownWarnings(model)).toEqual(['Unsupported', 'Bold']);
    });
  });
});
