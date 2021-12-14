import React, { Fragment, useCallback, useEffect, useState } from 'react';
import { ListGroup, Overlay, OverlayTrigger, Popover, Tooltip } from 'react-bootstrap';
import guid from 'utils/guid';
const AddPartToolbar = ({ partTypes, priorityTypes = [], onAdd, }) => {
    const paths = { images: '/images' }; // TODO: provide context to authoring
    const imgsPath = (paths === null || paths === void 0 ? void 0 : paths.images) || '';
    const availablePartComponents = window['partComponentTypes'] || []; // TODO: replace with context
    const [priorityPartComponents, setPriorityPartComponents] = useState([]);
    const [otherPartComponents, setOtherPartComponents] = useState([]);
    const [showMorePartsMenu, setShowMorePartsMenu] = useState(false);
    const [morePartsMenuTarget, setMorePartsMenuTarget] = useState(null);
    const handleMoreButtonClick = (e) => {
        setShowMorePartsMenu((current) => !current);
        setMorePartsMenuTarget(e.target);
    };
    const handleAddPartClick = useCallback((partSlug) => {
        setShowMorePartsMenu(false);
        setMorePartsMenuTarget(null);
        const partType = availablePartComponents.find((p) => p.slug === partSlug);
        if (partType) {
            const PartClass = customElements.get(partType.authoring_element);
            if (PartClass) {
                const part = new PartClass();
                const newPartData = {
                    id: `${partSlug}-${guid()}`,
                    type: partType.delivery_element,
                    custom: {
                        x: 10,
                        y: 10,
                        z: 0,
                        width: 100,
                        height: 100,
                    },
                };
                const creationContext = { transform: Object.assign({}, newPartData.custom) };
                if (part.createSchema) {
                    newPartData.custom = Object.assign(Object.assign({}, newPartData.custom), part.createSchema(creationContext));
                }
                onAdd(newPartData);
            }
        }
    }, [availablePartComponents, onAdd]);
    useEffect(() => {
        const filteredByPriority = availablePartComponents
            .filter((part) => partTypes[0] === '*' || partTypes.includes(part.slug))
            .filter((part) => priorityTypes.includes(part.slug))
            .sort((a, b) => {
            const aIndex = priorityTypes.indexOf(a.slug);
            const bIndex = priorityTypes.indexOf(b.slug);
            return aIndex - bIndex;
        });
        setPriorityPartComponents(filteredByPriority);
        const remainder = availablePartComponents
            .filter((part) => partTypes[0] === '*' || partTypes.includes(part.slug))
            .filter((part) => !priorityTypes.includes(part.slug));
        setOtherPartComponents(remainder);
    }, [availablePartComponents, priorityTypes]);
    return (<Fragment>
      <div className="btn-group align-items-center" role="group">
        {priorityPartComponents.map((part) => (<OverlayTrigger key={part.slug} placement="bottom" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                <strong>{part.title}</strong>
                <br />
                <em>{part.description}</em>
              </Tooltip>}>
            <span>
              <button className="px-2 btn btn-link" onClick={() => handleAddPartClick(part.slug)}>
                <img src={`${imgsPath}/icons/${part.icon}`}></img>
              </button>
            </span>
          </OverlayTrigger>))}
      </div>
      {otherPartComponents.length > 0 && (<div className="btn-group pl-3 ml-3 border-left align-items-center" role="group">
          <OverlayTrigger placement="bottom" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                More Components
              </Tooltip>}>
            <span>
              <button className="px-2 btn btn-link" onClick={handleMoreButtonClick}>
                <img src={`${imgsPath}/icons/icon-componentList.svg`}></img>
              </button>
            </span>
          </OverlayTrigger>
          <Overlay show={showMorePartsMenu} target={morePartsMenuTarget} placement="bottom" container={document.getElementById('advanced-authoring')} containerPadding={20} rootClose={true} onHide={() => setShowMorePartsMenu(false)}>
            <Popover id="moreComponents-popover">
              <Popover.Title as="h3">More Components</Popover.Title>
              <Popover.Content>
                <ListGroup className="aa-parts-list">
                  {otherPartComponents.map((part) => (<ListGroup.Item action onClick={() => handleAddPartClick(part.slug)} key={part.slug} className="d-flex align-items-center">
                      <div className="text-center mr-1 d-inline-block" style={{ minWidth: '36px' }}>
                        <img title={part.description} src={`${imgsPath}/icons/${part.icon}`}/>
                      </div>
                      <span className="mr-3">{part.title}</span>
                    </ListGroup.Item>))}
                </ListGroup>
              </Popover.Content>
            </Popover>
          </Overlay>
        </div>)}
    </Fragment>);
};
export default AddPartToolbar;
//# sourceMappingURL=AddPartToolbar.jsx.map