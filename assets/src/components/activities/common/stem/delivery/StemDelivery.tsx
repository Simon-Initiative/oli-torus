import { Stem } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import './StemDelivery.scss';

interface Props {
  stem: Stem;
  context: WriterContext;
  className?: string;
}

export const StemDelivery: React.FC<Props> = (props) => {
  return (
    <div className={`stem__delivery${props.className ? ' ' + props.className : ''}`}>
      <HtmlContentModelRenderer text={props.stem.content} context={props.context} />
    </div>
  );
};
