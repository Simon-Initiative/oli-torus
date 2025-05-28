interface OptionItem {
  key: string;
  options: string[];
  type: 'dropdown' | 'input';
  correct: string;
  alternateCorrect: any[];
}
type FIBContentItem =
  | { insert: string }
  | { 'text-input': string }
  | { dropdown: string; insert: '' };

type TextInputBlank = {
  alternateCorrect: [];
  options: any[];
  correct: string;
  key: string;
  type: 'input';
};
type DropdownBlank = {
  correct: string;
  alternateCorrect: [];
  key: string;
  options: any[];
  type: 'dropdown';
};

interface ParsedFIBResult {
  content: FIBContentItem[];
  elements: (TextInputBlank | DropdownBlank)[];
}

type FIBElement = DropdownBlank | TextInputBlank;

interface NormalizedBlank {
  key: string;
  options: any[];
  type: 'dropdown' | 'input';
  correct: string;
  alternateCorrect: [];
}

type ParseFIBMode = 'generate' | 'map';

/**
 * Converts an array of Quill-style nodes into a formatted HTML string.
 * Supports text nodes, superscript, subscript, and styled spans (bold, italic, underline).
 * Recursively processes children nodes to build the full HTML.
 */
export const extractFormattedHTMLFromQuillNodes = (nodes: any[]): string => {
  const processNodes = (nodeArray: any[]): string => {
    return nodeArray
      .map((node) => {
        if (node.tag === 'text' && node.text) {
          return node.text;
        }

        if (node.tag === 'sup' || node.tag === 'sub') {
          const inner = processNodes(node.children || []);
          return `<${node.tag}>${inner}</${node.tag}>`;
        }

        if (
          node.tag === 'span' &&
          (node.style?.fontWeight === 'bold' ||
            node.style?.fontStyle === 'italic' ||
            node.style?.textDecoration === 'underline')
        ) {
          const boldText = processNodes(node.children || []);
          let wrapped = boldText;
          if (node.style?.fontWeight === 'bold') {
            wrapped = `<b>${wrapped}</b>`;
          }
          if (node.style?.fontStyle === 'italic') {
            wrapped = `<i>${wrapped}</i>`;
          }
          if (node.style?.textDecoration === 'underline') {
            wrapped = `<u>${wrapped}</u>`;
          }
          return wrapped;
        }

        // Recurse for other tags (like <p> etc.)
        if (Array.isArray(node.children)) {
          return processNodes(node.children);
        }

        return '';
      })
      .join('');
  };

  return processNodes(nodes).trim();
};

/**
 * Converts a Fill-in-the-Blank (FIB) content representation with blanks and options
 * into Quill nodes suitable for rendering.
 * Inserts placeholder text or dropdown options in braces `{}`.
 */
export const convertFIBContentToQuillNodes = (contentItems: any[], blanks: any[]) => {
  let finalText = '';

  contentItems?.forEach((item) => {
    if (!blanks?.length) return;
    if (item.insert) {
      finalText += item.insert;
    } else if (item.dropdown) {
      const matchingDropdown = blanks.find((b) => b.key === item.dropdown);

      if (matchingDropdown) {
        finalText += ` {${matchingDropdown.options
          .map((opt: any) => {
            const isCorrect =
              opt.key === matchingDropdown.correct ||
              matchingDropdown.alternateCorrect?.includes(opt.key);
            return `"${opt.value}"${isCorrect ? '*' : ''}`;
          })
          .join(', ')}}`;
      }
    } else if (item['text-input']) {
      const matchingInput = blanks.find((b) => b.key === item['text-input']);

      if (matchingInput) {
        let updatedText = '';
        if (matchingInput.options) {
          updatedText = matchingInput.options
            .map((opt: any) => {
              return `"${opt.value}"*`;
            })
            .join(', ');
        } else {
          // this will be old formatted input type
          updatedText = `"${matchingInput.correct}"*`;
        }
        finalText += ` {${updatedText}}`;
      }
    }
  });
  try {
    const quillTextNodes = convertHTMLToQuillNodes(finalText);
    return quillTextNodes;
  } catch (ex) {
    return [
      {
        tag: 'p',
        style: {},
        children: [
          {
            tag: 'span',
            style: { fontSize: '1rem' },
            children: [
              {
                tag: 'text',
                style: {},
                text: finalText,
                children: [],
              },
            ],
          },
        ],
      },
    ];
  }
};

/**
 * Parses a raw HTML string into a tree of Quill-style nodes.
 * Maps supported tags (<b>, <i>, <u>, <sup>, <sub>) to node structures with styles.
 * Unwraps unknown tags and preserves children.
 *
 * @param htmlText - Raw HTML string to parse
 * @returns Array of Quill nodes representing the HTML content
 */
export const convertHTMLToQuillNodes = (htmlText: string) => {
  const parseNode = (node: Node): any | null => {
    if (node.nodeType === Node.TEXT_NODE) {
      const text = node.textContent;
      if (!text) return null;
      return {
        tag: 'span',
        children: [
          {
            tag: 'text',
            text,
            children: [],
          },
        ],
      };
    }

    if (node.nodeType === Node.ELEMENT_NODE) {
      const el = node as HTMLElement;
      const tag = el.tagName.toLowerCase();

      const children = Array.from(el.childNodes).map(parseNode).filter(Boolean);

      // Map supported tags to node structures
      switch (tag) {
        case 'sup':
        case 'sub':
          return { tag, children };

        case 'b':
        case 'strong':
          return {
            tag: 'span',
            style: { fontWeight: 'bold' },
            children,
          };

        case 'i':
        case 'em':
          return {
            tag: 'span',
            style: { fontStyle: 'italic' },
            children,
          };

        case 'u':
          return {
            tag: 'span',
            style: { textDecoration: 'underline' },
            children,
          };

        default:
          // Fallback: unwrap unknown tag and just return children
          return children;
      }
    }

    return null;
  };

  const parser = new DOMParser();
  const doc = parser.parseFromString(`<div>${htmlText}</div>`, 'text/html');
  const parsedChildren = Array.from(doc.body.firstChild?.childNodes || [])
    .map(parseNode)
    .flat()
    .filter(Boolean);
  return [
    {
      tag: 'p',
      style: { fontSize: '1rem' },
      children: parsedChildren,
    },
  ];
};

/**
 * Parses a text string containing fill-in-the-blank placeholders wrapped in braces `{}`.
 * Extracts content items and blank elements with options and correct answers.
 * Supports two modes:
 *  - 'generate': auto-generate blanks from text
 *  - 'map': map blanks from provided options list
 */
export const generateFIBStructure = (
  inputText: string,
  mode: ParseFIBMode = 'generate', // 'generate' = auto-generate from text, 'map' = map from provided options
  options?: (DropdownBlank | TextInputBlank)[],
): ParsedFIBResult & { blanksInsideBraces?: string[][] } => {
  const contentItems: FIBContentItem[] = [];
  const elements: (DropdownBlank | TextInputBlank)[] = [];
  const blanksInsideBraces: string[][] = [];

  const placeholderRegex = /{([^{}]+)}/g;
  let lastProcessedIndex = 0;
  let match: RegExpExecArray | null;
  let blankCounter = 1;

  while ((match = placeholderRegex.exec(inputText)) !== null) {
    const matchStart = match.index;
    const matchEnd = placeholderRegex.lastIndex;

    if (matchStart > lastProcessedIndex) {
      const plainText = inputText.slice(lastProcessedIndex, matchStart);
      if (plainText) contentItems.push({ insert: plainText });
    }

    if (mode === 'map' && options) {
      const currentOption = options[blankCounter - 1];
      const key = `blank${blankCounter++}`;
      if (currentOption?.type === 'input') {
        contentItems.push({ 'text-input': key });
      } else {
        contentItems.push({ dropdown: key, insert: '' });
      }
    } else {
      const placeholderContent = match[1].replace(/\\"/g, '"');
      const parts = placeholderContent
        .split(/\s*,\s*/)
        .map((s) => s.trim().replace(/^"(.*)"$/, '$1'));

      blanksInsideBraces.push([...parts]);

      if (parts.length === 1) {
        let value = parts[0];
        const isCorrect = value.endsWith('*');
        if (isCorrect) value = value.slice(0, -1);

        contentItems.push({ 'text-input': value });
        const cleaned = value.replace(/^"(.*)"$/, '$1');
        elements.push({
          correct: cleaned,
          key: cleaned,
          type: 'input',
          alternateCorrect: [],
          options: [{ key: cleaned, value: cleaned }],
        });
      } else {
        const optionsList: { key: string; value: string }[] = [];
        const alternateCorrectList: any = [];
        let correctKey = '';

        parts.forEach((option) => {
          const isCorrect = option.endsWith('*');
          let cleaned = isCorrect ? option.slice(0, -1) : option;
          cleaned = cleaned.replace(/^"(.*)"$/, '$1');
          optionsList.push({ key: cleaned, value: cleaned });
          if (isCorrect) {
            correctKey = cleaned;
            alternateCorrectList.push(cleaned);
          }
        });

        if (!correctKey && optionsList.length > 0) {
          correctKey = optionsList[0].key;
        }

        const dropdownKey = `blank${blankCounter++}`;
        contentItems.push({ dropdown: dropdownKey, insert: '' });

        elements.push({
          correct: correctKey,
          alternateCorrect: alternateCorrectList,
          key: dropdownKey,
          options: optionsList,
          type: 'dropdown',
        });
      }
    }

    lastProcessedIndex = matchEnd;
  }

  if (lastProcessedIndex < inputText.length) {
    const remaining = inputText.slice(lastProcessedIndex);
    if (remaining) contentItems.push({ insert: remaining });
  }

  return mode === 'generate'
    ? { content: contentItems, elements, blanksInsideBraces }
    : { content: contentItems, elements: [], blanksInsideBraces: [] };
};

/**
 * Normalizes an array of FIB elements into a standard format with keys, options,
 * types ('dropdown' or 'input'), and correct/alternate answers.
 * Assigns default keys like 'blank1', 'blank2', etc.
 */
export const transformOptionsToNormalized = (elements: FIBElement[]): NormalizedBlank[] => {
  return elements.map((el, idx) => {
    const isDropDownItem =
      ('type' in el && el.type === 'dropdown') || (!('type' in el) && 'options' in el);
    if (isDropDownItem) {
      return {
        key: `blank${idx + 1}`,
        options: el.options.map((opt) => {
          return { key: opt.value, value: opt.value };
        }),
        type: 'dropdown',
        correct: el.correct,
        alternateCorrect: el.alternateCorrect || [],
      };
    } else {
      // Normalize the options array safely
      const safeOptions = Array.isArray(el.options)
        ? el.options.map((opt) => ({
            key: opt.value,
            value: opt.value,
          }))
        : [
            {
              key: el.correct,
              value: el.correct,
            },
          ];
      return {
        key: `blank${idx + 1}`,
        options: safeOptions,
        type: 'input',
        correct: el.correct,
        alternateCorrect: el.alternateCorrect || [],
      };
    }
  });
};

/**
 * Embeds correct and alternate correct answers into a string with placeholders.
 * Replaces each placeholder `{...}` with formatted options where correct answers
 * are marked with an asterisk (*).
 * @param input - String containing placeholders in braces `{...}`
 * @param options - Array of option objects defining correct answers and types
 * @returns Updated string with correct answers annotated in placeholders
 */
export const embedCorrectAnswersInString = (input: string, options: OptionItem[]) => {
  let matchIndex = 0;
  return input.replace(/\{[^}]*\}/g, (match) => {
    const option = options[matchIndex++];
    if (!option) return match;

    const { correct, alternateCorrect, type, options: allOptions } = option;

    if (type === 'dropdown') {
      const updatedOptions = allOptions.map((opt: any) =>
        [correct, ...(alternateCorrect || [])].includes(opt?.value)
          ? `"${opt?.value}"*`
          : `"${opt?.value}"`,
      );
      return `{${updatedOptions.join(', ')}}`;
    }

    if (type === 'input') {
      const allCorrect = [correct, ...(alternateCorrect || [])].filter(Boolean);
      const formatted = allCorrect.map((opt: any) => `"${opt}"*`);
      return `{${formatted.join(', ')}}`;
    }

    return match; // fallback for unexpected types
  });
};

/**
 * Synchronizes a list of existing options with new options parsed from text.
 * Updates existing options' texts and correct values where matched by index,
 * adds new options if they do not exist.
 *
 * @param text - Text containing fill-in-the-blank placeholders
 * @param options - Existing list of option objects to update
 * @returns Updated array of option objects synced with parsed text
 */
export const syncOptionsFromText = (text: string, options: any[]) => {
  const newOptionsList: ParsedFIBResult = generateFIBStructure(text);
  return newOptionsList.elements.map((newOpt: any, idx: any) => {
    const existing = options[idx];
    if (existing) {
      // Update existing entry's text only
      return {
        ...existing,
        options: newOpt.options,
        correct: newOpt.correct,
        alternateCorrect:
          existing.type == 'input'
            ? newOpt.options.map((option: any) => option.value)
            : newOpt.alternateCorrect,
      };
    } else {
      // Add a new one
      return {
        key: `blank${idx + 1}`,
        options: newOpt.options,
        correct: newOpt.correct,
        alternateCorrect: newOpt.alternateCorrect,
        type: newOpt.options?.length <= 1 ? 'input' : 'dropdown',
      };
    }
  });
};

/**
 * Merges newly parsed blanks with existing normalized blanks.
 * Matches blanks by comparing option values arrays.
 * Preserves existing blanks where matched, adds new blanks otherwise.
 *
 * @param existingOptions - Array of existing normalized blanks
 * @param parsedElements - Array of newly parsed blanks to merge
 * @returns Merged array of normalized blanks
 */
export function mergeParsedWithExistingBlanks(
  existingOptions: NormalizedBlank[],
  parsedElements: NormalizedBlank[],
): NormalizedBlank[] {
  const updated: NormalizedBlank[] = [];
  const usedIndices = new Set<number>();

  for (const parsedItem of parsedElements) {
    let matchIndex = -1;

    // Try to find a matching option in existingOptions by options.value[]
    for (let i = 0; i < existingOptions.length; i++) {
      if (usedIndices.has(i)) continue;

      const existing = existingOptions[i];
      if (
        arraysEqual(
          existing.options.map((o) => o.value),
          parsedItem.options.map((o) => o.value),
        )
      ) {
        matchIndex = i;
        break;
      }
    }

    if (matchIndex >= 0) {
      // Found existing match — preserve type/correct values
      const matched = { ...existingOptions[matchIndex], key: parsedItem.key };
      updated.push(matched);
      usedIndices.add(matchIndex);
    } else {
      // New blank — use parsed one directly
      updated.push(parsedItem);
    }
  }

  return updated;
}

export const arraysEqual = (a: string[], b: string[]) => {
  if (a.length !== b.length) return false;
  return a.every((val, idx) => val === b[idx]);
};
