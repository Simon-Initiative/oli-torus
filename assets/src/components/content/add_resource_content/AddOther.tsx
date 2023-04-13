import React from 'react';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { FeatureFlags } from 'apps/page-editor/types';
import {
  ResourceContent,
  createBreak,
  createDefaultSelection,
  createSurvey,
} from 'data/content/resource';

// returns true if non of the parents are a survey element
const canInsertSurvey = (parents: ResourceContent[], featureFlags: FeatureFlags) =>
  featureFlags.survey && parents.every((p) => p.type !== 'survey');

interface Props {
  index: number[];
  parents: ResourceContent[];
  featureFlags: FeatureFlags;
  onAddItem: AddCallback;
}

export const AddOther: React.FC<Props> = ({ onAddItem, index, parents, featureFlags }) => {
  return (
    <>
      <div className="list-group">
        <button
          key={'static_activity_bank'}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={() => {
            onAddItem(createDefaultSelection(), index);
            document.body.click();
          }}
        >
          <div className="type-label">Activity Bank Selection</div>
          <div className="type-description">
            Select different activities at random according to defined criteria
          </div>
        </button>
        <button
          key={'page_break'}
          className="list-group-item list-group-item-action d-flex flex-column align-items-start"
          onClick={(_e) => addPageBreak(onAddItem, index)}
        >
          <div className="type-label">Content Break</div>
          <div className="type-description">
            Add a content break to split content across multiple pages
          </div>
        </button>
        {canInsertSurvey(parents, featureFlags) && (
          <button
            key={'survey'}
            className="list-group-item list-group-item-action d-flex flex-column align-items-start"
            onClick={(_e) => addSurvey(onAddItem, index)}
          >
            <div className="type-label">Survey</div>
            <div className="type-description">
              A collection of content and activities used to collect ungraded feedback from students
            </div>
          </button>
        )}
      </div>
    </>
  );
};

const addPageBreak = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createBreak(), index);
  document.body.click();
};

const addSurvey = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createSurvey(), index);
  document.body.click();
};
