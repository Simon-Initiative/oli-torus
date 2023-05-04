import React from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { WriterContext } from '../../data/content/writers/context';
import { HtmlContentModelRenderer } from '../../data/content/writers/renderer';

export const DescriptionList: React.FC<{
  description: ContentModel.DescriptionList;
  context: WriterContext;
}> = ({ description, context }) => {
  return (
    <>
      <h4 className="dl-title">
        <HtmlContentModelRenderer context={context} content={description.title} />
      </h4>
      <dl>
        <HtmlContentModelRenderer context={context} content={description.items} />
      </dl>
    </>
  );
};
