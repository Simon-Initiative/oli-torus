/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { sanitizeRichLabelHtml } from 'utils/richOptionLabel';
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
      {showHeaderFooter && (
        <div
          className="list-sort__header janus-rich-label"
          dangerouslySetInnerHTML={{ __html: sanitizeRichLabelHtml(headerLabel) }}
        />
      )}
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
              <span
                className="list-sort__text-label janus-rich-label"
                dangerouslySetInnerHTML={{ __html: sanitizeRichLabelHtml(item.text) }}
              />
            </div>
          </div>
        ))}
      </div>
      {showHeaderFooter && (
        <div
          className="list-sort__footer janus-rich-label"
          dangerouslySetInnerHTML={{ __html: sanitizeRichLabelHtml(footerLabel) }}
        />
      )}
    </div>
  );
};

export const tagName = 'janus-list-sort';

export default ListSortAuthor;
