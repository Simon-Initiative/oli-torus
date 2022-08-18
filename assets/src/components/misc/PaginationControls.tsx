import React, { useEffect, useState, useRef } from 'react';
import { List } from 'immutable';
import styles from './PaginationControls.modules.scss';
import { classNames } from 'utils/classNames';
import * as Events from 'data/events';

export interface PaginationControlsProps {
  forId: string;
  hideControls?: boolean;
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

        setPages(pages);
      }
    }
  }, [controls]);

  useEffect(() => {
    hideAll();
    show(active);
  }, [pages, active]);

  const onSelectPage = (pageIndex: number) => {
    setActive(Math.min(pages.count() - 1, Math.max(0, pageIndex)));
  };

  const previousDisabled = active === 0;
  const nextDisabled = active === pages.count() - 1;

  return (
    <div className={styles.paginationControls} ref={controls}>
      <div className="flex-grow-1"></div>
      <ul className="pagination" style={{ display: props.hideControls ? 'none' : 'inline-block' }}>
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
            onClick={() => onSelectPage(active + 1)}
            disabled={nextDisabled}
          >
            Next
          </button>
        </li>
      </ul>
      <div className="flex-grow-1"></div>
    </div>
  );
};
