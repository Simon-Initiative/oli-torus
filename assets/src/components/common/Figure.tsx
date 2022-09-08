import React, { ReactNode } from 'react';
import { SemanticChildren } from '../../data/content/model/elements/types';
import { WriterContext } from '../../data/content/writers/context';
import { HtmlContentModelRenderer } from '../../data/content/writers/renderer';

export const Figure: React.FC<{
  title: SemanticChildren[];
  children: ReactNode;
  context: WriterContext;
}> = ({ title, children, context }) => (
  <div className="figure">
    <figure>
      <figcaption>
        <HtmlContentModelRenderer context={context} content={title} />
      </figcaption>
      <div className="figure-content">{children}</div>
    </figure>
  </div>
);
