import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { selectPartComponentTypes, selectPaths } from 'apps/authoring/store/app/slice';
import { findInSequenceByResourceId } from 'apps/delivery/store/features/groups/actions/sequence';
import {
  selectCurrentActivityTree,
  selectSequence,
} from 'apps/delivery/store/features/groups/selectors/deck';
import React, { Fragment, useCallback } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import guid from 'utils/guid';

const AddComponentToolbar: React.FC = () => {
  const dispatch = useDispatch();
  const paths = useSelector(selectPaths);
  const imgsPath = paths?.images || '';

  const availablePartComponents = useSelector(selectPartComponentTypes);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentSequence = useSelector(selectSequence);

  console.log('AVAILABLE PART COMPONENTS', availablePartComponents);

  const handleAddComponent = useCallback(
    (partComponentType: string) => {
      if (!availablePartComponents || !currentActivityTree) {
        return;
      }
      const partComponent = availablePartComponents.find((p) => p.slug === partComponentType);
      if (!partComponent) {
        console.warn(`No part ${partComponentType} found in registry!`, {
          availablePartComponents,
        });
        return;
      }
      const PartClass = customElements.get(partComponent.authoring_element);
      if (PartClass) {
        // only ever add to the current activity, not a layer
        const [currentActivity] = currentActivityTree.slice(-1);
        const clonedActivity = clone(currentActivity);
        const sequenceEntry = findInSequenceByResourceId(
          currentSequence,
          currentActivity.resourceId,
        );

        const part = new PartClass();
        const newPartData = {
          id: `${partComponentType}-${guid()}`,
          type: partComponent.delivery_element,
          custom: {
            x: 10,
            y: 10,
            z: 0,
            width: 100,
            height: 100,
          },
        };
        const creationContext = { transform: { ...newPartData.custom } };
        if (part.createSchema) {
          newPartData.custom = { ...newPartData.custom, ...part.createSchema(creationContext) };
        }
        const partIdentifier = {
          id: newPartData.id,
          type: newPartData.type,
          owner: sequenceEntry?.custom?.sequenceId || '',
          inherited: false,
          // objectives: [],
        };

        clonedActivity.authoring.parts.push(partIdentifier);
        clonedActivity.content.partsLayout.push(newPartData);

        console.log('creating new part', { newPartData, clonedActivity, currentSequence });

        dispatch(saveActivity({ activity: clonedActivity }));
      }
    },
    [availablePartComponents, currentActivityTree, currentSequence],
  );

  // TODO: allow dynamic altering of "frequently used" per user?
  // and/or split based on media query available size?
  // and/or split by other groups?
  const frequentlyUsed = [
    'janus_text_flow',
    'janus_image',
    'janus_mcq',
    'janus_video',
    'janus_input_text',
    'janus_capi_iframe',
  ];

  return (
    <Fragment>
      <div className="btn-group pr-3 border-right align-items-center" role="group">
        {availablePartComponents
          .filter((part) => frequentlyUsed.includes(part.slug))
          .map((part) => (
            <OverlayTrigger
              key={part.partComponentType}
              placement="bottom"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  {part.title}
                </Tooltip>
              }
            >
              <span>
                <button className="px-2 btn btn-link" onClick={() => handleAddComponent(part.slug)}>
                  <img src={`${imgsPath}/icons/${part.icon}`}></img>
                </button>
              </span>
            </OverlayTrigger>
          ))}
      </div>
      <div className="btn-group px-3 border-right align-items-center" role="group">
        <OverlayTrigger
          placement="bottom"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              All Components
            </Tooltip>
          }
        >
          <span>
            <button className="px-2 btn btn-link" disabled>
              <img src={`${imgsPath}/icons/icon-componentList.svg`}></img>
            </button>
          </span>
        </OverlayTrigger>
      </div>
    </Fragment>
  );
};

export default AddComponentToolbar;
