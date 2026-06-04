/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { ListSortHandleIcon } from './ListSort';
import './ListSort.scss';
import { ListSortModel } from './schema';

const ListSortAuthor: React.FC<AuthorPartComponentProps<ListSortModel>> = (props) => {
  const { model } = props;

  const {
    listItems = [],
    showHeaderFooter = true,
    headerLabel = 'First',
    footerLabel = 'Last',
    barColor = '#0070F3',
  } = model;

  useEffect(() => {
    // all parts *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  // listItems are stored in the author-defined correct order
  const orderedItems = listItems;

  const containerStyle: CSSProperties = {
    width: '100%',
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
        {orderedItems.map((item) => (
          <div key={item.id} className="list-sort__item" role="listitem">
            <span className="list-sort__bar" aria-hidden="true" />
            <span className="list-sort__handle" aria-hidden="true">
              <ListSortHandleIcon />
            </span>
            <span className="list-sort__text">{item.text}</span>
          </div>
        ))}
      </div>
      {showHeaderFooter && <div className="list-sort__footer">{footerLabel}</div>}
    </div>
  );
};

export const tagName = 'janus-list-sort';

export default ListSortAuthor;
