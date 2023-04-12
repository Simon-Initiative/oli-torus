import styles from './PaginationControls.modules.scss';
import { PaginationMode } from 'data/content/resource';
import * as Events from 'data/events';
import { updatePaginationState } from 'data/persistence/pagination';
import { List } from 'immutable';
import React, { useEffect, useRef, useState } from 'react';
import { classNames } from 'utils/classNames';

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
          {pages.map((p, i) => (
            <li key={i} className={classNames('page-item', i == active ? 'active' : '')}>
              <button className="page-link" onClick={() => onSelectPage(i)}>
                {i + 1}
              </button>
            </li>
          ))}
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
