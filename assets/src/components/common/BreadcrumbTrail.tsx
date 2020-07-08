import React from 'react';

import { ProjectSlug } from 'data/types';

export type BreadcrumbResource = {
  slug: string,
  title: string,
};

export interface BreadcrumbTrailProps {
  projectSlug: ProjectSlug;
  page: BreadcrumbResource;
  activity?: BreadcrumbResource;
}

const curriculumPath = (projectSlug: string) => `/project/${projectSlug}/curriculum`;
const pagePath = (projectSlug: string, pageSlug: string) => `/project/${projectSlug}/resource/${pageSlug}`;
const link = (label: string, path: string) => <a href={path}>{label}</a>;

export const BreadcrumbTrail = (props: BreadcrumbTrailProps) => {

  let pageActivityLinks = null;

  if (props.activity === undefined) {
    pageActivityLinks = [
      <li key="page" className="breadcrumb-item active" aria-current="page">{props.page.title}</li>,
    ];
  } else {
    pageActivityLinks = [
      <li key="page" className="breadcrumb-item">
        {link(props.page.title, pagePath(props.projectSlug, props.page.slug))}
      </li>,
      <li key="activity" className="breadcrumb-item active" aria-current="page">
        {props.activity.title}
        </li>,
    ];
  }

  return (
    <nav aria-label="breadcrumb">
      <ol className="breadcrumb">
        <li key="project" className="breadcrumb-item">
          {link('Curriculum', curriculumPath(props.projectSlug))}
        </li>
        {pageActivityLinks}
      </ol>
    </nav>
  );

};
