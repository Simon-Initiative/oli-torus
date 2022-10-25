import React, { MouseEventHandler, ReactNode } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { HtmlContentModelRenderer } from '../../data/content/writers/renderer';
import { WriterContext } from '../../data/content/writers/context';

export const DescriptionList: React.FC<{
  description: ContentModel.DescriptionList;
  context: WriterContext;
}> = ({ description, context }) => {
  return (
    <>
      <h4>
        <HtmlContentModelRenderer context={context} content={description.title} />
      </h4>
      <dl>
        <HtmlContentModelRenderer context={context} content={description.items} />
      </dl>
    </>
  );
};
