import React, { useEffect, useMemo } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import AccordionView, { tagName } from './AccordionView';
import { parseAccordionModel } from './accordion-util';
import { AccordionModel } from './schema';

const AUTHOR_PREVIEW_EXPANDED = [1];

const AccordionAuthor: React.FC<AuthorPartComponentProps<AccordionModel>> = (props) => {
  const { id } = props;
  const model = useMemo(() => parseAccordionModel(props.model), [props.model]);

  useEffect(() => {
    props.onReady({ id: `${id}` });
  }, []);

  return (
    <AccordionView
      id={`${id}-view`}
      model={model}
      expandedSections={AUTHOR_PREVIEW_EXPANDED}
      interactive={false}
      className="janus-accordion--authoring"
    />
  );
};

export { tagName };
export default AccordionAuthor;
