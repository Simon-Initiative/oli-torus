/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import { Item, JanusHubSpokeItemProperties, hubSpokeModel } from './schema';

const SpokeItemContentComponent: React.FC<any> = ({ nodes }) => {
  return nodes;
};

const SpokeItemContent = React.memo(SpokeItemContentComponent);

export const SpokeItems: React.FC<JanusHubSpokeItemProperties> = ({
  nodes,
  state,
  itemId,
  layoutType,
  totalItems,
  idx,
  overrideHeight,
  columns = 1,
  index,
  verticalGap = 0,
  onSelected,
  val,
  IsCompleted,
}) => {
  const spokeItemStyles: CSSProperties = {};
  if (layoutType === 'horizontalLayout') {
    if (columns === 1) {
      spokeItemStyles.width = `calc(${Math.floor(100 / totalItems)}% - 6px)`;
    } else {
      spokeItemStyles.width = `calc(100% / ${columns} - 6px)`;
    }
    if (idx !== 0) {
      spokeItemStyles.left = `calc(${(100 / totalItems) * idx}% - 6px)`;
    }
    spokeItemStyles.position = `absolute`;

    spokeItemStyles.display = `inline-block`;
  }
  if (layoutType === 'verticalLayout' && overrideHeight) {
    spokeItemStyles.height = `calc(${100 / totalItems}%)`;
  }
  if (layoutType === 'verticalLayout' && verticalGap && index > 0) {
    spokeItemStyles.marginTop = `${verticalGap}px`;
  }
  return (
    <React.Fragment>
      <div style={spokeItemStyles} className={` hub-spoke-item`}>
        <button
          type="button"
          style={{ width: '100%' }}
          onClick={() => {
            if (onSelected) onSelected(val);
          }}
          className="btn btn-primary"
        >
          {IsCompleted && (
            <span style={{ float: 'left', paddingLeft: '10px' }} className={'fa fa-check-circle'}>
              &nbsp;
            </span>
          )}
          <SpokeItemContent itemId={itemId} nodes={nodes} state={state} />
        </button>
      </div>
      {layoutType !== 'horizontalLayout' && <br style={{ padding: '0px' }} />}
    </React.Fragment>
  );
};

interface SpokeOptionModel extends Item {
  index: number;
  value: number;
}

const HubSpoke: React.FC<PartComponentProps<hubSpokeModel>> = (props) => {
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id = props.id;
  const [enabled, setEnabled] = useState(true);
  const [options, setOptions] = useState<SpokeOptionModel[]>([]);
  const [completedSpokeCount, setCompletedSpokeCount] = useState<number>(0);
  const initialize = useCallback(async (pModel) => {
    // set defaults from model
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    // now we need to save the defaults used in adaptivity (not necessarily the same)
    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'selectedSpoke',
          type: CapiVariableTypes.NUMBER,
          value: -1,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;

    // we need to set up a new list so that we can shuffle while maintaining correct index/values
    const spokeItems: SpokeOptionModel[] = pModel.spokeItems?.map((item: any, index: number) => ({
      ...item,
      index: index + 1,
      value: index + 1,
    }));

    spokeItems.forEach((spoke: any) => {
      spoke.IsCompleted = !!currentStateSnapshot[`session.visits.${spoke.destinationActivityId}`];
    });

    setOptions(spokeItems);
    const spokeCount = spokeItems.filter((spoke) => spoke.IsCompleted) ?? 0;
    setCompletedSpokeCount(spokeCount?.length || 0);
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: 'spokeCompleted',
          type: CapiVariableTypes.NUMBER,
          value: spokeCount?.length || 0,
        },
      ],
    });

    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(sEnabled);
    }

    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady(true);
  }, []);

  const {
    width,
    customCssClass,
    layoutType,
    height,
    showProgressBar,
    overrideHeight = false,
    verticalGap,
  } = model;

  useEffect(() => {
    let pModel;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }
    initialize(pModel);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const handleButtonPress = (val: any) => {
    props.onSubmit({
      id: `${id}`,
      responses: [
        {
          key: 'selectedSpoke',
          type: CapiVariableTypes.NUMBER,
          value: val,
        },
      ],
    });
  };
  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [MCQ]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // should disable input during check?
            break;
          case NotificationType.CHECK_COMPLETE:
            // if disabled above then re-enable now
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              console.log({ changes });
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              if (payload.mode === contexts.REVIEW) {
                setEnabled(false);
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify, options, handleButtonPress]);

  // Set up the styles
  const styles: CSSProperties = {
    /* position: 'absolute',
    top: y,
    left: x,
    width,
    zIndex: z, */
    width,
  };
  if (overrideHeight) {
    styles.height = height;
    styles.marginTop = '8px';
  }

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }

    props.onResize({ id: `${id}`, settings: styleChanges });
  }, [width, height]);

  let columns = 1;
  if (customCssClass === 'two-columns') {
    columns = 2;
  }
  if (customCssClass === 'three-columns') {
    columns = 3;
  }
  if (customCssClass === 'four-columns') {
    columns = 4;
  }

  return (
    <React.Fragment>
      {ready ? (
        <>
          <style>
            {`

              .spoke-horizontalLayout .hub-spoke-item {
                box-sizing: border-box;
                margin-left: 0px;
                margin-right: 6px;
              }
              .spoke-horizontalLayout .progress-bar {
                width: 25% !important;
                margin-left: auto;
                margin-right: 8px !important;
              }
              .spoke-horizontalLayout {
                box-sizing: border-box;
                margin-left: 0px;
                margin-right: 0px;
              }
              .hub-spoke button {
                color: white !important;
                min-width: 100px;
                height: auto !important;
                min-height: 44px;
                background-color: #006586;
                border-radius: 3px;
                border: none;
                padding: 0px 0px 0px 0px;
                cursor: pointer;
              }
              .hub-spoke {
                border: none !important;
                padding: 0px;

                > div {
                  display: block;
                  position: static !important;
                  margin: 0 9px 15px 0;
                  min-height: 20px;
                }
                > div:last-of-type {
                  margin-right: 0;
                }
                p {
                  margin: 0px;
                }
                > br {
                  display: none !important;
                }
              }
        `}
          </style>
          <div data-janus-type={tagName} style={styles} className={`hub-spoke spoke-${layoutType}`}>
            {options?.map((item, index) => (
              <SpokeItems
                idx={index}
                key={`${id}-item-${index}`}
                title={item.title}
                totalItems={options.length}
                layoutType={layoutType}
                itemId={`${id}-item-${index}`}
                groupId={`mcq-${id}`}
                val={item.value}
                onSelected={handleButtonPress}
                {...item}
                x={0}
                y={0}
                overrideHeight={overrideHeight}
                disabled={!enabled}
                columns={columns}
                verticalGap={verticalGap}
              />
            ))}
            {showProgressBar && (
              <div className="space-y-5 progress-bar" style={{ width: '96%' }}>
                <div>
                  <div className="mb-2 flex justify-between items-center">
                    <h3 className="text-sm font-semibold text-gray-800 dark:text-white">
                      Progress
                    </h3>
                    <span className="text-sm text-gray-800 dark:text-white">
                      <b>
                        {completedSpokeCount}/{options?.length}
                      </b>
                    </span>
                  </div>
                  <div
                    className="flex w-full h-2 bg-gray-200 rounded-full overflow-hidden dark:bg-neutral-700"
                    role="progressbar"
                  >
                    <div
                      className="flex flex-col justify-center rounded-full overflow-hidden bg-body-dark-600 text-xs text-white text-center whitespace-nowrap transition duration-500 dark:bg-blue-500"
                      style={{ width: '25%' }}
                    ></div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </>
      ) : null}
    </React.Fragment>
  );
};

export const tagName = 'janus-hub-spoke';

export default HubSpoke;
