import React, { CSSProperties, KeyboardEvent, forwardRef, useCallback } from 'react';
import { MarkupTree, renderFlow } from 'components/parts/janus-text-flow/TextFlow';
import { htmlToPlainText, sanitizeRichLabelHtml } from 'utils/richOptionLabel';
import './Accordion.scss';
import {
  accordionContainerStyles,
  accordionLayoutClass,
  accordionThemeStyles,
  hasAccordionTheme,
  normalizeSections,
} from './accordion-util';
import { AccordionModel } from './schema';

export const tagName = 'janus-accordion';

export type AccordionViewProps = {
  id: string;
  model: AccordionModel;
  expandedSections: number[];
  enabled?: boolean;
  interactive?: boolean;
  onToggle?: (sectionIndex: number) => void;
  className?: string;
};

const AccordionChevron = ({ expanded }: { expanded: boolean }) => (
  <svg
    className={`accordion-chevron${expanded ? ' is-expanded' : ''}`}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 256 256"
    aria-hidden="true"
    focusable="false"
  >
    <polygon points="64,48 176,128 64,208" />
  </svg>
);

const AccordionView = forwardRef<HTMLDivElement, AccordionViewProps>(function AccordionView(
  { id, model, expandedSections, enabled = true, interactive = true, onToggle, className = '' },
  ref,
) {
  const sections = normalizeSections(model.sections);
  const customCss = model.customCss || '';
  const themeStyles = accordionThemeStyles(model.themeColor);
  const styles: CSSProperties = interactive
    ? {
        ...accordionContainerStyles(model.width, model.height),
        ...themeStyles,
      }
    : themeStyles;
  const themedClass = hasAccordionTheme(model.themeColor) ? 'janus-accordion--themed' : '';

  const handleHeaderKeyDown = useCallback(
    (event: KeyboardEvent<HTMLButtonElement>, currentIndex: number) => {
      const root = event.currentTarget.closest('.janus-accordion');
      const headers = Array.from(
        root?.querySelectorAll<HTMLButtonElement>('.accordion-header-button') ?? [],
      );
      if (headers.length === 0) return;

      const focusAt = (i: number) => headers[i]?.focus();

      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault();
          focusAt((currentIndex + 1) % headers.length);
          break;
        case 'ArrowUp':
          event.preventDefault();
          focusAt((currentIndex - 1 + headers.length) % headers.length);
          break;
        case 'Home':
          event.preventDefault();
          focusAt(0);
          break;
        case 'End':
          event.preventDefault();
          focusAt(headers.length - 1);
          break;
        default:
          break;
      }
    },
    [],
  );

  return (
    <div
      ref={ref}
      data-janus-type={tagName}
      className={`janus-accordion ${accordionLayoutClass(model.width)} ${themedClass} ${
        model.customCssClass || ''
      } ${className}`.trim()}
      style={styles}
    >
      {customCss ? <style>{customCss}</style> : null}
      {sections.length === 0 ? (
        <div className="accordion-empty-hint">Add sections in the property panel</div>
      ) : (
        <div className="accordion-list">
          {sections.map((section, index) => {
            const oneBased = index + 1;
            const expanded = expandedSections.includes(oneBased);
            const headerId = `${id}-accordion-header-${oneBased}`;
            const panelId = `${id}-accordion-panel-${oneBased}`;
            const contentNodes = (section.contentNodes || []) as MarkupTree[];
            const fallbackTitle = `Section ${oneBased}`;
            const titleHtml = sanitizeRichLabelHtml(section.title || fallbackTitle);
            const titlePlain = htmlToPlainText(section.title) || fallbackTitle;

            return (
              <div className={`accordion-item${expanded ? ' is-expanded' : ''}`} key={section.id}>
                <h3 className="accordion-heading">
                  {interactive ? (
                    <button
                      type="button"
                      id={headerId}
                      className="accordion-header-button"
                      aria-expanded={expanded}
                      aria-controls={panelId}
                      aria-label={titlePlain}
                      disabled={!enabled}
                      onClick={() => onToggle?.(oneBased)}
                      onKeyDown={(e) => handleHeaderKeyDown(e, index)}
                    >
                      <span
                        className="accordion-title"
                        dangerouslySetInnerHTML={{ __html: titleHtml || fallbackTitle }}
                      />
                      <AccordionChevron expanded={expanded} />
                    </button>
                  ) : (
                    <div
                      id={headerId}
                      className={`accordion-header-preview${expanded ? ' is-expanded' : ''}`}
                    >
                      <span
                        className="accordion-title"
                        dangerouslySetInnerHTML={{ __html: titleHtml || fallbackTitle }}
                      />
                      <AccordionChevron expanded={expanded} />
                    </div>
                  )}
                </h3>
                {interactive ? (
                  <div
                    className={`accordion-panel-wrap${expanded ? ' is-expanded' : ''}`}
                    aria-hidden={!expanded}
                  >
                    <div
                      id={panelId}
                      role="region"
                      aria-labelledby={headerId}
                      className="accordion-panel"
                    >
                      <div className="accordion-panel-inner">
                        {contentNodes.map((subtree, ni) =>
                          renderFlow(`${section.id}-${ni}`, subtree, {}, []),
                        )}
                      </div>
                    </div>
                  </div>
                ) : (
                  <div
                    id={panelId}
                    role="region"
                    aria-labelledby={headerId}
                    hidden={!expanded}
                    className={`accordion-panel${expanded ? ' is-expanded' : ''}`}
                  >
                    <div className="accordion-panel-inner">
                      {contentNodes.map((subtree, ni) =>
                        renderFlow(`${section.id}-${ni}`, subtree, {}, []),
                      )}
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
});

AccordionView.displayName = 'AccordionView';

export default React.memo(AccordionView);
