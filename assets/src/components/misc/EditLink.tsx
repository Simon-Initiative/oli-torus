import React from 'react';

export type EditLinkProps = {
  href: string,
  label: string,
};

export const EditLink = (props: EditLinkProps) => (
  <a
    href={props.href}
    className="btn btn-sm btn-primary btn-outline mx-2"
    aria-label="edit">
    <i className="fa fa-pencil-alt" aria-hidden="true"></i> {props.label}
  </a>
);
