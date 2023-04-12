import './StemDelivery.scss';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { HasStem, Stem } from 'components/activities/types';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import { useSelector } from 'react-redux';

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
  const { writerContext } = useDeliveryElementContext<HasStem>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return <StemDelivery stem={(uiState.model as any).stem} context={writerContext} {...props} />;
};
