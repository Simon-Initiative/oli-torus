import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { OliEmbeddedModelSchema } from './schema';
import { RichText, ScoringStrategy } from '../types';

export const defaultEmbeddedModel: () => OliEmbeddedModelSchema = () => {
  return {
    modelXml: '<?xml version="1.0" encoding="UTF-8"?>\n' +
      '<!DOCTYPE embed_activity PUBLIC "-//Carnegie Mellon University//DTD Embed 1.1//EN" "http://oli.cmu.edu/dtd/oli-embed-activity_1.0.dtd">\n' +
      '<embed_activity id="dndembed" width="670" height="700">\n' +
      '<title>Drag and Drop Activity</title>\n' +
      '<source>webcontent/customact/dragdrop.js</source>\n' +
      '\t<assets>\n' +
      '\t\t<asset name="layout">webcontent/customact/layout1.html</asset>\n' +
      '\t\t<asset name="controls">webcontent/customact/controls.html</asset>\n' +
      '\t\t<!-- This is a global asset for activity -->\n' +
      '\t\t<asset name="dndstyles">webcontent/customact/dndstyles1.css</asset>\n' +
      '\t\t<asset name="questions">webcontent/customact/parts1.xml</asset>\n' +
      '\t</assets>\n' +
      '</embed_activity>',
    resourceUrls: [],
    stem: fromText(''),
    title: 'Embedded activity',
    authoring: {
      parts: [{
        id: '1', // an embedded only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        hints: [],
      }],
      previewText: '',
    },
  };
};

export function fromText(text: string): { id: string, content: RichText } {
  return {
    id: guid() + '',
    content: {
      model: [
        ContentModel.create<ContentModel.Paragraph>({
          type: 'p',
          children: [{ text }],
          id: guid() + '',
        }),
      ],
      selection: null,
    },
  };
}