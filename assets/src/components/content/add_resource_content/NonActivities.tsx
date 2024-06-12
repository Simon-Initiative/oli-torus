import React, { useEffect, useState } from 'react';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { FetchDataModal } from 'components/modal/FetchDataModal';
import { SelectModal } from 'components/modal/SelectModal';
import { ManageAlternativesLink } from 'components/resource/editors/AlternativesEditor';
import { modalActions } from 'actions/modal';
import { FeatureFlags } from 'apps/page-editor/types';
import {
  ResourceContext,
  createAlternatives,
  createDefaultStructuredContent,
  createGroup,
} from 'data/content/resource';
import {
  ResourceContent,
  createBreak,
  createDefaultSelection,
  createSurvey,
} from 'data/content/resource';
import * as Persistence from 'data/persistence/resource';
import { ResourceChoice } from './ResourceChoice';

interface Props {
  index: number[];
  onAddItem: AddCallback;
  parents: ResourceContent[];
  featureFlags: FeatureFlags;
  resourceContext: ResourceContext;
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
  resourceContext,
}) => {
  const [ABTestDisabled, setABTestDisabled] = useState(true);

  useEffect(() => {
    setABTestDisabled(!resourceContext.hasExperiments);
  }, []);

  return (
    <div className="d-flex flex-column">
      <div className="resource-choice-header">Content types</div>

      <div className="resource-choices non-activities">
        <ResourceChoice
          icon="paragraph"
          label="Paragraph"
          onHoverStart={() =>
            onSetTip('Rich content such as paragraphs, images, tables, YouTube, etc')
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
          onHoverStart={() => onSetTip('Randomly select questions from the activity bank')}
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
          icon="window-restore"
          label="Alt"
          onHoverStart={() =>
            onSetTip('Alternative materials which will be displayed based on student preference')
          }
          onHoverEnd={() => onResetTip()}
          key={'alternatives'}
          disabled={false}
          onClick={() => addAlternatives(onAddItem, index, resourceContext.projectSlug)}
        />
        <ResourceChoice
          icon="vial"
          label="A/B Test"
          onHoverStart={() => onSetTip('A/B Testing is not yet supported')}
          onHoverEnd={() => onResetTip()}
          key={'ab-test'}
          disabled={ABTestDisabled}
          onClick={() => addExperiment(onAddItem, index, resourceContext.projectSlug)}
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
  onAddItem(createGroup(index.length > 1 ? 'none' : 'didigetthis'), index);
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

const addAlternatives = (onAddItem: AddCallback, index: number[], projectSlug: string) => {
  // hide insert menu
  document.body.click();

  window.oliDispatch(
    modalActions.display(
      <SelectModal
        title="Select Alternatives Group"
        description="Select an Alternatives Group"
        additionalControls={
          <ManageAlternativesLink
            linkHref={`/authoring/project/${projectSlug}/alternatives`}
            linkText="Manage Alternatives"
          />
        }
        onFetchOptions={() =>
          Persistence.alternatives(projectSlug).then((result) => {
            if (result.type === 'success') {
              return result.alternatives
                .filter(
                  (a: Persistence.AlternativesGroup) => a.strategy !== 'upgrade_decision_point',
                )
                .map((a) => ({ value: a.id, title: a.title }));
            } else {
              throw result.message;
            }
          })
        }
        onDone={(alternativesId: string) => {
          window.oliDispatch(modalActions.dismiss());
          onAddItem(createAlternatives(Number(alternativesId), 'user_section_preference'), index);
        }}
        onCancel={() => window.oliDispatch(modalActions.dismiss())}
      />,
    ),
  );
};

const addExperiment = (onAddItem: AddCallback, index: number[], projectSlug: string) => {
  document.body.click();

  window.oliDispatch(
    modalActions.display(
      <FetchDataModal
        title="Fetching A/B testing options"
        onFetchData={() =>
          Persistence.alternatives(projectSlug).then((result) => {
            if (result.type === 'success') {
              const experiment = result.alternatives.find(
                (a) => a.strategy === 'upgrade_decision_point',
              );
              if (experiment) {
                return experiment;
              }
              throw 'No experiment found. Please follow the instructions on how to setup and enable A/B testing.';
            } else {
              throw result.message;
            }
          })
        }
        onDone={(experiment: Persistence.AlternativesGroup) => {
          window.oliDispatch(modalActions.dismiss());
          onAddItem(createAlternatives(Number(experiment.id), 'upgrade_decision_point'), index);
        }}
        onCancel={() => window.oliDispatch(modalActions.dismiss())}
      />,
    ),
  );
};
