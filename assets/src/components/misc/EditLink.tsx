import React from 'react';

export type EditLinkProps = {
  href: string,
};

export const EditLink = (props: EditLinkProps) => (
  <a
    href={props.href}
    className="btn btn-sm btn-link mx-2"
    aria-label="edit">
    <i className="fa fa-pencil-alt" aria-hidden="true"></i> Edit
  </a>
);
