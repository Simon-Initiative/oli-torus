import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { SpokeItems } from './HubSpoke';
import { hubSpokeModel } from './schema';

const HubSpokeAuthor: React.FC<AuthorPartComponentProps<hubSpokeModel>> = (props) => {
  const { id, model } = props;
  const {
    width,
    spokeItems,
    verticalGap,
    customCssClass,
    layoutType,
    overrideHeight = false,
    showProgressBar,
  } = model;
  const styles: CSSProperties = {
    width,
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const options: any[] = spokeItems?.map((item: any, index: number) => ({
    ...item,
    index: index,
    value: index + 1,
  }));

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
      {
        <div data-janus-type={tagName} style={styles} className={`hub-spoke spoke-${layoutType}`}>
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
                padding: 10px 20px;
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
          {options?.map((item, index) => (
            <SpokeItems
              index={index}
              key={`${id}-item-${index}`}
              totalItems={options.length}
              layoutType={layoutType}
              itemId={`${id}-item-${index}`}
              val={item.value}
              {...item}
              x={0}
              y={0}
              verticalGap={verticalGap}
              overrideHeight={overrideHeight}
              disabled={false}
              columns={columns}
            />
          ))}
          {showProgressBar && (
            <div className="space-y-5 progress-bar" style={{ width: '96%' }}>
              <div>
                <div className="mb-2 flex justify-between items-center">
                  <h3 className="text-sm font-semibold text-gray-800 dark:text-white">Progress</h3>
                  <span className="text-sm text-gray-800 dark:text-white">
                    <b>0/{options?.length}</b>
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
      }
    </React.Fragment>
  );
};
export const tagName = 'janus-hub-spoke';

export default HubSpokeAuthor;
