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
              opt.key === matchingDropdown.correct || opt.key === matchingDropdown.alternateCorrect;
            return `"${opt.value}"${isCorrect ? '*' : ''}`;
          })
          .join(', ')}}`;
      }
    } else if (item['text-input']) {
      const matchingInput = blanks.find((b) => b.key === item['text-input']);

      if (matchingInput) {
        finalText += `{"${matchingInput.key}"}`;
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

type TextInputBlank = { correct: string; key: string };
type DropdownBlank = {
  correct: string;
  alternateCorrect: string;
  key: string;
  options: { key: string; value: string }[];
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
    const placeholderContent = match[1];

    // Plain text before current match
    if (matchStart > lastProcessedIndex) {
      const plainText = inputText.slice(lastProcessedIndex, matchStart);
      if (plainText) contentItems.push({ insert: plainText });
    }

    const parts = placeholderContent
      .split(/\s*,\s*/)
      .map((s) => s.trim().replace(/^"(.*)"$/, '$1'));

    blanksInsideBraces.push([...parts]);

    if (parts.length === 1) {
      let value = parts[0];
      const isCorrect = value.endsWith('*');
      if (isCorrect) value = value.slice(0, -1);

      contentItems.push({ 'text-input': value });

      elements.push({
        correct: value,
        key: value,
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
        alternateCorrect: '',
        key: dropdownKey,
        options,
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
  options: string[];
  type: 'dropdown' | 'input';
  correct: string;
}

export const normalizeBlanks = (elements: FIBElement[]): NormalizedBlank[] => {
  return elements.map((el, idx) => {
    if ('options' in el) {
      return {
        key: `blank ${idx + 1}`,
        options: el.options.map((opt) => opt.value),
        type: 'dropdown',
        correct: el.correct,
      };
    } else {
      return {
        key: `blank ${idx + 1}`,
        options: [el.correct],
        type: 'input',
        correct: 'true',
      };
    }
  });
};

interface OptionItem {
  key: string;
  options: string[];
  type: 'dropdown' | 'input';
  correct: string;
}
export const updateStringWithCorrectAnswers = (input: string, options: OptionItem[]) => {
  let matchIndex = 0;
  return input.replace(/\{[^}]*\}/g, (match) => {
    const option = options[matchIndex++];
    if (!option) return match; // fallback if no matching option
    const updatedOptions = option.options.map((opt) =>
      opt === option.correct ? `"${opt}"*` : `"${opt}"`,
    );
    return `{${updatedOptions.join(', ')}}`;
  });
};
