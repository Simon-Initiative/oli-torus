import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { HasStem, Stem, HasContent } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';

import './StemDelivery.scss';

interface StemProps {
  stem: Stem;
  context: WriterContext;
  className?: string;
}

export const StemDelivery: React.FC<StemProps> = (props) => {
  return (
    <div className={`stem__delivery${props.className ? ' ' + props.className : ''}`}>
      <HtmlContentModelRenderer content={props.stem.content} context={props.context} />
    </div>
  );
};

interface Props {
  className?: string;
}
export const StemDeliveryConnected: React.FC<Props> = (props) => {
  const { model, writerContext } = useDeliveryElementContext<HasStem>();
  return <StemDelivery stem={model.stem} context={writerContext} {...props} />;
};
