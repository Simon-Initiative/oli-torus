import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  categoryTitle,
  groupingContainerStyles,
  groupingLayoutClass,
  groupingThemeStyles,
  itemDisplayText,
} from './grouping-util';
import { GroupingModel } from './schema';
import './Grouping.scss';

const GroupingAuthor: React.FC<AuthorPartComponentProps<GroupingModel>> = (props) => {
  const { id, model } = props;

  useEffect(() => {
    props.onReady({ id: `${id}` });
  }, []);

  const categories = model.categories || [];
  const items = model.items || [];

  const styles: CSSProperties = {
    ...groupingContainerStyles(model.width, model.height),
    ...groupingThemeStyles(model.themeColor),
  };

  return (
    <div
      data-janus-type={tagName}
      className={`grouping grouping-author ${groupingLayoutClass(model.width)}`}
      style={styles}
    >
      <div className="grouping-columns">
        <section className="grouping-column grouping-column-bank">
          <header className="grouping-column-header">Item Bank</header>
          <div className="grouping-dropzone grouping-dropzone-bank">
            {items.length === 0 && (
              <div className="grouping-empty-hint">
                <span>Use Manage Item Bank in the property panel to add items</span>
              </div>
            )}
            {items.map((item) => (
              <div key={item.id} className={`grouping-item grouping-item-${item.type}`}>
                {item.type === 'image' && item.imageSrc ? (
                  <>
                    <img
                      className="grouping-item-thumb"
                      src={item.imageSrc}
                      alt={item.alt || item.label}
                    />
                    <span className="grouping-item-label">{itemDisplayText(item)}</span>
                  </>
                ) : (
                  <span className="grouping-item-label">{itemDisplayText(item)}</span>
                )}
              </div>
            ))}
          </div>
        </section>
        {categories.map((category, index) => (
          <section key={category.id} className="grouping-column">
            <header className="grouping-column-header">{categoryTitle(category, index)}</header>
            <div className="grouping-dropzone">
              <div className="grouping-empty-hint">
                <span>No items in this category</span>
              </div>
            </div>
          </section>
        ))}
      </div>
    </div>
  );
};

export const tagName = 'janus-item-bank';

export default GroupingAuthor;
