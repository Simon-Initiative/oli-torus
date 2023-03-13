import * as React from 'react';

function range(start: number, stop: number, step = 1) {
  const a = [start];
  let b = start;
  while (b < stop) {
    a.push((b += step || 1));
  }
  return a;
}

export interface Page {
  offset: number;
  limit: number;
}

export interface PagingProps {
  totalResults: number;
  page: Page;
  onPageChange: (page: Page) => void;
  children?: (item: any, index: number) => React.ReactNode;
}

// Implements pagination, with a maximum of nine directly navigable
// page buttons and "previous" and "next" buttons, with the current page
// highlighted
//
// Previous 1 2 3 4 5 6 7 8 9 Next
//              ^
export const Paging: React.FC<PagingProps> = (props: PagingProps) => {
  const { totalResults, page, onPageChange } = props;
  const lastPageIndex = Math.ceil(totalResults / page.limit) - 1;
  const currentPage = page.offset / page.limit;
  const upper = Math.min(page.offset + page.limit, totalResults);

  const firstPage = { offset: 0, limit: page.limit };
  const previousPage = { offset: page.offset - page.limit, limit: page.limit };
  const nextPage = { offset: page.offset + page.limit, limit: page.limit };
  const lastPage = { offset: lastPageIndex * page.limit, limit: page.limit };

  const start = Math.max(currentPage - 4, 0);
  const end = Math.min(currentPage + 4, lastPageIndex);

  const pages = range(start, end).map((i) => (
    <li key={i} className={`page-item ${i === currentPage ? 'active' : ''}`}>
      <button
        className="page-link"
        onClick={() => onPageChange({ offset: i * page.limit, limit: page.limit })}
      >
        {i + 1}
      </button>
    </li>
  ));

  return (
    <div className="d-flex justify-content-between">
      <div>
        Showing result {page.offset + 1} - {upper} of {totalResults} total
      </div>
      <nav aria-label="Activity Bank Paging">
        <ul className="pagination">
          <li className={`page-item ${currentPage === 0 ? 'disabled' : ''}`}>
            <button
              className="page-link"
              onClick={() => currentPage > 0 && onPageChange(firstPage)}
            >
              <i className="fas fa-angle-double-left"></i>
            </button>
          </li>
          <li className={`page-item ${currentPage === 0 ? 'disabled' : ''}`}>
            <button
              className="page-link"
              onClick={() => currentPage > 0 && onPageChange(previousPage)}
            >
              <i className="fas fa-angle-left"></i>
            </button>
          </li>
          {pages}
          <li className={`page-item ${currentPage === lastPageIndex ? 'disabled' : ''}`}>
            <button
              className="page-link"
              onClick={() => currentPage < lastPageIndex && onPageChange(nextPage)}
            >
              <i className="fas fa-angle-right"></i>
            </button>
          </li>
          <li className={`page-item ${currentPage === lastPageIndex ? 'disabled' : ''}`}>
            <button
              className="page-link"
              onClick={() => currentPage < lastPageIndex && onPageChange(lastPage)}
            >
              <i className="fas fa-angle-double-right"></i>
            </button>
          </li>
        </ul>
      </nav>
    </div>
  );
};
