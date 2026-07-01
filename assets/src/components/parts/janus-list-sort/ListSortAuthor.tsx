/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import './ListSort.scss';
import { itemBarStyle } from './list-sort-util';
import { DEFAULT_LIST_SORT_BAR_COLOR, ListSortModel } from './schema';

const ListSortAuthor: React.FC<AuthorPartComponentProps<ListSortModel>> = (props) => {
  const { model } = props;

  const {
    width,
    height,
    listItems = [],
    showHeaderFooter = true,
    headerLabel = 'First',
    footerLabel = 'Last',
    barColor = DEFAULT_LIST_SORT_BAR_COLOR,
  } = model;

  useEffect(() => {
    props.onReady({ id: `${props.id}` });
  }, []);

  const containerStyle: CSSProperties = {
    width: width ?? '100%',
    ...(height != null ? { height, minHeight: height } : {}),
    ['--list-sort-bar-color' as any]: barColor,
  };

  return (
    <div
      data-janus-type={tagName}
      className="list-sort list-sort--authoring"
      style={containerStyle}
    >
      {showHeaderFooter && <div className="list-sort__header">{headerLabel}</div>}
      <div className="list-sort__items" role="list">
        {listItems.map((item, index) => (
          <div
            key={item.id}
            className="list-sort__item"
            role="listitem"
            style={itemBarStyle(barColor, index, listItems.length)}
          >
            <span className="list-sort__bar" aria-hidden="true" />
            <div className="list-sort__text">
              <span className="list-sort__text-label">{item.text}</span>
            </div>
          </div>
        ))}
      </div>
      {showHeaderFooter && <div className="list-sort__footer">{footerLabel}</div>}
    </div>
  );
};

export const tagName = 'janus-list-sort';

export default ListSortAuthor;
