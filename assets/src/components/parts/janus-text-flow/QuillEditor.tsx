import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Alert, Modal } from 'react-bootstrap';
import ReactQuill, { Quill } from 'react-quill';
import Delta from 'quill-delta';
import { normalizeHref } from 'data/content/model/elements/utils';
import * as Persistence from 'data/persistence/resource';
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
import {
  convertJanusToQuill,
  convertQuillToJanus,
  fontFamilyMapping,
  getFontName,
  getSupportedFonts,
} from './quill-utils';

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
  projectSlug?: string;
}

// Get supported fonts from shared mapping (ensures consistency)
const supportedFonts = getSupportedFonts();
Quill.import('ui/icons')['insertFIBOption'] =
  '<i class="fa-solid fa-square-caret-down" style="color:rgb(55, 58, 68)"></i>';

const FontAttributor = Quill.import('attributors/class/font');
FontAttributor.whitelist = supportedFonts.map(getFontName);
Quill.register(FontAttributor, true);

const FontSizeAttributor = Quill.import('attributors/style/size');
// Expanding the font-size whitelist to include the newly supported responsive sizes while keeping compatibility with migrated lessons.
FontSizeAttributor.whitelist = ['16px', '14px', '18px', '20px', '24px', '28px', '32px'];
Quill.register(FontSizeAttributor, true);

const Parchment = Quill.import('parchment');
const TextStyleAttributor = new Parchment.Attributor.Class('textStyle', 'ql-text-style', {
  scope: Parchment.Scope.BLOCK,
});
Quill.register(TextStyleAttributor, true);

type TextStyleOption = 'normal' | 'h1' | 'h2' | 'h3' | 'h4' | 'caption';

const STYLE_DIVIDER_VALUE = '__style-divider__';
const NORMAL_FONT_CODE = getFontName('Open Sans');
const NORMAL_FONT_SIZE = '16px';
const textStyleDefaults: Record<
  Exclude<TextStyleOption, 'normal'>,
  { font: string; size: string; header: number | false }
> = {
  h1: { font: getFontName('Montserrat'), size: '32px', header: 1 },
  h2: { font: getFontName('Montserrat'), size: '28px', header: 2 },
  h3: { font: getFontName('Montserrat'), size: '24px', header: 3 },
  h4: { font: getFontName('Montserrat'), size: '20px', header: 4 },
  caption: { font: getFontName('Open Sans'), size: '14px', header: false },
};

const clearLineFontAndSize = (editor: any, range: { index: number; length: number }) => {
  const lines = editor.getLines(range.index, Math.max(1, range.length));
  lines.forEach((line: any) => {
    const lineIndex = editor.getIndex(line);
    const textLength = Math.max(0, line.length() - 1);
    if (textLength > 0) {
      editor.formatText(lineIndex, textLength, 'font', false, 'user');
      editor.formatText(lineIndex, textLength, 'size', false, 'user');
    }
  });
};

const applyTextStyle = (editor: any, rawStyleValue: string) => {
  const range = editor.getSelection();
  if (!range || !rawStyleValue || rawStyleValue === STYLE_DIVIDER_VALUE) {
    return;
  }

  const styleValue = rawStyleValue as TextStyleOption;
  const lineRange = { index: range.index, length: Math.max(1, range.length) };

  clearLineFontAndSize(editor, lineRange);
  editor.formatLine(lineRange.index, lineRange.length, 'header', false, 'user');
  editor.formatLine(lineRange.index, lineRange.length, 'textStyle', false, 'user');
  editor.format('font', false, 'user');
  editor.format('size', false, 'user');

  if (styleValue === 'normal') {
    // Apply default normal font/size so the toolbar reflects Open Sans / 16px.
    const linesForNormal = editor.getLines(lineRange.index, lineRange.length);
    linesForNormal.forEach((line: any) => {
      const lineIndex = editor.getIndex(line);
      const textLength = Math.max(0, line.length() - 1);
      if (textLength > 0) {
        editor.formatText(lineIndex, textLength, 'font', NORMAL_FONT_CODE, 'user');
        editor.formatText(lineIndex, textLength, 'size', NORMAL_FONT_SIZE, 'user');
      }
    });
    editor.format('font', NORMAL_FONT_CODE, 'user');
    editor.format('size', NORMAL_FONT_SIZE, 'user');
    editor.formatLine(lineRange.index, lineRange.length, 'textStyle', 'normal', 'user');
    editor.format('textStyle', 'normal', 'user');
    return;
  }

  const defaults = textStyleDefaults[styleValue];
  editor.formatLine(lineRange.index, lineRange.length, 'header', defaults.header, 'user');
  editor.formatLine(lineRange.index, lineRange.length, 'textStyle', styleValue, 'user');
  editor.format('textStyle', styleValue, 'user');

  const lines = editor.getLines(lineRange.index, lineRange.length);
  lines.forEach((line: any) => {
    const lineIndex = editor.getIndex(line);
    const textLength = Math.max(0, line.length() - 1);
    if (textLength > 0) {
      editor.formatText(lineIndex, textLength, 'font', defaults.font, 'user');
      editor.formatText(lineIndex, textLength, 'size', defaults.size, 'user');
    }
  });

  editor.format('font', defaults.font, 'user');
  editor.format('size', defaults.size, 'user');
};

const BaseImage = Quill.import('formats/image');

class ImageWithAlt extends BaseImage {
  static blotName = 'image';
  static tagName = 'IMG';

  static create(value: any) {
    const node = super.create(value);

    if (typeof value === 'object') {
      node.setAttribute('src', value.src);
      if (value.alt) node.setAttribute('alt', value.alt);
    } else {
      node.setAttribute('src', value);
    }
    return node;
  }

  static value(node: HTMLElement) {
    return {
      src: node.getAttribute('src'),
      alt: node.getAttribute('alt'),
    };
  }

  static formats(node: HTMLElement) {
    return {
      alt: node.getAttribute('alt'),
    };
  }
}

Quill.register(ImageWithAlt, true);

const getCssForFonts = (fonts: string[]) => {
  return fonts
    .map((font) => {
      const fontCode = getFontName(font);
      const fontFamily = fontFamilyMapping[fontCode] || `'${font}'`;
      return `
    .ql-snow .ql-picker.ql-font .ql-picker-label[data-value='${fontCode}']::before,
    .ql-snow .ql-picker.ql-font .ql-picker-item[data-value='${fontCode}']::before
    {
      content: '${font}';
      font-family: ${fontFamily};
    }
    .ql-font-${fontCode} {
      font-family: ${fontFamily};
    }
  `;
    })
    .join('\n');
};

const fontStyles = `${getCssForFonts(supportedFonts)}
/* default normal size */
.ql-container {
  font-size: 16px !important;
}
.ql-snow .ql-picker.ql-font .ql-picker-label:not([data-value])::before {
  content: 'Open Sans';
  font-family: 'Open Sans';
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="__size-divider__"],
.ql-snow .ql-picker.ql-font .ql-picker-item[data-value="__font-divider__"],
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="${STYLE_DIVIDER_VALUE}"] {
  display: block;
  width: 100%;
  height: 1px;
  padding-top: 1px;
  padding-bottom: 1px;
  background-color: #d0d7de;
  pointer-events: none;
  cursor: default;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="__size-divider__"]::before,
.ql-snow .ql-picker.ql-font .ql-picker-item[data-value="__font-divider__"]::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="${STYLE_DIVIDER_VALUE}"]::before {
  content: '';
}
.ql-snow .ql-picker.ql-textStyle {
  width: 116px;
}
.ql-snow .ql-picker.ql-textStyle .ql-picker-item::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label[data-value="normal"]::before {
  content: 'Normal';
}
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="h1"]::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label[data-value="h1"]::before {
  content: 'Heading 1';
}
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="h2"]::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label[data-value="h2"]::before {
  content: 'Heading 2';
}
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="h3"]::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label[data-value="h3"]::before {
  content: 'Heading 3';
}
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="h4"]::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label[data-value="h4"]::before {
  content: 'Heading 4';
}
.ql-snow .ql-picker.ql-textStyle .ql-picker-item[data-value="caption"]::before,
.ql-snow .ql-picker.ql-textStyle .ql-picker-label[data-value="caption"]::before {
  content: 'Caption';
}
.ql-snow .ql-editor p,
.ql-snow .ql-editor h1,
.ql-snow .ql-editor h2,
.ql-snow .ql-editor h3,
.ql-snow .ql-editor h4,
.ql-snow .ql-editor p.caption,
.ql-snow .ql-editor p.ql-text-style-caption {
  margin-bottom: 1rem;
}
.ql-snow .ql-editor h1,
.ql-snow .ql-editor h2,
.ql-snow .ql-editor h3,
.ql-snow .ql-editor h4 {
  margin-top: 2rem;
  font-family: "Montserrat", "Helvetica Neue", Arial, sans-serif;
  font-weight: 700;
}
.ql-snow .ql-editor > :first-child {
  margin-top: 0;
}
.ql-snow .ql-editor p {
  font-family: "Open Sans", "Helvetica Neue", Arial, sans-serif;
  font-size: 1rem;
  line-height: 1.25rem;
}
.ql-snow .ql-editor h1 {
  font-size: 2rem;
  line-height: 2.25rem;
}
.ql-snow .ql-editor h2 {
  font-size: 1.75rem;
  line-height: 1.875rem;
}
.ql-snow .ql-editor h3 {
  font-size: 1.5rem;
  line-height: 1.75rem;
}
.ql-snow .ql-editor h4 {
  font-size: 1.25rem;
  line-height: 1.625rem;
}
.ql-snow .ql-editor p.caption,
.ql-snow .ql-editor p.ql-text-style-caption {
  font-size: 0.875rem;
  line-height: 1rem;
}
.ql-snow .ql-editor hr {
  margin-top: 2rem;
  margin-bottom: 1rem;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="14px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="14px"]::before {
  content: '14px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="16px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="16px"]::before {
  content: '16px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="18px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="18px"]::before {
  content: '18px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="20px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="20px"]::before {
  content: '20px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="24px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="24px"]::before {
  content: '24px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="28px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="28px"]::before {
  content: '28px';
  font-size: 14px !important;
}
.ql-snow .ql-picker.ql-size .ql-picker-item[data-value="32px"]::before,
.ql-snow .ql-picker.ql-size .ql-picker-label[data-value="32px"]::before {
  content: '32px';
  font-size: 14px !important;
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
  projectSlug = '',
}) => {
  const resolveProjectSlug = () => {
    if (projectSlug) return projectSlug;

    const path = window?.location?.pathname || '';
    const pathnamePatterns = [/\/authoring\/project\/([^/]+)/, /\/project\/([^/]+)/];

    for (const pattern of pathnamePatterns) {
      const match = path.match(pattern);
      if (match?.[1]) return decodeURIComponent(match[1]);
    }

    const bodyProjectSlug = document.body?.getAttribute('data-project-slug');
    if (bodyProjectSlug) return bodyProjectSlug;

    const projectSlugMeta = document.querySelector('meta[name="project-slug"]');
    if (projectSlugMeta?.getAttribute('content')) {
      return projectSlugMeta.getAttribute('content') as string;
    }

    return '';
  };

  const inferredProjectSlug = useMemo(() => {
    return resolveProjectSlug();
  }, [projectSlug]);

  const quill: any = useRef();
  const [contents, setContents] = React.useState<any>(tree);
  const [selectedKey, setSelectedKey] = useState<number>(0);
  const [fibElements, setFibElements] = React.useState<any>([]);
  // Convert Janus tree to Quill delta without adding default font size
  // The editor will display 16px via CSS (.ql-container) but won't add inline styles
  const initialDelta = useMemo(() => {
    return convertJanusToQuill(tree);
  }, [tree]);
  const [delta, setDelta] = React.useState<any>(initialDelta);
  const [currentQuillRange, setCurrentQuillRange] = React.useState<number>(0);
  const [showImageSelectorDailog, setShowImageSelectorDailog] = React.useState<boolean>(false);
  const [showFIBOptionEditorDailog, setShowFIBOptionEditorDailog] = React.useState<boolean>(false);
  const [showLinkDialog, setShowLinkDialog] = React.useState<boolean>(false);
  const [linkRange, setLinkRange] = React.useState<{ index: number; length: number } | null>(null);
  const [linkType, setLinkType] = React.useState<'page' | 'url'>('url');
  const [linkHref, setLinkHref] = React.useState<string>('');
  const [pagesState, setPagesState] = React.useState<
    { type: 'idle' | 'loading' | 'error' } | Persistence.PagesReceived
  >({ type: 'idle' });
  const [selectedPageHref, setSelectedPageHref] = React.useState<string>('');

  const sortedPages =
    pagesState.type === 'success'
      ? [...pagesState.pages].sort((a, b) => (a.numbering_index ?? 0) - (b.numbering_index ?? 0))
      : [];

  const internalPageHref = (slug: string) => `/course/link/${slug}`;

  useEffect(() => {
    if (!showLinkDialog || linkType !== 'page') return;

    if (!inferredProjectSlug) {
      setPagesState({ type: 'error' });
      return;
    }

    setPagesState({ type: 'loading' });
    Persistence.pages(inferredProjectSlug)
      .then((result) => {
        if (result.type === 'success') {
          setPagesState(result);
        } else {
          setPagesState({ type: 'error' });
        }
      })
      .catch(() => setPagesState({ type: 'error' }));
  }, [showLinkDialog, linkType, inferredProjectSlug]);

  useEffect(() => {
    if (linkType !== 'page' || pagesState.type !== 'success') return;

    if (linkHref.startsWith('/course/link/')) {
      const selected = sortedPages.find((p) => internalPageHref(p.slug) === linkHref);
      if (selected) {
        setSelectedPageHref(internalPageHref(selected.slug));
        return;
      }
    }

    if (sortedPages.length > 0) {
      setSelectedPageHref(internalPageHref(sortedPages[0].slug));
    } else {
      setSelectedPageHref('');
    }
  }, [linkType, pagesState, linkHref]);

  const applyLink = (href: string) => {
    if (!quill?.current || !linkRange) return;

    const editor = quill.current.getEditor();
    editor.setSelection(linkRange.index, linkRange.length);
    editor.format('link', href);
    setShowLinkDialog(false);
  };

  const removeLink = () => {
    if (!quill?.current || !linkRange) return;

    const editor = quill.current.getEditor();
    editor.setSelection(linkRange.index, linkRange.length);
    editor.format('link', false);
    setShowLinkDialog(false);
  };

  const openLinkDialog = React.useCallback(
    (providedRange?: { index: number; length: number }, providedHref?: string) => {
      if (!quill?.current) return;

      const editor = quill.current.getEditor();
      const range = providedRange || editor.getSelection();
      if (!range) return;

      const format = editor.getFormat(range.index, range.length || 1);
      const currentHref = providedHref || (typeof format.link === 'string' ? format.link : '');

      let normalizedRange = range;
      if (range.length === 0 && currentHref) {
        let start = range.index;
        let stop = range.index;
        const maxIndex = editor.getLength();

        while (start > 0 && editor.getFormat(start - 1, 1).link === currentHref) {
          start -= 1;
        }

        while (stop < maxIndex && editor.getFormat(stop, 1).link === currentHref) {
          stop += 1;
        }

        normalizedRange = { index: start, length: Math.max(1, stop - start) };
      }

      setLinkRange({ index: normalizedRange.index, length: normalizedRange.length });
      setLinkHref(currentHref);
      setLinkType(currentHref.startsWith('/course/link/') ? 'page' : 'url');
      setShowLinkDialog(true);
      editor.theme?.tooltip?.hide?.();
    },
    [quill],
  );

  useEffect(() => {
    if (!quill?.current) return;

    const editor = quill.current.getEditor();
    const root = editor.root;

    const getAnchorFromEventTarget = (target: EventTarget | null): HTMLAnchorElement | null => {
      if (!target) return null;

      if (target instanceof HTMLAnchorElement) return target;

      if (target instanceof Element) {
        return target.closest('a');
      }

      if (target instanceof Node && target.parentElement) {
        return target.parentElement.closest('a');
      }

      return null;
    };

    const onEditorMouseDown = (event: MouseEvent) => {
      const anchor = getAnchorFromEventTarget(event.target);
      if (!anchor) return;

      event.preventDefault();
    };

    const onEditorClick = (event: MouseEvent) => {
      const anchor = getAnchorFromEventTarget(event.target);
      if (!anchor) return;

      const blot = Quill.find(anchor);
      if (!blot) return;

      event.preventDefault();
      event.stopPropagation();

      const index = editor.getIndex(blot);
      const length = Math.max(1, blot.length?.() || 1);

      editor.setSelection(index, length);
      openLinkDialog({ index, length }, anchor.getAttribute('href') || '');
    };

    root.addEventListener('mousedown', onEditorMouseDown, true);
    root.addEventListener('click', onEditorClick, true);
    return () => {
      root.removeEventListener('mousedown', onEditorMouseDown, true);
      root.removeEventListener('click', onEditorClick, true);
    };
  }, [openLinkDialog]);
  const customHandlers = {
    textStyle: function (value: string) {
      applyTextStyle(this.quill, value);
    },
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
        const janusText = convertQuillToJanus(
          new Delta(quill.current?.getEditor()?.getContents().ops),
        );
        const collectedText = extractFormattedHTMLFromQuillNodes(janusText);
        const parsed = generateFIBStructure(collectedText);
        const quillOptions = transformOptionsToNormalized(parsed.elements);
        const updatedFIBOptions = mergeParsedWithExistingBlanks(localOptions, quillOptions);
        setFibElements(updatedFIBOptions);
        setSelectedKey(iMatchCounter);
        setShowFIBOptionEditorDailog(true);
      }
    },
    link: function () {
      openLinkDialog();
    },
  };
  const handleImageDetailsSave = (imageURL: string, imageAltText: string) => {
    setShowImageSelectorDailog(false);

    if (!quill?.current || !imageURL) return;

    const editor = quill.current.getEditor();
    const index = currentQuillRange ?? editor.getLength();

    editor.insertEmbed(index, 'image', { src: imageURL, alt: imageAltText }, 'user');
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

        [{ textStyle: ['normal', STYLE_DIVIDER_VALUE, 'h1', 'h2', 'h3', 'h4', 'caption'] }],
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
        [
          {
            font: [
              getFontName('Open Sans'),
              '__font-divider__',
              getFontName('Aleo'),
              getFontName('Courier Prime'),
              getFontName('Brawler'),
              getFontName('Montserrat'),
              getFontName('Open Sans'),
              getFontName('Patrick Hand'),
            ],
          },
          {
            size: [
              '16px',
              '__size-divider__',
              '14px',
              '16px',
              '18px',
              '20px',
              '24px',
              '28px',
              '32px',
            ],
          },
        ],
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
      {showfibinsertoptioncontrol && (
        <Alert variant="info" style={{ fontSize: '14px' }}>
          To edit a blank: Place your cursor in the blank and select 🔽. <br></br> To create a new
          blank: Place your cursor where you want it and select 🔽.
        </Alert>
      )}
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
          formats={[
            'size',
            'font',
            'bold',
            'italic',
            'underline',
            'strike',
            'script',
            'blockquote',
            'list',
            'indent',
            'header',
            'textStyle',
            'color',
            'background',
            'align',
            'link',
            'image',
            'adaptivity',
            'insertFIBOption',
          ]}
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
      <Modal show={showLinkDialog} onHide={() => setShowLinkDialog(false)} centered>
        <Modal.Header closeButton>
          <Modal.Title>Insert Link</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="form-check mb-2">
            <input
              id="link-page-option"
              className="form-check-input"
              type="radio"
              name="adaptive-link-type"
              value="page"
              checked={linkType === 'page'}
              onChange={() => setLinkType('page')}
            />
            <label className="form-check-label" htmlFor="link-page-option">
              Link to page in course
            </label>
          </div>
          <div className="form-check mb-3">
            <input
              id="link-url-option"
              className="form-check-input"
              type="radio"
              name="adaptive-link-type"
              value="url"
              checked={linkType === 'url'}
              onChange={() => setLinkType('url')}
            />
            <label className="form-check-label" htmlFor="link-url-option">
              Link to external URL
            </label>
          </div>
          {linkType === 'page' && (
            <>
              <select
                aria-label="Link target page"
                className="form-control"
                value={selectedPageHref}
                onChange={(e) => setSelectedPageHref(e.target.value)}
                disabled={pagesState.type !== 'success' || sortedPages.length === 0}
              >
                {pagesState.type === 'idle' && <option value="">Select a page</option>}
                {pagesState.type === 'loading' && <option value="">Loading pages...</option>}
                {pagesState.type === 'error' && (
                  <option value="">Unable to load pages for this project</option>
                )}
                {pagesState.type === 'success' && sortedPages.length === 0 && (
                  <option value="">No pages available in this course</option>
                )}
                {pagesState.type === 'success' &&
                  sortedPages.map((page) => (
                    <option key={page.id} value={internalPageHref(page.slug)}>
                      {page.title}
                    </option>
                  ))}
              </select>
              {pagesState.type === 'error' && (
                <div className="mt-2 text-muted">Check project context and try again.</div>
              )}
            </>
          )}
          {linkType === 'url' && (
            <input
              aria-label="External link URL"
              className="form-control"
              type="text"
              value={linkHref}
              placeholder="https://example.org"
              onChange={(e) => setLinkHref(e.target.value)}
            />
          )}
        </Modal.Body>
        <Modal.Footer>
          <button className="btn btn-outline-danger" onClick={removeLink}>
            Remove Link
          </button>
          <button className="btn btn-secondary" onClick={() => setShowLinkDialog(false)}>
            Cancel
          </button>
          <button
            className="btn btn-primary"
            disabled={
              linkRange?.length === 0 ||
              (linkType === 'page' && !selectedPageHref) ||
              (linkType === 'url' && !linkHref.trim())
            }
            onClick={() =>
              applyLink(linkType === 'page' ? selectedPageHref : normalizeHref(linkHref))
            }
          >
            Save
          </button>
        </Modal.Footer>
      </Modal>
    </React.Fragment>
  );
};

export const tagName = 'tf-quill-editor';

export const registerEditor = () => {
  if (!customElements.get(tagName)) {
    register(
      QuillEditor,
      tagName,
      ['tree', 'html', 'showimagecontrol', 'showCustomOptionControl', 'project-slug'],
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
