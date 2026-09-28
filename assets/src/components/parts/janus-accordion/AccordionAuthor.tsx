import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { parseBoolean } from 'utils/common';
import AccordionView, { tagName } from './AccordionView';
import { parseAccordionModel } from './accordion-util';
import { AccordionModel, DEFAULT_ACCORDION_HEIGHT } from './schema';

const AUTHOR_PREVIEW_EXPANDED: number[] = [];

type AccordionAuthorProps = AuthorPartComponentProps<AccordionModel> & {
  layoutchanging?: string | boolean | number;
};

const AccordionAuthor: React.FC<AccordionAuthorProps> = (props) => {
  const { id } = props;
  const model = useMemo(() => parseAccordionModel(props.model), [props.model]);
  const containerRef = useRef<HTMLDivElement>(null);
  const [contentHeight, setContentHeight] = useState(0);
  const authoredHeight = model.height ?? DEFAULT_ACCORDION_HEIGHT;
  const layoutChanging = parseBoolean(props.layoutchanging ?? false);

  useLayoutEffect(() => {
    const list = containerRef.current?.querySelector<HTMLElement>('.accordion-list');
    if (!list) return;

    // Added sections and wrapped titles must fit in the authoring selection frame.
    const measure = () => setContentHeight(list.offsetHeight + 2);
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(list);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    // Resize-stop commits the dragged height; enforce the content minimum afterward.
    if (!layoutChanging && contentHeight > authoredHeight) {
      props.onResize({ id, settings: { height: { value: contentHeight } } });
    }
  }, [contentHeight, authoredHeight, layoutChanging, id, props.onResize]);

  useEffect(() => {
    props.onReady({ id: `${id}` });
  }, []);

  return (
    <AccordionView
      ref={containerRef}
      id={`${id}-view`}
      model={{ ...model, height: Math.max(authoredHeight, contentHeight) }}
      expandedSections={AUTHOR_PREVIEW_EXPANDED}
      interactive={false}
      className="janus-accordion--authoring"
    />
  );
};

export { tagName };
export default AccordionAuthor;
