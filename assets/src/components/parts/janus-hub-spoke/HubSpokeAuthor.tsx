import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { SpokeItems } from './HubSpoke';
import './hubSpoke.scss';
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

  useEffect(() => {
    props.onReady({ id: `${props.id}` });
  }, []);

  const styles: CSSProperties = { width };

  const options = spokeItems?.map((item, index) => ({
    ...item,
    index,
    value: index + 1,
  }));

  const columnsMap: Record<string, number> = {
    'two-columns': 2,
    'three-columns': 3,
    'four-columns': 4,
  };

  const columns = customCssClass ? columnsMap[customCssClass] || 1 : 1;

  return (
    <>
      <div data-janus-type={tagName} style={styles} className={`hub-spoke spoke-${layoutType}`}>
        {layoutType === 'horizontalLayout' ? (
          <div className="spoke-items-row">
            {options.map((item, index) => (
              <SpokeItems
                key={`${id}-item-${index}`}
                totalItems={options.length}
                layoutType={layoutType}
                itemId={`${id}-item-${index}`}
                val={item.value}
                {...item}
                verticalGap={verticalGap}
                overrideHeight={overrideHeight}
                columns={columns}
              />
            ))}
          </div>
        ) : (
          options.map((item, index) => (
            <SpokeItems
              key={`${id}-item-${index}`}
              totalItems={options.length}
              layoutType={layoutType}
              itemId={`${id}-item-${index}`}
              val={item.value}
              {...item}
              verticalGap={verticalGap}
              overrideHeight={overrideHeight}
              columns={columns}
            />
          ))
        )}

        {showProgressBar && (
          <div className="space-y-5 progress-bar" style={{ width: '96%' }}>
            <div>
              <div className="mb-2 flex justify-between items-center">
                <h3 className="text-sm font-semibold text-gray-800 dark:text-white">Progress</h3>
                <span className="text-sm text-gray-800 dark:text-white">
                  <b>0/{options.length}</b>
                </span>
              </div>
              <div className="flex w-full h-2 bg-gray-200 rounded-full overflow-hidden dark:bg-neutral-700">
                <div
                  className="flex flex-col justify-center rounded-full overflow-hidden bg-body-dark-600 text-xs text-white text-center whitespace-nowrap transition duration-500 dark:bg-blue-500"
                  style={{ width: '25%' }}
                />
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
};

export const tagName = 'janus-hub-spoke';

export default HubSpokeAuthor;
