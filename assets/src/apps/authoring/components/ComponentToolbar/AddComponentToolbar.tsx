import { selectPartComponentTypes, selectPaths } from 'apps/authoring/store/app/slice';
import React, { Fragment } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import guid from 'utils/guid';

const AddComponentToolbar: React.FC = () => {
  const paths = useSelector(selectPaths);
  const imgsPath = paths?.images || '';

  const availablePartComponents = useSelector(selectPartComponentTypes);

  console.log('AVAILABLE PART COMPONENTS', availablePartComponents);

  const handleAddComponent = (partComponentType: string) => {
    const partComponent = availablePartComponents.find((p) => p.slug === partComponentType);
    if (!partComponent) {
      console.warn(`No part ${partComponentType} found in registry!`, { availablePartComponents });
      return;
    }
    const PartClass = customElements.get(partComponent.authoring_element);
    if (PartClass) {
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
      console.log('creating new part', newPartData);
    }
  };

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
