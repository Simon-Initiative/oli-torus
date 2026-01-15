import React, { useEffect, useRef, useState } from 'react';
import { List } from 'immutable';
import { PaginationMode } from 'data/content/resource';
import * as Events from 'data/events';
import { updatePaginationState } from 'data/persistence/pagination';
import { MediaSize, useMediaQuery } from 'hooks/media_query';
import { classNames } from 'utils/classNames';
import styles from './PaginationControls.modules.scss';

export interface PaginationControlsProps {
  forId: string;
  paginationMode: PaginationMode;
  sectionSlug: string;
  pageAttemptGuid: string;
  initiallyVisible: number[];
}

type Page = List<Element>;

export const PaginationControls = (props: PaginationControlsProps) => {
  const controls = useRef<HTMLDivElement>(null);
  const [pages, setPages] = useState(List<Page>());
  const [active, setActive] = useState(0);
  const isAtLeastSmall = useMediaQuery(MediaSize.sm);
  const isMobile = !isAtLeastSmall;

  const hideAll = () => {
    pages.forEach((page) => page.forEach((el) => el.classList.remove(styles.show)));
  };

  const show = (pageIndex: number) => {
    pages.get(pageIndex)?.forEach((el) => el.classList.add(styles.show));
  };

  useEffect(() => {
    document.addEventListener(Events.Registry.ShowContentPage, (e) => {
      // check if this activity belongs to the survey being reset
      if (e.detail.forId === props.forId) {
        onSelectPage(e.detail.index);
      }
    });
  }, []);

  useEffect(() => {
    const parentElement = controls?.current?.parentElement?.parentElement;

    if (parentElement) {
      const children = parentElement.querySelector('.elements')?.children;

      if (children) {
        let pages = List<Page>();
        for (let i = 0; i < children.length; i++) {
          if (children[i].classList.contains('content-break')) {
            pages = pages.push(List<Element>());
          } else {
            pages = pages.update(pages.count() - 1, List<Element>(), (elements) =>
              elements.push(children[i]),
            );
          }
        }

        // Set the visibility of our initial state
        props.initiallyVisible.forEach((index) => {
          pages.get(index)?.forEach((el) => el.classList.add(styles.show));
        });
        const maxItem = props.initiallyVisible.reduce((p, c) => {
          if (p > c) {
            return p;
          }
          return c;
        }, 0);
        setActive(maxItem);
        setPages(pages);
      }
    }
  }, [controls]);

  useEffect(() => {
    if (props.paginationMode === 'normal') {
      hideAll();
    }
    show(active);
  }, [pages, active]);

  const onSelectPage = (pageIndex: number) => {
    setActive(Math.max(0, pageIndex));
  };

  const previousDisabled = active === 0;
  const nextDisabled = active === pages.count() - 1;
  const totalPages = pages.count();
  const shouldCondense = isMobile && totalPages > 5;
  const displayItems = (() => {
    if (!shouldCondense) {
      return Array.from({ length: totalPages }, (_, index) => ({
        type: 'page' as const,
        index,
        key: `page-${index}`,
      }));
    }

    const items: Array<{ type: 'page' | 'ellipsis'; index?: number; key: string }> = [];
    const baseSet = new Set<number>([0, totalPages - 1, active]);
    const countItems = (set: Set<number>) => {
      const ordered = Array.from(set).sort((a, b) => a - b);
      let gaps = 0;
      for (let i = 0; i < ordered.length - 1; i++) {
        if (ordered[i + 1] > ordered[i] + 1) {
          gaps += 1;
        }
      }
      return ordered.length + gaps;
    };

    const addNeighborIfFits = (index: number) => {
      if (index < 0 || index > totalPages - 1 || baseSet.has(index)) {
        return;
      }
      const nextSet = new Set(baseSet);
      nextSet.add(index);
      if (countItems(nextSet) <= 5) {
        baseSet.add(index);
      }
    };

    addNeighborIfFits(active - 1);
    addNeighborIfFits(active + 1);

    const orderedPages = Array.from(baseSet).sort((a, b) => a - b);
    for (let i = 0; i < orderedPages.length; i++) {
      const index = orderedPages[i];
      items.push({ type: 'page', index, key: `page-${index}` });

      const nextIndex = orderedPages[i + 1];
      if (nextIndex !== undefined && nextIndex > index + 1) {
        items.push({ type: 'ellipsis', key: `ellipsis-${index}-${nextIndex}` });
      }
    }

    return items;
  })();

  return (
    <>
      <div className="d-flex justify-content-center">
        {props.paginationMode === 'manualReveal' && active !== pages.toArray().length - 1 ? (
          <button
            className="btn btn-primary"
            onClick={() => {
              onSelectPage(active + 1);
              updatePaginationState(props.sectionSlug, props.pageAttemptGuid, props.forId, [
                active + 1,
              ]);
            }}
          >
            Next
          </button>
        ) : null}
      </div>
      <div className={styles.paginationControls} ref={controls}>
        <div className="flex-grow-1"></div>
        <ul
          className="pagination"
          style={{ visibility: props.paginationMode !== 'normal' ? 'hidden' : 'visible' }}
        >
          <li className={classNames('page-item', previousDisabled ? 'disabled' : '')}>
            <button
              className="page-link"
              onClick={() => onSelectPage(active - 1)}
              disabled={previousDisabled}
            >
              Previous
            </button>
          </li>
          {displayItems.map((item) => {
            if (item.type === 'ellipsis') {
              return (
                <li key={item.key} className={classNames('page-item', 'disabled')}>
                  <span className="page-link" aria-label="More pages">
                    ...
                  </span>
                </li>
              );
            }

            const pageIndex = item.index ?? 0;
            return (
              <li
                key={item.key}
                className={classNames('page-item', pageIndex == active ? 'active' : '')}
              >
                <button
                  className="page-link"
                  onClick={() => onSelectPage(pageIndex)}
                  aria-current={pageIndex === active ? 'page' : undefined}
                >
                  {pageIndex + 1}
                </button>
              </li>
            );
          })}
          <li className={classNames('page-item', nextDisabled ? 'disabled' : '')}>
            <button
              className="page-link"
              onClick={() => {
                onSelectPage(active + 1);
              }}
              disabled={nextDisabled}
            >
              Next
            </button>
          </li>
        </ul>
        <div className="flex-grow-1"></div>
      </div>
    </>
  );
};
