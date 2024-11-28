import React, { Fragment, useCallback, useEffect, useRef, useState } from 'react';
import { Accordion, Button, Dropdown, ListGroup, OverlayTrigger, Popover } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectPartComponentTypes, selectPaths } from 'apps/authoring/store/app/slice';
import { hasNesting, unflatten } from 'apps/delivery/components/preview-tools/inspector/utils';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import {
  SequenceEntryChild,
  SequenceHierarchyItem,
  getHierarchy,
  getSequenceLineage,
} from 'apps/delivery/store/features/groups/actions/sequence';
import {
  selectCurrentActivityTree,
  selectSequence,
} from 'apps/delivery/store/features/groups/selectors/deck';
import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { selectState as selectPageState } from '../../store/page/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import { SequenceDropdown } from '../PropertyEditor/custom/SequenceDropdown';
import { sessionVariables } from './AdaptiveItemOptions';

export enum OverlayPlacements {
  TOP = 'top',
  RIGHT = 'right',
  BOTTOM = 'bottom',
  LEFT = 'left',
}
enum FilterItems {
  SCREEN = 'This Screen',
  SESSION = 'Session',
  VARIABLES = 'Lesson Variables',
}
interface VariablePickerProps {
  placement?: OverlayPlacements;
  targetRef?: React.RefObject<HTMLInputElement>;
  typeRef?: React.RefObject<HTMLSelectElement>;
  onTargetChange?: (value: any) => any;
  onTypeChange?: (value: any) => any;
  context: 'init' | 'mutate' | 'condition';
}
interface NestedStateDisplayProps {
  rootLevel: any;
  currentTarget: string;
  state: any;
  currentState?: any;
  onClick?: (key: string, variableType: string) => void;
}

export interface LessonVariable {
  name: string;
  expression: string;
}

export const VariablePicker: React.FC<VariablePickerProps> = ({
  placement = OverlayPlacements.TOP,
  targetRef,
  typeRef,
  context,
  onTargetChange,
  onTypeChange,
}) => {
  const currentLesson = useSelector(selectPageState);
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);
  const vpContainerRef = useRef(document.getElementById('advanced-authoring'));
  const paths = useSelector(selectPaths);
  const availablePartComponents = useSelector(selectPartComponentTypes);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const allActivities = useSelector(selectAllActivities);

  const [specificSequenceId, setSpecificSequenceId] = useState<string>('stage');
  const [specificActivityTree, setSpecificActivityTree] = useState<any>();
  const [isFilterMenuOpen, setIsFilterMenuOpen] = useState<boolean>(false);
  const [activeFilter, setActiveFilter] = useState<string>(FilterItems.SCREEN);
  const [partAdaptivityMap, setPartAdaptivityMap] = useState<Record<string, string>>({});
  const [allParts, setAllParts] = useState([]);

  const setTargetRef = (setTo: string) => {
    if (targetRef) {
      setTimeout(() => {
        if (targetRef?.current) {
          targetRef.current.value = setTo;
          targetRef.current.click();
          targetRef.current.focus();
        }
      });
    }
    if (onTargetChange) {
      onTargetChange(setTo);
    }
  };
  const setTypeRef = (setTo: string) => {
    if (typeRef) {
      const event = new Event('change', { bubbles: true });
      setTimeout(() => {
        if (typeRef?.current) {
          typeRef.current.value = setTo;
          typeRef.current.click();
          typeRef.current.dispatchEvent(event);
          typeRef.current.focus();
        }
      });
    }
    if (onTypeChange) {
      onTypeChange(setTo);
    }
  };

  const onChangeHandler = (
    item: null | SequenceHierarchyItem<SequenceEntryChild>,
    e?: React.MouseEvent,
    isNextButton?: boolean,
  ) => {
    if (item) {
      const lineage = getSequenceLineage(sequence, item.custom.sequenceId);
      const selectedActivityTree = lineage.map((lineageItem) =>
        allActivities.find((act) => act.id === lineageItem.resourceId),
      );
      setActiveFilter(item?.custom.sequenceName);
      setSpecificActivityTree(selectedActivityTree);
    }
    setIsFilterMenuOpen(false);
    const itemId = isNextButton ? 'next' : item?.custom.sequenceId;
    if (itemId) {
      setSpecificSequenceId(itemId);
    } else {
      return console.warn('SequenceId not found in sequence');
    }
  };

  const getPartIcon = (type: string) => {
    const part = availablePartComponents.find((part) => part.delivery_element === type);
    if (!part) {
      return `${paths?.images}/icons/icon-componentList.svg`;
    }
    // TODO: test if part.icon starts with http and if so use that instead of the paths.images
    return `${paths?.images}/icons/${part.icon}`;
  };

  const getLimitedTypeCheck = (typeToCheck: string | boolean | number | unknown) => {
    const limitedTypeCheck = typeof typeToCheck;
    let limitedType: string | boolean | number;
    switch (limitedTypeCheck) {
      case 'string':
        limitedType = CapiVariableTypes.STRING;
        break;
      case 'boolean':
        limitedType = CapiVariableTypes.BOOLEAN;
        break;
      default:
        limitedType = CapiVariableTypes.NUMBER;
        break;
    }
    return limitedType;
  };

  const getPartTypeTemplate = useCallback(
    (part: Record<string, string>, index: number) => {
      const adaptivitySchema: any = partAdaptivityMap[part.id];
      if (adaptivitySchema) {
        return (
          <>
            <>
              <Accordion.Toggle
                as={ListGroup.Item}
                eventKey={`${index}`}
                action
                className="part-type"
                onClick={() => setIsFilterMenuOpen(false)}
              >
                <div className="d-flex align-items-center justify-space-between flex-grow-1">
                  <div className="d-flex flex-grow-1">
                    <div className="text-center mr-2 d-flex">
                      <img
                        title={part.type}
                        src={getPartIcon(part.type)}
                        className="part-type-icon"
                      />
                    </div>
                    <span className="mr-2">{part.id}</span>
                  </div>
                  <ContextAwareToggle eventKey={`${index}`} />
                </div>
              </Accordion.Toggle>
              <Accordion.Collapse eventKey={`${index}`}>
                <ul className="list-unstyled m-0 mb-2 tree">
                  {Object.keys(adaptivitySchema)
                    .sort()
                    .map((key: string, index: number) =>
                      !hasNesting(adaptivitySchema[key]) ? (
                        <li
                          className="pb-2 pl-1 ml-4"
                          key={index}
                          onClick={() => {
                            setTargetRef(
                              `${
                                specificSequenceId === 'stage'
                                  ? 'stage.'
                                  : `${specificSequenceId}|stage.`
                              }${part.id}.${key}`,
                            );
                            setTypeRef(`${adaptivitySchema[key as unknown as number]}`);
                          }}
                        >
                          <button type="button" className="text-btn font-italic">
                            <span
                              title={
                                CapiVariableTypes[adaptivitySchema[key]][0] +
                                CapiVariableTypes[adaptivitySchema[key]].slice(1).toLowerCase()
                              }
                            >
                              {key}
                            </span>
                          </button>
                        </li>
                      ) : (
                        <TreeView
                          state={adaptivitySchema}
                          onClick={(currentKey, variableType) => {
                            setTargetRef(
                              `${
                                specificSequenceId === 'stage'
                                  ? 'stage.'
                                  : `${specificSequenceId}|stage.`
                              }${part.id}.${currentKey}`,
                            );
                            setTypeRef(variableType);
                          }}
                          rootLevel={key}
                          currentTarget={key}
                        ></TreeView>
                      ),
                    )}
                </ul>
              </Accordion.Collapse>
            </>
          </>
        );
      }
      return null;
    },
    [partAdaptivityMap, specificSequenceId],
  );

  const getAdaptivePartTypes = useCallback(async () => {
    const getMapPromises = allParts.map(async (part: Record<string, string>) => {
      let adaptivitySchema: null | Record<string, string> = null;
      const PartClass = customElements.get(part.type);
      if (PartClass) {
        const instance: any = new PartClass();
        if (instance) {
          if (instance.getAdaptivitySchema) {
            adaptivitySchema = await instance.getAdaptivitySchema({
              currentModel: part,
              editorContext: context,
            });
            if (
              part.type === 'janus-capi-iframe' &&
              adaptivitySchema &&
              Object.keys(adaptivitySchema)?.length
            ) {
              const globalStateAsVars = Object.keys(adaptivitySchema).reduce(
                (collect: any, key: any) => {
                  if (adaptivitySchema) collect[key] = adaptivitySchema[key];
                  return collect;
                },
                {},
              );
              adaptivitySchema = unflatten(globalStateAsVars);
            }
          }
        }
      }
      return { adaptivitySchema, type: part.type, id: part.id };
    });
    const mapItems = await Promise.all(getMapPromises);
    const adaptivityMap: Record<string, string> = mapItems.reduce(
      (acc: any, typeToAdaptivitySchemaMap: any) => {
        acc[typeToAdaptivitySchemaMap.id] = typeToAdaptivitySchemaMap.adaptivitySchema;
        return acc;
      },
      {},
    );
    return Promise.resolve(adaptivityMap);
  }, [allParts, currentActivityTree, specificActivityTree]);

  const sessionVisits: Record<string, unknown>[] = [];
  const getSessionVisits = (sequence: any) => {
    sequence.forEach((sequenceItem: SequenceHierarchyItem<SequenceEntryChild>) => {
      if (!sequenceItem.custom.isBank && !sequenceItem.custom.isLayer) {
        sessionVisits.push({
          sequenceId: sequenceItem.custom.sequenceId,
          sequenceName: sequenceItem.custom.sequenceName,
        });
      }
      if (sequenceItem.children.length > 0) {
        getSessionVisits(sequenceItem.children);
      }
    });
    return [
      ...new Map(sessionVisits.map((uniqueBy) => [uniqueBy['sequenceId'], uniqueBy])).values(),
    ];
  };

  const SessionTemplate: React.FC = () => (
    <>
      {Object.keys(sessionVariables).map((variable: string, index: number) => {
        if (variable !== 'visits') {
          const limitedType = getLimitedTypeCheck(sessionVariables[variable]);
          // PMP-2039: if the context is mutate, we only want to show tutorialScore and currentQuestionScore
          if (context === 'mutate') {
            if (variable === 'tutorialScore' || variable === 'currentQuestionScore') {
              return (
                <div key={index} className="part-type">
                  <button
                    type="button"
                    className="text-btn font-italic"
                    onClick={() => {
                      setTargetRef(`session.${variable}`);
                      setTypeRef(`${limitedType}`);
                    }}
                    title={`${
                      CapiVariableTypes[limitedType][0] +
                      CapiVariableTypes[limitedType].slice(1).toLowerCase()
                    }`}
                  >
                    {variable}
                  </button>
                </div>
              );
            }
          } else {
            return (
              <div key={index} className="part-type">
                <button
                  type="button"
                  className="text-btn font-italic"
                  onClick={() => {
                    setTargetRef(`session.${variable}`);
                    setTypeRef(`${limitedType}`);
                  }}
                  title={`${
                    CapiVariableTypes[limitedType][0] +
                    CapiVariableTypes[limitedType].slice(1).toLowerCase()
                  }`}
                >
                  {variable}
                </button>
              </div>
            );
          }
        }
        if (variable === 'visits' && context !== 'mutate') {
          const sessionVisits = getSessionVisits(hierarchy);
          return (
            <Accordion>
              <Accordion.Toggle
                as={ListGroup.Item}
                eventKey={`${index}`}
                action
                className="part-type border-top"
                onClick={() => setIsFilterMenuOpen(false)}
              >
                <div className="d-flex align-items-center justify-space-between flex-grow-1">
                  <div className="d-flex flex-grow-1">
                    <span className="ml-1 text-btn font-weight-bold">{variable}</span>
                  </div>
                  <ContextAwareToggle eventKey={`${index}`} />
                </div>
              </Accordion.Toggle>
              <Accordion.Collapse eventKey={`${index}`}>
                <ul className="list-unstyled m-0 mb-2">
                  {sessionVisits.map((sequence: any, index: number) => (
                    <li
                      className="pb-2 pl-1 ml-3"
                      key={index}
                      onClick={() => {
                        setTargetRef(`session.visits.${sequence.sequenceId}`);
                        setTypeRef(`${CapiVariableTypes.NUMBER}`);
                      }}
                    >
                      <button type="button" className="text-btn font-italic">
                        <span title={`${sequence.sequenceId}`}>{sequence.sequenceName}</span>
                      </button>
                    </li>
                  ))}
                </ul>
              </Accordion.Collapse>
            </Accordion>
          );
        }
      })}
    </>
  );

  const VariableTemplate: React.FC = () =>
    currentLesson?.custom?.variables?.map((variable: LessonVariable, index: number) => {
      const { expression, name } = variable;
      const limitedType = getLimitedTypeCheck(expression);
      return (
        <div key={index} className="part-type">
          <button
            type="button"
            className="text-btn font-italic"
            onClick={() => {
              setTargetRef(`variables.${name}`);
              setTypeRef(`${limitedType}`);
            }}
            title={`${
              CapiVariableTypes[limitedType][0] +
              CapiVariableTypes[limitedType].slice(1).toLowerCase()
            }`}
          >
            {name}
          </button>
        </div>
      );
    });

  useEffect(() => {
    let isMounted = true;
    getAdaptivePartTypes().then((map) => {
      if (isMounted) {
        setPartAdaptivityMap(map);
      }
    });
    return () => {
      isMounted = false;
    };
  }, [allParts, currentActivityTree, specificActivityTree]);

  useEffect(() => {
    const someParts = (
      activeFilter.includes(FilterItems.SCREEN) ? currentActivityTree : specificActivityTree || []
    ).reduce((acc: any, activity: any) => acc.concat(activity.content.partsLayout || []), []);
    setAllParts(someParts);
  }, [currentActivityTree, specificActivityTree, activeFilter]);

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
                    className="variable-picker-dropdown d-flex align-items-center flex-grow-1"
                    onClick={() => setIsFilterMenuOpen(!isFilterMenuOpen)}
                  >
                    <span className="d-flex">{activeFilter}</span>
                  </Dropdown.Toggle>
                  <Dropdown.Menu
                    onClick={() => setIsFilterMenuOpen(!isFilterMenuOpen)}
                    show={isFilterMenuOpen}
                    rootCloseEvent="click"
                  >
                    <Dropdown.Item
                      active={activeFilter === FilterItems.SCREEN}
                      onClick={() => {
                        setActiveFilter(FilterItems.SCREEN);
                        setSpecificSequenceId('stage');
                      }}
                    >
                      {FilterItems.SCREEN}
                    </Dropdown.Item>
                    {context !== 'init' && (
                      <>
                        <Dropdown.Item
                          active={activeFilter === FilterItems.SESSION}
                          onClick={() => {
                            setActiveFilter(FilterItems.SESSION);
                            setSpecificSequenceId('session');
                          }}
                        >
                          {FilterItems.SESSION}
                        </Dropdown.Item>
                        {context !== 'mutate' && (
                          <>
                            <Dropdown.Item
                              active={activeFilter === FilterItems.VARIABLES}
                              onClick={() => {
                                setActiveFilter(FilterItems.VARIABLES);
                                setSpecificSequenceId('variables');
                              }}
                            >
                              {FilterItems.VARIABLES}
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
                          </>
                        )}
                      </>
                    )}
                  </Dropdown.Menu>
                </Dropdown>
              </div>
            </div>
            <div className="activity-tree">
              {activeFilter === FilterItems.SESSION && <SessionTemplate />}
              {activeFilter === FilterItems.VARIABLES && <VariableTemplate />}
              {activeFilter !== FilterItems.SESSION && activeFilter !== FilterItems.VARIABLES && (
                <Accordion>
                  {allParts.map((part: Record<string, string>, index: number) => (
                    <Fragment key={part.id}>{getPartTypeTemplate(part, index)}</Fragment>
                  ))}
                </Accordion>
              )}
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

const TreeView: React.FC<NestedStateDisplayProps> = ({
  state,
  rootLevel,
  onClick,
  currentTarget,
  currentState,
}) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const hasChildren = hasNesting(state[rootLevel]);
  return (
    <li className={`${hasChildren ? 'pb-2 pl-1 ml-4' : 'pb-0 pt-2 pl-1 ml-4'}`}>
      <div
        onClick={() => {
          setIsExpanded(!isExpanded);
          if (onClick && !hasChildren) {
            const variableType = currentState[rootLevel];
            onClick(currentTarget, variableType);
          }
        }}
        style={{ cursor: 'pointer' }}
      >
        {rootLevel}
        {hasChildren ? (
          isExpanded ? (
            <button type="button" className="btn btn-link  pr-1 pt-0 pb-0 mr-1">
              <i className="fa fa-angle-down"></i>
            </button>
          ) : (
            <button type="button" className="btn btn-link  pr-1 pt-0 pb-0 mr-1">
              <i className="fa fa-angle-right"></i>
            </button>
          )
        ) : (
          ''
        )}{' '}
      </div>
      {hasChildren && isExpanded && (
        <div>
          {Object.keys(state[rootLevel]).map((level2: any) => (
            <TreeView
              key={level2}
              state={{ [level2]: { ...state[rootLevel][level2] } }}
              rootLevel={level2}
              onClick={onClick}
              currentTarget={`${currentTarget}.${level2}`}
              currentState={state[rootLevel]}
            />
          ))}
        </div>
      )}
    </li>
  );
};
