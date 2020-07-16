import React, { useState } from 'react';
import { ResourceContent, Activity, ResourceContext, ActivityReference,
  createDefaultStructuredContent } from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityModelSchema } from 'components/activities/types';
import { invokeCreationFunc } from 'components/activities/creation';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import * as Persistence from 'data/persistence/activity';
import guid from 'utils/guid';
import Popover from 'react-tiny-popover';

import { modalActions } from 'actions/modal';
import * as Immutable from 'immutable';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

import './AddResourceContent.scss';
import { classNames } from 'utils/classNames';
import { ObjectiveSelection } from 'components/resource/ObjectiveSelection';
import ModalSelection from 'components/modal/ModalSelection';

type AddCallback = (content: ResourceContent, index: number, a? : Activity) => void;


const promptForObjectiveSelection
  = (objectives: Immutable.List<Objective>,
    childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
    onRegisterNewObjective: (title: string) => Promise<Objective>) => {

    return new Promise((resolve, reject) => {

      const onRegister = (title: string) : Promise<Objective> => {
        return new Promise((inner, reject) => {
          onRegisterNewObjective(title)
          .then((objective) => {
            dismiss();
            resolve(Immutable.List<ObjectiveSlug>([objective.slug]));
          });
        });
      };

      const onUseSelected = (selected: Immutable.List<ObjectiveSlug>) => {
        dismiss();
        resolve(selected);
      };

      display(<ModalSelection title="Target learning objectives with this activity"
        hideOkButton={true}
        cancelLabel="Skip this step"
        onInsert={() => { dismiss(); }}
        onCancel={() => { dismiss(); }}>

        <ObjectiveSelection objectives={objectives}
          childrenObjectives={childrenObjectives}
          onUseSelected={onUseSelected}
          onRegisterNewObjective={onRegister}/>
      </ModalSelection>);
    });

  };


// Component that presents a drop down to use to add structure
// content or the any of the registered activities
export const AddResourceContent = (
  { editMode, index, onAddItem, editorMap, resourceContext, isLast,
    objectives, onRegisterNewObjective, childrenObjectives }
  : {editMode: boolean, index: number, onAddItem: AddCallback, isLast: boolean,
    objectives: Immutable.List<Objective>,
    childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
    onRegisterNewObjective: (text: string) => Promise<Objective>,
    editorMap: ActivityEditorMap, resourceContext: ResourceContext  }) => {

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const handleAdd = (editorDesc: EditorDesc) => {

    let model : ActivityModelSchema;

    promptForObjectiveSelection(objectives, childrenObjectives, onRegisterNewObjective)
    .then((objectives: string[]) => invokeCreationFunc(editorDesc.slug, resourceContext)
      .then((createdModel) => {

        model = createdModel;
        return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, objectives);
      })
      .then((result: Persistence.Created) => {

        const resourceContent : ActivityReference = {
          type: 'activity-reference',
          id: guid(),
          activitySlug: result.revisionSlug,
          purpose: 'none',
          children: [],
        };

        const activity : Activity = {
          type: 'activity',
          activitySlug: result.revisionSlug,
          typeSlug: editorDesc.slug,
          model,
          transformed: result.transformed,
        };

        onAddItem(resourceContent, index, activity);
      })
      .catch((err) => {
        // console.log(err);
      }));
  };

  const content =
    <div className="insert-item list-group-item list-group-item-action" key="content"
      onClick={() => onAddItem(createDefaultStructuredContent(), index)}>
      Content
    </div>;

  const activityEntries = Object
    .keys(editorMap)
    .map((k: string) => {
      const editorDesc : EditorDesc = editorMap[k];
      return (
        <div className="insert-item list-group-item list-group-item-action" key={editorDesc.slug}
            onClick={handleAdd.bind(this, editorDesc)}>
            {editorDesc.friendlyName}
        </div>
      );
    });

  const contentFn = () =>
      <div className="add-resource-popover-content">
        <div className="list-group">
          {[content, ...activityEntries]}
        </div>
      </div>;

  const [latestClickEvent, setLatestClickEvent] = useState<MouseEvent>();
  const togglePopover = (e: React.MouseEvent) => {
    setIsPopoverOpen(!isPopoverOpen);
    setLatestClickEvent(e.nativeEvent);
  };

  return (
      <div className={classNames(['add-resource-content', isPopoverOpen ? 'active' : '', isLast ? 'add-resource-content-last' : ''])}
        onClick={togglePopover}>

        {editMode &&
          <React.Fragment>
            <div className="insert-button-container">
              <Popover
                containerClassName="add-resource-popover"
                onClickOutside={(e) => {
                  if (e !== latestClickEvent) {
                    setIsPopoverOpen(false);
                  }
                }}
                isOpen={isPopoverOpen}
                align="start"
                transitionDuration={0.25}
                position={['bottom', 'top']}
                content={contentFn}>
                  {ref => <div ref={ref} className="insert-button">
                    <i className="fa fa-plus"></i>
                  </div>}
              </Popover>
            </div>
            <div className="insert-adornment"></div>
          </React.Fragment>
        }

      </div>
  );
};
