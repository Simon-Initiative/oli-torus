import { Stem } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import './StemDelivery.scss';

interface Props {
  stem: Stem;
  context: WriterContext;
}

export const StemDelivery: React.FC<Props> = ({ stem, context }) => {
  return (
    <div className="stem__delivery">
      <HtmlContentModelRenderer text={stem.content} context={context} />
    </div>
  );
};
