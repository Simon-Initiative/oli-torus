import React, { useEffect, useMemo, useRef, useState } from 'react';
import ReactQuill, { Quill } from 'react-quill';
import Delta from 'quill-delta';
import register from '../customElementWrapper';
import {
  embedCorrectAnswersInString,
  extractFormattedHTMLFromQuillNodes,
  generateFIBStructure,
  mergeParsedWithExistingBlanks,
  syncOptionsFromText,
  transformOptionsToNormalized,
} from '../janus-fill-blanks/FIBUtils';
import { OptionItem, QuillFIBOptionEditor } from './QuillFIBOptionEditor';
import { QuillImageUploader } from './QuillImageUploader';
import { convertJanusToQuill, convertQuillToJanus } from './quill-utils';

interface QuillEditorProps {
  tree: any[];
  html?: string;
  onChange: (changes: any) => void;
  onSave: (contents: any) => void;
  onCancel: () => void;
  showSaveCancelButtons?: boolean;
  showimagecontrol?: boolean;
  showfibinsertoptioncontrol?: boolean;
  options?: any;
}

const supportedFonts = ['Initial', 'Arial', 'Times New Roman', 'Sans Serif'];

// get code friendly font names
const getFontName = (font: string) => {
  return font.toLowerCase().replace(/\s/g, '-');
};
Quill.import('ui/icons')['insertFIBOption'] = '<i class="fa-solid fa-square-caret-down"></i>';

const FontAttributor = Quill.import('attributors/class/font');
FontAttributor.whitelist = supportedFonts.map(getFontName);
Quill.register(FontAttributor, true);

const FontSizeAttributor = Quill.import('attributors/style/size');
// Expanding the font-size whitelist to include sizes above 20px, ensuring that migrated lessons with larger font sizes render correctly.
// This also resolves an issue where editing a text field with a larger font size previously caused the editor to remove the font size, making the text smaller.
FontSizeAttributor.whitelist = [
  '10px',
  '12px',
  '14px',
  '16px',
  '18px',
  '20px',
  '24px',
  '32px',
  '36px',
  '48px',
  '72px',
];
Quill.register(FontSizeAttributor, true);

const getCssForFonts = (fonts: string[]) => {
  return fonts
    .map(
      (font) => `
    .ql-snow .ql-picker.ql-font .ql-picker-label[data-value='${getFontName(font)}']::before,
    .ql-snow .ql-picker.ql-font .ql-picker-item[data-value='${getFontName(font)}']::before
    {
      content: '${font}';
      font-family: '${font}';
    }
    .ql-font-${getFontName(font)} {
      font-family: '${font}';
    }
  `,
    )
    .join('\n');
};

const fontStyles = `${getCssForFonts(supportedFonts)}
/* default normal size */
.ql-container {
  font-size: 20px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="12px"]::before {
  content: '12px';
  font-size: 12px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="14px"]::before {
  content: '14px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="16px"]::before {
  content: '16px';
  font-size: 16px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="18px"]::before {
  content: '18px';
  font-size: 18px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="20px"]::before {
  content: '20px';
  font-size: 20px !important;
}
  .ql-snow .ql-picker.ql-size .ql-picker-label[data-value="12px"]::before {
  content: '12px';
}
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="14px"]::before {
  content: '14px';
}
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="16px"]::before {
  content: '16px';
}
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="18px"]::before {
  content: '18px';
}
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="20px"]::before {
  content: '20px';
}

`;
let localOptions: any = [];
export const QuillEditor: React.FC<QuillEditorProps> = ({
  tree,
  html,
  showSaveCancelButtons = false,
  onChange,
  onSave,
  onCancel,
  showimagecontrol = false,
  showfibinsertoptioncontrol = false,
  options = '',
}) => {
  const quill: any = useRef();
  const [contents, setContents] = React.useState<any>(tree);
  const [selectedKey, setSelectedKey] = useState<number>(0);
  const [fibElements, setFibElements] = React.useState<any>([]);
  const [delta, setDelta] = React.useState<any>(convertJanusToQuill(tree));
  const [currentQuillRange, setCurrentQuillRange] = React.useState<number>(0);
  const [showImageSelectorDailog, setShowImageSelectorDailog] = React.useState<boolean>(false);
  const [showFIBOptionEditorDailog, setShowFIBOptionEditorDailog] = React.useState<boolean>(false);
  const customHandlers = {
    adaptivity: function (value: string) {
      const range = this.quill.getSelection();
      let selectionValue = '';
      if (range && range.length > 0) {
        selectionValue = this.quill.getText(range.index, range.length);
        if (selectionValue.charAt(0) === '{') {
          selectionValue = selectionValue.substring(1, selectionValue.length - 1);
        }
      }
      const expression = prompt('Enter the Expression', selectionValue);
      if (expression) {
        this.quill.insertText(range.index, `{${expression}}`);
        this.quill.deleteText(range.index + expression.length + 2, expression.length + 2);
      }
    },
    image: function (value: string) {
      setShowImageSelectorDailog(true);
      setCurrentQuillRange(this.quill.getSelection()?.index || 0);
    },
    insertFIBOption: function (value: string) {
      const range = this.quill.getSelection();
      const insertIndex = range ? range.index : this.quill.getLength();
      setCurrentQuillRange(insertIndex);

      const fullText = quill.current?.getEditor().getText() ?? '';
      const cursorIndex = insertIndex;

      // Match all {...} blocks
      const placeholderRegex = /\{[^{}]*\}/g;
      const results: { text: string; start: number; end: number }[] = [];

      let match: RegExpExecArray | null;
      while ((match = placeholderRegex.exec(fullText)) !== null) {
        results.push({
          text: match[0],
          start: match.index,
          end: match.index + match[0].length,
        });
      }

      let isInsideExistingBlank = false;
      let iMatchCounter = 0;
      for (const block of results) {
        const { text, start: matchStart, end: matchEnd } = block;

        if (cursorIndex >= matchStart && cursorIndex <= matchEnd) {
          isInsideExistingBlank = true;

          // Extract options inside this {...}
          const extractedOptions: string[] = [];
          const optionRegex = /"([^"]+)"\*?/g;
          let innerMatch: RegExpExecArray | null;
          while ((innerMatch = optionRegex.exec(text)) !== null) {
            extractedOptions.push(innerMatch[1]);
          }
          setSelectedKey(iMatchCounter);
          setShowFIBOptionEditorDailog(true);
          break;
        }
        iMatchCounter++;
      }

      if (!isInsideExistingBlank) {
        // Insert a new blank
        const newKey = `New blank Option`;
        quill.current?.getEditor().insertText(insertIndex, `{"${newKey}"}`);

        // Update FIB structure and dropdown options
        const updatedText = quill.current?.getEditor().getText() ?? '';
        const parsed = generateFIBStructure(updatedText);
        const quillOptions = transformOptionsToNormalized(parsed.elements);
        const updatedFIBOptions = mergeParsedWithExistingBlanks(localOptions, quillOptions);
        setFibElements(updatedFIBOptions);
        setSelectedKey(iMatchCounter);
        setShowFIBOptionEditorDailog(true);
      }
    },
  };
  const handleImageDetailsSave = (imageURL: string, imageAltText: string) => {
    setShowImageSelectorDailog(false);
    if (quill?.current) {
      if (imageURL) {
        const img = document.createElement('img');
        img.src = imageURL;
        img.alt = imageAltText;
        // quill.insertEmbed does not allow inserting any additional attributes hence using dangerouslyPasteHTML function to set the Alt text
        // This code only gets executed when user tries to add a Image in MCQ Options.
        quill.current.editor.clipboard.dangerouslyPasteHTML(currentQuillRange, img.outerHTML);
      }
    }
  };

  const handleFIBOptionsEditorSave = (Options: Array<OptionItem>) => {
    setShowFIBOptionEditorDailog(false);
    if (quill?.current) {
      const janusText = convertQuillToJanus(
        new Delta(quill.current?.getEditor()?.getContents().ops),
      );
      const collectedText = extractFormattedHTMLFromQuillNodes(janusText);
      localOptions = Options;
      const updatedString = embedCorrectAnswersInString(collectedText, Options);
      const span = document.createElement('span');
      span.innerHTML = updatedString;
      span.style.fontSize = '16px';
      const editor = quill.current.getEditor();
      // Clear all content first
      editor.setText('');
      quill.current.editor.clipboard.dangerouslyPasteHTML(0, span.outerHTML);
    }
  };

  const handleImageUploaderDailogClose = () => {
    setShowImageSelectorDailog(false);
  };

  const handleFIBOptionsEditorClose = () => {
    setShowFIBOptionEditorDailog(false);
  };
  /*  console.log('[QuillEditor]', { tree, html }); */

  useEffect(() => {
    const convertedTree = convertJanusToQuill(tree);
    /* console.log('[QuillEditor] convertedTree', convertedTree); */
    setDelta(convertedTree);
  }, [tree]);

  useEffect(() => {
    if (options?.length) {
      const myOptions = JSON.parse(options);
      setFibElements(myOptions);
      localOptions = myOptions;
    }
  }, [options]);

  const handleSave = React.useCallback(() => {
    if (!contents) {
      return;
    }
    onSave(contents);
  }, [onSave, contents]);

  const handleQuillChange = React.useCallback(
    (content, delta, source, editor) => {
      // console.log('quill changes', { content, delta, source, editor });
      const janusText = convertQuillToJanus(new Delta(editor.getContents().ops));
      // console.log('JANUS TEXT', janusText);
      let normalizedFIBOptions: any = [];
      if (showfibinsertoptioncontrol) {
        const plainTextFromQuillNodes = extractFormattedHTMLFromQuillNodes(janusText);
        if (plainTextFromQuillNodes?.trim()?.length) {
          normalizedFIBOptions = syncOptionsFromText(plainTextFromQuillNodes, localOptions);
          setFibElements(normalizedFIBOptions || []);
          localOptions = normalizedFIBOptions;
        }
      }
      setContents(janusText);
      onChange({ value: janusText, options: normalizedFIBOptions });
    },
    [onChange],
  );
  const toolbarContainerDefault = showfibinsertoptioncontrol
    ? [
        ['bold', 'italic', 'underline'], // toggled buttons
        [{ script: 'sub' }, { script: 'super' }], // superscript/subscript
        ['insertFIBOption'],
      ]
    : [
        ['bold', 'italic', 'underline', 'strike'], // toggled buttons
        ['blockquote' /* , 'code-block' */],

        [{ list: 'ordered' }, { list: 'bullet' }],
        [{ script: 'sub' }, { script: 'super' }], // superscript/subscript
        [{ indent: '-1' }, { indent: '+1' }], // outdent/indent

        [{ header: [1, 2, 3, 4, 5, 6, false] }],
        [
          {
            color: [
              '#000000',
              '#e60000',
              '#ff9900',
              '#ffff00',
              '#008a00',
              '#0066cc',
              '#9933ff',
              '#ffffff',
              '#facccc',
              '#ffebcc',
              '#ffffcc',
              '#cce8cc',
              '#cce0f5',
              '#ebd6ff',
              '#bbbbbb',
              '#f06666',
              '#ffc266',
              '#ffff66',
              '#66b966',
              '#66a3e0',
              '#c285ff',
              '#888888',
              '#a10000',
              '#b26b00',
              '#b2b200',
              '#006100',
              '#0047b2',
              '#6b24b2',
              '#444444',
              '#5c0000',
              '#663d00',
              '#666600',
              '#003700',
              '#002966',
              '#3d1466',
            ],
          },
          { background: [] },
        ], // dropdown with defaults from theme
        [{ font: FontAttributor.whitelist }, { size: ['12px', '14px', '16px', '18px', '20px'] }],
        [{ align: [] }],
        ['link', 'adaptivity'],
        ['clean'], // remove formatting button
        showimagecontrol ? ['image'] : [],
      ];
  const modules = useMemo(
    () => ({
      toolbar: {
        container: toolbarContainerDefault,
        handlers: customHandlers,
      },
    }),
    [],
  );

  return (
    <React.Fragment>
      <link rel="stylesheet" href="https://cdn.quilljs.com/1.3.6/quill.snow.css" />
      <style>{fontStyles}</style>
      <div
        style={{
          maxWidth: 520,
          height: '100%',
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: '#fff',
        }}
      >
        <ReactQuill
          ref={quill}
          style={{ maxHeight: '100%' }}
          modules={modules}
          defaultValue={delta}
          onChange={handleQuillChange}
        />
        {showSaveCancelButtons && (
          <>
            <button onClick={handleSave}>Save</button>
            <button onClick={onCancel}>Cancel</button>
          </>
        )}
      </div>
      {
        <QuillImageUploader
          showImageSelectorDailog={showImageSelectorDailog}
          handleImageDetailsSave={handleImageDetailsSave}
          handleImageDailogClose={handleImageUploaderDailogClose}
        ></QuillImageUploader>
      }
      {showFIBOptionEditorDailog && (
        <QuillFIBOptionEditor
          showOptionDailog={showFIBOptionEditorDailog}
          handleOptionSave={handleFIBOptionsEditorSave}
          handleOptionDailogClose={handleFIBOptionsEditorClose}
          Options={fibElements}
          selectedIndex={selectedKey}
        ></QuillFIBOptionEditor>
      )}
    </React.Fragment>
  );
};

export const tagName = 'tf-quill-editor';

export const registerEditor = () => {
  if (!customElements.get(tagName)) {
    register(
      QuillEditor,
      tagName,
      ['tree', 'html', 'showimagecontrol', 'showCustomOptionControl'],
      {
        shadow: false, // shadow dom breaks the quill toolbar
        customEvents: {
          onChange: `${tagName}-change`,
          onSave: `${tagName}-save`,
          onCancel: `${tagName}-cancel`,
        },
        attrs: {
          tree: {
            json: true,
          },
        },
      },
    );
  }
};
