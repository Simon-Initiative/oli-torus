import guid from 'utils/guid';
import { ScoringStrategy, makeStem } from '../types';
import { OliEmbeddedModelSchema } from './schema';

export const defaultEmbeddedModel: () => OliEmbeddedModelSchema = () => {
  return {
    base: 'embedded',
    src: 'index.html',
    modelXml: `<?xml version="1.0" encoding="UTF-8"?>
    <embed_activity id="custom_side" width="670" height="300">
        <title>Custom Activity</title>
        <source>webcontent/custom_activity/customactivity.js</source>
        <assets>
            <asset name="layout">webcontent/custom_activity/layout.html</asset>
            <asset name="controls">webcontent/custom_activity/controls.html</asset>
            <asset name="styles">webcontent/custom_activity/styles.css</asset>
            <asset name="questions">webcontent/custom_activity/questions.xml</asset>
        </assets>
    </embed_activity>`,
    resourceBase: guid(),
    resourceURLs: [],
    stem: makeStem(''),
    title: 'Embedded activity',
    authoring: {
      parts: [
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
      ],
      previewText: '',
    },
  };
};

export function lastPart(resourceBase: string, path: string): string {
  if (resourceBase.includes('bundles/')) {
    return path.substring(path.lastIndexOf('webcontent'));
  }
  if (path.includes('media/')) {
    return path.substring(path.lastIndexOf('media/') + 6);
  }
  return path.substring(path.lastIndexOf('/') + 1);
}
