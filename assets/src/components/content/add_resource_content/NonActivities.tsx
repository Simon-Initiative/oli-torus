import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultStructuredContent, createGroup } from 'data/content/resource';

import {
  createDefaultSelection,
  createBreak,
  createSurvey,
  ResourceContent,
} from 'data/content/resource';
import React from 'react';
import { ResourceChoice } from './ResourceChoice';
import { FeatureFlags } from 'apps/page-editor/types';

interface Props {
  index: number[];
  onAddItem: AddCallback;
  parents: ResourceContent[];
  featureFlags: FeatureFlags;
  onSetTip: (tip: string) => void;
  onResetTip: () => void;
}

export const NonActivities: React.FC<Props> = ({
  onSetTip,
  onResetTip,
  onAddItem,
  index,
  parents,
  featureFlags,
}) => {
  return (
    <div className="d-flex flex-column">
      <div className="resource-choice-header">Content types</div>

      <div className="resource-choices non-activities">
        <ResourceChoice
          icon="edit"
          label="Mixed"
          onHoverStart={() =>
            onSetTip(
              'Author mixed, HTML-like content such as paragraphs, images, tables, YouTube, etc',
            )
          }
          onHoverEnd={() => onResetTip()}
          key={'static_html_content'}
          disabled={false}
          onClick={() => addContent(onAddItem, index)}
        />
        <ResourceChoice
          icon="layer-group"
          label="Group"
          onHoverStart={() =>
            onSetTip('Group related questions and content together to assign a purpose')
          }
          onHoverEnd={() => onResetTip()}
          key={'group'}
          disabled={false}
          onClick={() => addGroup(onAddItem, index)}
        />
        <ResourceChoice
          icon="random"
          label="Bank"
          onHoverStart={() => onSetTip('Randomnly select questions from the activity bank')}
          onHoverEnd={() => onResetTip()}
          key={'selection'}
          disabled={false}
          onClick={() => {
            onAddItem(createDefaultSelection(), index);
            document.body.click();
          }}
        />
        <ResourceChoice
          icon="columns"
          label="Break"
          onHoverStart={() => onSetTip('Separate items with a carousel-like paging mechanism')}
          onHoverEnd={() => onResetTip()}
          key={'static_html_break'}
          disabled={false}
          onClick={() => addPageBreak(onAddItem, index)}
        />
        <ResourceChoice
          icon="poll"
          label="Survey"
          onHoverStart={() => onSetTip('Collect student feedback via no-stakes activities')}
          onHoverEnd={() => onResetTip()}
          key={'survey'}
          disabled={false}
          onClick={() => addSurvey(onAddItem, index)}
        />
        <ResourceChoice
          icon="vial"
          label="A/B Test"
          onHoverStart={() => onSetTip('A/B Testing is not yet supported')}
          onHoverEnd={() => onResetTip()}
          key={'ab-test'}
          disabled={true}
          onClick={() => true}
        />
      </div>
    </div>
  );
};

const addContent = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createDefaultStructuredContent(), index);
  document.body.click();
};

const addGroup = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createGroup(), index);
  document.body.click();
};

const addPageBreak = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createBreak(), index);
  document.body.click();
};

const addSurvey = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createSurvey(), index);
  document.body.click();
};
