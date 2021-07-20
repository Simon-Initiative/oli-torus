import * as React from 'react';
import * as Bank from 'data/content/bank';

export interface PagingProps {
  totalResults: number;
  page: Bank.Paging;
  onPageChange: (page: Bank.Paging) => void;
  children?: (item: any, index: number) => React.ReactNode;
}

// https://getbootstrap.com/docs/4.0/components/pagination/
//
// Implements Bootrap pagination, with a maximum of nine directly navigable
// page buttons and "previous" and "next" buttons, with the current page
// highlighted
//
// Previous 1 2 3 4 5 6 7 8 9 Next
//              ^
export const Paging: React.FC<PagingProps> = (props: PagingProps) => {
  const { totalResults, page, onPageChange } = props;
  const lastPageIndex = Math.ceil(totalResults / page.limit) - 1;
  const renderedPages = Math.min(lastPageIndex + 1, 9);
  const pages = [];
  const currentPage = page.offset / page.limit;

  let start: number;
  // Handle cases where we have less than nine pages of results
  if (lastPageIndex <= 9) {
    start = 0;
    // Will render like:
    //
    // Previous 1 2 3 Next
    //          ^
    //        current
  } else if (lastPageIndex - currentPage < 4) {
    // We have more than nine total pages of results, but not enough pages
    // that we can simply 'center' current page, so we right align the
    // current page as far as we can
    //
    // Previous 3 4 5 6 7 8 9 10 11 Next
    //                        ^
    //                      current
    start = 8 - (lastPageIndex - currentPage);
  } else {
    // We have more than enough pages to allow us to just 'center'
    // the current page, placing four pages to the left and four
    // to the right of it.
    //
    // Will render like:
    //
    // Previous 3 4 5 6 7 8 9 10 11 Next
    //                  ^
    //                current
    start = currentPage - 4;
  }

  for (let i = 0; i < renderedPages; i++) {
    pages.push(
      <li className={`page-item ${start + i === currentPage ? 'active' : ''}`}>
        <a
          className="page-link"
          onClick={() => onPageChange({ offset: (start + i) * page.limit, limit: page.limit })}
        >
          {i + 1}
        </a>
      </li>,
    );
  }

  const previousPage = { offset: page.offset - page.limit, limit: page.limit };
  const nextPage = { offset: page.offset + page.limit, limit: page.limit };

  return (
    <nav aria-label="Activity Bank Paging">
      <ul className="pagination">
        <li className={`page-item ${currentPage === 0 ? 'disabled' : ''}`}>
          <a className="page-link" onClick={() => onPageChange(previousPage)}>
            Previous
          </a>
        </li>
        {pages}
        <li className={`page-item ${currentPage === lastPageIndex ? 'disabled' : ''}`}>
          <a className="page-link" onClick={() => onPageChange(nextPage)}>
            Next
          </a>
        </li>
      </ul>
    </nav>
  );
};
