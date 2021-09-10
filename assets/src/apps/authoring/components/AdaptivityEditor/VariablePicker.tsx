import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { selectPartComponentTypes, selectPaths } from 'apps/authoring/store/app/slice';
import {
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
  SequenceHierarchyItem,
} from 'apps/delivery/store/features/groups/actions/sequence';
import {
  selectCurrentActivityTree,
  selectSequence,
} from 'apps/delivery/store/features/groups/selectors/deck';
import React, { Fragment, useCallback, useEffect, useRef, useState } from 'react';
import {
  Accordion,
  Button,
  ButtonGroup,
  Card,
  Dropdown,
  DropdownButton,
  ListGroup,
  OverlayTrigger,
  Popover,
} from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { SequenceDropdown } from '../PropertyEditor/custom/SequenceDropdown';
import { promises } from 'dns';

export enum OverlayPlacements {
  TOP = 'top',
  RIGHT = 'right',
  BOTTOM = 'bottom',
  LEFT = 'left',
}
enum FilterItems {
  SCREEN = 'This Screen',
  SESSION = 'Session',
  LESSON = 'Lesson Variables',
}
interface VariablePickerProps {
  placement?: OverlayPlacements;
  targetRef: React.RefObject<HTMLInputElement>;
  typeRef: React.RefObject<HTMLSelectElement>;
}

export const VariablePicker: React.FC<VariablePickerProps> = ({
  placement = OverlayPlacements.TOP,
  targetRef,
  typeRef,
}) => {
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);
  const vpContainerRef = useRef(document.getElementById('advanced-authoring'));
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const paths = useSelector(selectPaths);
  const availablePartComponents = useSelector(selectPartComponentTypes);
  const [isFilterMenuOpen, setIsFilterMenuOpen] = useState<boolean>(false);
  const [activeFilter, setActiveFilter] = useState<string>(FilterItems.SCREEN);
  const [partAdaptivityMap, setPartAdaptivityMap] = useState<Record<string, any>>({});
  const [allParts, setAllParts] = useState([]);

  // TODO: figure out how to swap in parts for any sequence activity tree

  const setTargetRef = (setTo: string) => {
    setTimeout(() => {
      if (targetRef?.current) {
        targetRef.current.value = setTo;
        targetRef.current.focus();
      }
    });
  };
  const setTypeRef = (setTo: string) => {
    const event = new Event('change', { bubbles: true });
    setTimeout(() => {
      if (typeRef?.current) {
        typeRef.current.value = setTo;
        typeRef.current.click();
        typeRef.current.dispatchEvent(event);
        typeRef.current.focus();
      }
    });
  };

  const onChangeHandler = (
    item: null | SequenceHierarchyItem<SequenceEntryChild>,
    e?: React.MouseEvent,
    isNextButton?: boolean,
  ) => {
    item ? setActiveFilter(item?.custom.sequenceName) : '';
    setIsFilterMenuOpen(false);
    const itemId = isNextButton ? 'next' : item?.custom.sequenceId;
  };

  const getPartIcon = (type: string) => {
    const part = availablePartComponents.find((part) => part.delivery_element === type);
    if (!part) {
      return `${paths?.images}/icons/icon-componentList.svg`;
    }
    // TODO: test if part.icon starts with http and if so use that instead of the paths.images
    return `${paths?.images}/icons/${part.icon}`;
  };

  const getPartTypeTemplate = useCallback(
    (part: Record<string, string>, index: number) => {
      const adaptivitySchema = partAdaptivityMap[part.type];
      if (adaptivitySchema) {
        return (
          <>
            <Accordion.Toggle as={ListGroup.Item} eventKey={`${index}`} action>
              <div className="text-center mr-1 d-inline-block" style={{ minWidth: '36px' }}>
                <img title={part.type} src={getPartIcon(part.type)} />
              </div>
              <span className="mr-2">{part.id}</span>
            </Accordion.Toggle>
            <Accordion.Collapse eventKey={`${index}`}>
              <>
                {Object.keys(adaptivitySchema).map((key, index) => (
                  <div
                    key={index}
                    onClick={() => {
                      setTargetRef(`stage.${part.id}.${key}`);
                      setTypeRef(`${adaptivitySchema[key]}`);
                    }}
                  >
                    {key} is {adaptivitySchema[key]}
                  </div>
                ))}
              </>
            </Accordion.Collapse>
          </>
        );
      }
      return null;
    },
    [partAdaptivityMap],
  );

  const getAdaptivePartTypes = useCallback(async () => {
    const getMapPromises = allParts.map(async (part: any) => {
      let adaptivitySchema: any = null;
      const PartClass = customElements.get(part.type);
      if (PartClass) {
        const instance: any = new PartClass();
        if (instance) {
          if (instance.getAdaptivitySchema) {
            adaptivitySchema = await instance.getAdaptivitySchema();
          }
        }
      }
      return { adaptivitySchema, type: part.type };
    });
    const mapItems = await Promise.all(getMapPromises);
    const adaptivityMap: any = mapItems.reduce((acc: any, typeToAdaptivitySchemaMap: any) => {
      acc[typeToAdaptivitySchemaMap.type] = typeToAdaptivitySchemaMap.adaptivitySchema;
      return acc;
    }, {});
    setPartAdaptivityMap(adaptivityMap);
  }, [allParts, currentActivityTree]);

  useEffect(() => {
    getAdaptivePartTypes();
  }, [allParts, currentActivityTree]);

  useEffect(() => {
    const someParts = (currentActivityTree || [])
      .slice(-1)
      .reduce((acc, activity) => acc.concat(activity.content.partsLayout || []), []);
    setAllParts(someParts);
  }, [currentActivityTree]);

  return (
    <OverlayTrigger
      rootClose
      trigger="click"
      placement={placement}
      container={vpContainerRef.current}
      onExit={() => setIsFilterMenuOpen(false)}
      overlay={
        <Popover id={`aa-variable-picker`}>
          <Popover.Title as="h3">{`Variable Picker`}</Popover.Title>
          <Popover.Content>
            <div className="target-select-container">
              <div className="input-group input-group-sm flex-grow-1">
                <div className="input-group-prepend" title="filter">
                  <div className="input-group-text">
                    <i className="fa fa-filter" />
                  </div>
                </div>
                <Dropdown className="flex-grow-1" show={isFilterMenuOpen}>
                  <Dropdown.Toggle
                    id="target-select"
                    size="sm"
                    split
                    variant="secondary"
                    className="d-flex align-items-center w-100 flex-grow-1"
                    onClick={() => setIsFilterMenuOpen(!isFilterMenuOpen)}
                  >
                    <span className="w-100 d-flex">{activeFilter}</span>
                  </Dropdown.Toggle>
                  <Dropdown.Menu
                    className="w-100"
                    onClick={() => setIsFilterMenuOpen(!isFilterMenuOpen)}
                    show={isFilterMenuOpen}
                    rootCloseEvent="click"
                  >
                    <Dropdown.Item
                      active={activeFilter === FilterItems.SCREEN}
                      onClick={() => setActiveFilter(FilterItems.SCREEN)}
                    >
                      {FilterItems.SCREEN}
                    </Dropdown.Item>
                    <Dropdown.Item
                      active={activeFilter === FilterItems.SESSION}
                      onClick={() => setActiveFilter(FilterItems.SESSION)}
                    >
                      {FilterItems.SESSION}
                    </Dropdown.Item>
                    <Dropdown.Item
                      active={activeFilter === FilterItems.LESSON}
                      onClick={() => setActiveFilter(FilterItems.LESSON)}
                    >
                      {FilterItems.LESSON}
                    </Dropdown.Item>
                    <Dropdown.Divider />
                    <Dropdown.Header>Other Screens</Dropdown.Header>
                    <div className="screen-picker-container">
                      <SequenceDropdown
                        items={hierarchy}
                        onChange={onChangeHandler}
                        value={'next'}
                        showNextBtn={false}
                      />
                    </div>
                  </Dropdown.Menu>
                </Dropdown>
              </div>
            </div>
            <div className="activity-tree">
              <Accordion>
                {allParts.map((part: any, index: number) => (
                  <Fragment key={part.id}>{getPartTypeTemplate(part, index)}</Fragment>
                ))}
              </Accordion>
            </div>
          </Popover.Content>
        </Popover>
      }
    >
      <Button className="input-group-text">
        <i className="fa fa-crosshairs" />
      </Button>
    </OverlayTrigger>
  );
};
