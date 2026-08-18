import React, {
  CSSProperties,
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import './Matching.scss';
import MatchingItemContent from './MatchingItemContent';
import MatchingLines from './MatchingLines';
import {
  DrawnLine,
  areDrawnLinesEqual,
  buildDrawnLines,
  columnTitle,
  matchingLayoutClass,
  matchingMinHeight,
  matchingThemeStyles,
  normalizeMatchingItemsForSave,
} from './matching-util';
import { DEFAULT_MATCHING_THEME, MatchingModel } from './schema';

const MatchingAuthor: React.FC<AuthorPartComponentProps<MatchingModel>> = (props) => {
  const { id, model } = props;
  const stageRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const [lines, setLines] = useState<DrawnLine[]>([]);

  useEffect(() => {
    props.onReady({ id: `${id}` });
  }, []);

  const column1Items = normalizeMatchingItemsForSave(model.column1Items || []);
  const column2Items = normalizeMatchingItemsForSave(model.column2Items || []);
  const showTitles = model.showColumnTitles !== false;
  const themeColor = model.themeColor || DEFAULT_MATCHING_THEME;
  const height = matchingMinHeight(model.width, model.height);

  const redrawLines = useCallback(() => {
    if (!stageRef.current) {
      setLines((prev) => (prev.length === 0 ? prev : []));
      return;
    }
    const stageRect = stageRef.current.getBoundingClientRect();
    const next = buildDrawnLines(model.correctMatches || {}, (itemId, side) => {
      const el = itemRefs.current[itemId];
      if (!el) {
        return null;
      }
      const rect = el.getBoundingClientRect();
      return {
        x: side === 'left' ? rect.right - stageRect.left : rect.left - stageRect.left,
        y: (rect.top + rect.bottom) / 2 - stageRect.top,
      };
    });
    setLines((prev) => (areDrawnLinesEqual(prev, next) ? prev : next));
  }, [model.correctMatches]);

  useLayoutEffect(() => {
    redrawLines();
  }, [
    redrawLines,
    model.column1Items,
    model.column2Items,
    model.correctMatches,
    showTitles,
    height,
  ]);

  useEffect(() => {
    window.addEventListener('resize', redrawLines);
    return () => window.removeEventListener('resize', redrawLines);
  }, [redrawLines]);

  const styles: CSSProperties = {
    width: model.width ?? '100%',
    height,
    minHeight: height,
    ...matchingThemeStyles(themeColor),
    ['--matching-min-height' as string]: `${height}px`,
  };

  return (
    <div
      data-janus-type={tagName}
      className={`matching matching-author ${matchingLayoutClass(model.width)}`}
      style={styles}
    >
      <div className="matching-stage" ref={stageRef}>
        <MatchingLines lines={lines} themeColor={themeColor} />
        <div className="matching-columns">
          <section className="matching-column">
            {showTitles && (
              <header className="matching-column-header">
                <span>{columnTitle(model.column1Title, 'Column 1')}</span>
              </header>
            )}
            <div className="matching-items">
              {column1Items.length === 0 && (
                <div className="matching-empty-hint">
                  Use Manage Matching in the property panel to add items
                </div>
              )}
              {column1Items.map((item) => (
                <div
                  key={item.id}
                  className="matching-item"
                  ref={(el) => {
                    itemRefs.current[item.id] = el;
                  }}
                >
                  <div className="matching-item-body">
                    <MatchingItemContent item={item} />
                  </div>
                </div>
              ))}
            </div>
          </section>

          <section className="matching-column">
            {showTitles && (
              <header className="matching-column-header">
                <span>{columnTitle(model.column2Title, 'Column 2')}</span>
              </header>
            )}
            <div className="matching-items">
              {column2Items.map((item) => (
                <div
                  key={item.id}
                  className="matching-item"
                  ref={(el) => {
                    itemRefs.current[item.id] = el;
                  }}
                >
                  <div className="matching-item-body">
                    <MatchingItemContent item={item} />
                  </div>
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-matching';

export default MatchingAuthor;
