export const convertQuillNodesToText = (nodes: any[]): string => {
  let textContent = '';

  const traverseNodes = (nodeArray: any[]) => {
    nodeArray.forEach((node) => {
      if (node.tag === 'text' && node.text) {
        textContent += node.text + ' ';
      }
      if (Array.isArray(node.children)) {
        traverseNodes(node.children);
      }
    });
  };

  traverseNodes(nodes);
  return textContent.trim();
};

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
        finalText += ` {${matchingInput.options
          .map((opt: any) => {
            return `"${opt.value}"*`;
          })
          .join(', ')}}`;
      }
    }
  });

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
};

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
export const parseTextToFIBStructure = (
  inputText: string,
): ParsedFIBResult & { blanksInsideBraces: string[][] } => {
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
    const placeholderContent = match[1].replace(/\\"/g, '"'); // Unescape escaped quotes;

    // Plain text before current match
    if (matchStart > lastProcessedIndex) {
      const plainText = inputText.slice(lastProcessedIndex, matchStart);
      if (plainText) contentItems.push({ insert: plainText });
    }

    const parts = placeholderContent
      .split(/\s*,\s*/)
      .map((s) => s.trim().replace(/^"(.*)"$/, '$1')); // ✅ Strip quotes

    blanksInsideBraces.push([...parts]);

    if (parts.length === 1) {
      let value = parts[0];
      const isCorrect = value.endsWith('*');
      if (isCorrect) value = value.slice(0, -1);

      contentItems.push({ 'text-input': value });

      elements.push({
        correct: value,
        key: value,
        type: 'input',
        alternateCorrect: [],
        options: [{ key: value, value: value }],
      });
    } else {
      const options: { key: string; value: string }[] = [];
      let correctKey = '';

      parts.forEach((option) => {
        const isCorrect = option.endsWith('*');
        let cleaned = isCorrect ? option.slice(0, -1) : option;
        cleaned = cleaned.replace(/^"(.*)"$/, '$1');
        options.push({ key: cleaned, value: cleaned });
        if (isCorrect) correctKey = cleaned;
      });

      if (!correctKey && options.length > 0) {
        correctKey = options[0].key;
      }

      const dropdownKey = `blank${blankCounter++}`;
      contentItems.push({ dropdown: dropdownKey, insert: '' });

      elements.push({
        correct: correctKey,
        alternateCorrect: [],
        key: dropdownKey,
        options,
        type: 'dropdown',
      });
    }

    lastProcessedIndex = matchEnd;
  }

  // Append any remaining text after last placeholder
  if (lastProcessedIndex < inputText.length) {
    const remaining = inputText.slice(lastProcessedIndex);
    if (remaining) contentItems.push({ insert: remaining });
  }

  return {
    content: contentItems,
    elements, // now correctly ordered
    blanksInsideBraces,
  };
};

type FIBElement = DropdownBlank | TextInputBlank;

interface NormalizedBlank {
  key: string;
  options: any[];
  type: 'dropdown' | 'input';
  correct: string;
  alternateCorrect: [];
}

export const normalizeBlanks = (elements: FIBElement[]): NormalizedBlank[] => {
  return elements.map((el, idx) => {
    let isKeyExists = false;
    let isDropDownItem = false;
    if ('type' in el) {
      isKeyExists = true;
      isDropDownItem = el.type == 'dropdown';
    }
    if (!isKeyExists && 'options' in el) {
      isDropDownItem = true;
    }
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
      return {
        key: `blank${idx + 1}`,
        options: el.options.map((opt) => {
          return {
            key: opt.value,
            value: opt.value,
          };
        }),
        type: 'input',
        correct: el.correct,
        alternateCorrect: el.alternateCorrect || [],
      };
    }
  });
};

interface OptionItem {
  key: string;
  options: string[];
  type: 'dropdown' | 'input';
  correct: string;
  alternateCorrect: any[];
}

export const updateStringWithCorrectAnswers = (input: string, options: OptionItem[]) => {
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

export const updateFinalOptionsText = (text: string, options: any[]) => {
  const newOptionsList: any = parseTextToFIBStructure(text);
  console.log({ newOptionsList, options });
  return newOptionsList.elements.map((newOpt: any, idx: any) => {
    const existing = options[idx];
    console.log({ existing });
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
        type: 'dropdown', // or default to whatever you prefer
      };
    }
  });
};

export const parseTextContentToFIBStructure = (inputText: string, options?: any[]) => {
  const contentItems: FIBContentItem[] = [];

  const placeholderRegex = /{([^{}]+)}/g;
  let lastProcessedIndex = 0;
  let match: RegExpExecArray | null;
  let blankCounter = 1;

  while ((match = placeholderRegex.exec(inputText)) !== null) {
    const matchStart = match.index;
    const matchEnd = placeholderRegex.lastIndex;
    // Plain text before current match
    if (matchStart > lastProcessedIndex) {
      const plainText = inputText.slice(lastProcessedIndex, matchStart);
      if (plainText) contentItems.push({ insert: plainText });
    }
    const currentOption = options?.[blankCounter - 1];
    const isInput = currentOption?.type === 'input';
    const key = `blank${blankCounter++}`;
    if (isInput) {
      contentItems.push({ 'text-input': key });
    } else {
      contentItems.push({ dropdown: key, insert: '' });
    }
    lastProcessedIndex = matchEnd;
  }

  // Append any remaining text after last placeholder
  if (lastProcessedIndex < inputText.length) {
    const remaining = inputText.slice(lastProcessedIndex);
    if (remaining) contentItems.push({ insert: remaining });
  }

  return {
    content: contentItems,
  };
};

export function syncOptionsWithParsed(
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
