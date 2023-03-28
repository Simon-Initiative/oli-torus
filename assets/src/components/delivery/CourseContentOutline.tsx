import React, { useEffect } from 'react';
import { classNames } from 'utils/classNames';

type MaybeSlug = string | null;

interface CourseContentOutlineProps {
  sectionSlug: MaybeSlug;
  projectSlug: MaybeSlug;
  hierarchy: any;
}

export const CourseContentOutline = ({ sectionSlug, projectSlug, hierarchy }: CourseContentOutlineProps) => {
  const items = flatten({ ...hierarchy, type: 'root' }, sectionSlug, projectSlug);
  const active = items.find((i: FlattenedItem) => i.isActive);
  const activeContainerSlug = active?.containerSlug;

  useEffect(() => {
    // ensure the active item is scrolled into view when the course outline is initially rendered
    if (active) {
      const element = document.querySelector(`#outline-item-${active.slug}`);

      if (element) {
        element.scrollIntoView();
      }
    }
  }, []);

  return (
    <div className="lg:w-[400px]">
      <div className="hidden lg:block p-4 font-bold">Course Content</div>
      <div>
        {items.map((pageItemProps) => (
          <PageItem
            key={pageItemProps.id}
            {...pageItemProps}
            sectionSlug={sectionSlug}
            projectSlug={projectSlug}
            activeContainerSlug={activeContainerSlug}
          />
        ))}
      </div>
    </div>
  );
};

type FlattenedItem = {
  type: 'page' | 'container';
  title: string;
  id: string;
  slug: string;
  level: number;
  containerSlug: string | undefined;
  isActive: boolean;
};

const flatten = (
  item: HierarchyItem | Root,
  sectionSlug: MaybeSlug,
  projectSlug: MaybeSlug,
  containerSlug?: string | undefined,
  level = 0,
): FlattenedItem[] =>
  item.type === 'root'
    ? item.children.reduce(
        (acc, c) => [...acc, ...flatten(c, sectionSlug, projectSlug, containerSlug, level + 1)],
        [],
      )
    : item.type === 'container'
    ? [
        {
          id: item.id,
          type: item.type,
          title: item.title,
          slug: item.slug,
          level,
          containerSlug: item.slug,
          isActive: isCurrentUrl(sectionSlug, projectSlug, item.type, item.slug),
        },
        ...item.children.reduce(
          (acc: FlattenedItem[], c: HierarchyItem) => [
            ...acc,
            ...flatten(c, sectionSlug, projectSlug, item.slug, level + 1),
          ],
          [],
        ),
      ]
    : [
        {
          id: item.id,
          type: item.type,
          title: item.title,
          slug: item.slug,
          level,
          containerSlug,
          isActive: isCurrentUrl(sectionSlug, projectSlug, item.type, item.slug),
        },
      ];

interface Root {
  type: 'root';
  children: HierarchyItem[];
}

interface Container {
  type: 'container';
  children: HierarchyItem[];
  title: string;
  id: string;
  slug: string;
}

interface Page {
  type: 'page';
  title: string;
  id: string;
  slug: string;
}

type HierarchyItem = Container | Page;

const url = (sectionSlug: MaybeSlug, projectSlug: MaybeSlug, type: string, slug: string) =>
sectionSlug ?
  `/sections/${sectionSlug}/${type}/${slug}`
  : `/authoring/project/${projectSlug}/preview/${slug}`;

const isCurrentUrl = (sectionSlug: MaybeSlug, projectSlug: MaybeSlug, type: string, slug: string) => {
  return window.location.href.endsWith(url(sectionSlug, projectSlug, type, slug));
};

interface PageItemProps extends FlattenedItem {
  activeContainerSlug: string | undefined;
  sectionSlug: MaybeSlug;
  projectSlug: MaybeSlug;
}

const PageItem = ({
  type,
  title,
  slug,
  level,
  sectionSlug,
  projectSlug,
  containerSlug,
  activeContainerSlug,
}: PageItemProps) => (
  <a
    id={`outline-item-${slug}`}
    href={url(sectionSlug, projectSlug, type, slug)}
    className={classNames(
      'block p-3 border-l-[8px] text-current hover:text-delivery-primary hover:no-underline',
      activeContainerSlug &&
        (containerSlug === activeContainerSlug || slug == activeContainerSlug) &&
        'border-delivery-primary-100',
      isCurrentUrl(sectionSlug, projectSlug, type, slug)
        ? '!border-delivery-primary bg-delivery-primary-50 dark:bg-delivery-primary-800'
        : 'border-transparent',
    )}
  >
    <div style={{ marginLeft: level * 20 }}>{title}</div>
  </a>
);
