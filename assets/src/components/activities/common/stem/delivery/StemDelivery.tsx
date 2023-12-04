import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { HasStem, Stem } from 'components/activities/types';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import './StemDelivery.scss';

interface StemProps {
  stem: Stem;
  context: WriterContext;
  className?: string;
}

export const StemDelivery: React.FC<StemProps> = (props) => {
  return (
    <div className={`stem__delivery content${props.className ? ' ' + props.className : ''}`}>
      <HtmlContentModelRenderer
        content={props.stem.content}
        context={props.context}
        direction={props.stem.textDirection}
      />
    </div>
  );
};

interface Props {
  className?: string;
}
export const StemDeliveryConnected: React.FC<Props> = (props) => {
  const { writerContext, model } = useDeliveryElementContext<HasStem>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const effectiveModel = uiState.model || model;
  return <StemDelivery stem={(effectiveModel as any).stem} context={writerContext} {...props} />;
};
