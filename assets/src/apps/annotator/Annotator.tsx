import React, { useCallback, useMemo } from 'react';
import { useToggle } from '../../components/hooks/useToggle';
import useWindowSize from '../../components/hooks/useWindowSize';
import { useDocumentMouseEvents } from './useDocumentMouseEvents';

interface TextAnnotation {
  id: string;
  startOffset: number;
  endOffset: number;
}

const getHeadingBlockHighlight = () => {
  const heading = document.querySelector('#E236710925');
  const rects = heading?.getClientRects();
  // console.info(rects);
  if (rects?.length) {
    return rects![0];
  }
  return null;
};

const getHeadingParagraphTextHighlight = () => {
  return getAnnotation('E236710926', 10, 19);
};

const getAnnotation = (id: string, startOffset: number, endOffset: number) => {
  const element = document.querySelector('#' + id);
  if (!element) return [];
  if (!element.firstChild) return [];

  try {
    const range = document.createRange();
    range.setStart(element.firstChild, startOffset);
    range.setEnd(element.firstChild, endOffset);

    const rects = range?.getClientRects();
    if (rects?.length) {
      return Array.from(rects);
    }
  } catch (e) {
    console.info(e);
  }

  return [];
};

const getHeadingParagraphTextHighlight2 = () => {
  return getAnnotation('E236710926', 99, 150);
};

const getIdFromTextNode = (node: Node | null): string | null => {
  if (!node) return null;
  if (node.nodeType === Node.TEXT_NODE) {
    return getIdFromTextNode(node.parentElement);
  }
  if (node.nodeType === Node.ELEMENT_NODE) {
    const id = (node as Element).attributes.getNamedItem('id')?.value;
    if (id) return id;
    return getIdFromTextNode(node.parentElement);
  }
  return null;
};

const getActiveTextHighlight = (activeHighlight: TextAnnotation | null) => {
  if (!activeHighlight) return [];

  return getAnnotation(activeHighlight.id, activeHighlight.startOffset, activeHighlight.endOffset);
};

const hasBlockAnnotationAttribute = (element: Element) => {
  return element.attributes.getNamedItem('data-annotate')?.value === 'block';
};

const hasID = (element: Element) => {
  return !!element.attributes.getNamedItem('id');
};

const blockAnnotatable = (element: Element) => {
  return (
    element.nodeType === Node.ELEMENT_NODE && hasBlockAnnotationAttribute(element) && hasID(element)
  );
};

const getHighlightCoords = (highlights: TextAnnotation[]) =>
  highlights.map(getActiveTextHighlight).flat(1);

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

export const Annotator = () => {
  const windowSize = useWindowSize();
  const [editMode, toggleMode] = useToggle(true);
  const [mouseDown, toggleMouse] = useToggle();
  const [activeHighlight, setActiveHighlight] = React.useState<TextAnnotation | null>(null);
  const [highlights, setHighlights] = React.useState<TextAnnotation[]>([]);

  const appendHighlight = useCallback((highlight: TextAnnotation) => {
    setHighlights((highlights) => [...highlights, highlight]);
  }, []);

  const highlightCoords = useMemo(() => {
    return [...getHighlightCoords(highlights), ...getActiveTextHighlight(activeHighlight)];
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [windowSize, activeHighlight]);

  const onMouseDown = useCallback((event: MouseEvent) => {
    toggleMouse();
  }, []);

  const onMouseUp = useCallback(
    (event: MouseEvent) => {
      toggleMouse();
      activeHighlight && appendHighlight(activeHighlight);
      setActiveHighlight(null);
    },
    [activeHighlight, appendHighlight, toggleMouse],
  );

  const onMouseMove = useCallback(
    (event: MouseEvent) => {
      event.stopPropagation();
      event.preventDefault();

      const { pageX, pageY, clientX, clientY } = event;

      if (mouseDown) {
        const blockHighlightable = document
          .elementsFromPoint(clientX, clientY)
          .filter(blockAnnotatable);
        // .forEach((element) => {
        //   console.info('Bock highlight:', element);
        // });

        if (blockHighlightable.length === 0) {
          let range;
          let textNode;
          let offset;
          if (document.caretPositionFromPoint) {
            range = document.caretPositionFromPoint(clientX, clientY);
            textNode = range.offsetNode;
            offset = range.offset;
          } else if (document.caretRangeFromPoint) {
            // Use WebKit-proprietary fallback method
            range = document.caretRangeFromPoint(clientX, clientY);
            if (range) {
              textNode = range.startContainer;
              offset = range.startOffset;
            }
          } else {
            // Neither method is supported, do nothing
            return;
          }
          const id = getIdFromTextNode(textNode);
          if (activeHighlight && activeHighlight.id === id) {
            setActiveHighlight({
              ...activeHighlight,
              endOffset: offset,
            });
          } else {
            if (id) {
              setActiveHighlight({
                id,
                startOffset: offset,
                endOffset: offset,
              });
            }
          }
          console.info(editMode, mouseDown, {
            clientX,
            clientY,
            activeHighlight,
            textNode,
            offset,
          });
        }
      }
    },
    [activeHighlight, editMode, mouseDown],
  );

  useDocumentMouseEvents(editMode, onMouseDown, onMouseUp, onMouseMove);

  return (
    <>
      <div className="annotation-controls">
        <button onClick={toggleMode}>Highlighter ({editMode ? 'On' : 'Off'})</button>
      </div>
      <svg width="100%" height="100%">
        {highlightCoords.map(
          (highlight, index) =>
            highlight && (
              <rect
                key={index}
                x={highlight.x}
                y={highlight.y}
                width={highlight.width}
                height={highlight.height}
                rx="5"
                fill="yellow"
                fillOpacity="0.4"
              />
            ),
        )}
      </svg>
    </>
  );
};

declare global {
  interface Document {
    caretPositionFromPoint: any;
  }
}
