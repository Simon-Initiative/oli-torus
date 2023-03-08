import React, { useEffect } from 'react';
import { classNames } from 'utils/classNames';

interface CourseContentOutlineProps {
  sectionSlug: string;
  hierarchy: any;
}

export const CourseContentOutline = ({ sectionSlug, hierarchy }: CourseContentOutlineProps) => {
  const items = flatten({ type: 'root', ...hierarchy }, sectionSlug);
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
  sectionSlug: string,
  containerSlug?: string | undefined,
  level = 0,
): FlattenedItem[] =>
  item.type === 'root'
    ? item.children.reduce(
        (acc, c) => [...acc, ...flatten(c, sectionSlug, containerSlug, level + 1)],
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
          isActive: isCurrentUrl(sectionSlug, item.type, item.slug),
        },
        ...item.children.reduce(
          (acc: FlattenedItem[], c: HierarchyItem) => [
            ...acc,
            ...flatten(c, sectionSlug, item.slug, level + 1),
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
          isActive: isCurrentUrl(sectionSlug, item.type, item.slug),
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

const url = (sectionSlug: string, type: string, slug: string) =>
  `/sections/${sectionSlug}/${type}/${slug}`;

const isCurrentUrl = (sectionSlug: string, type: string, slug: string) => {
  return window.location.href.endsWith(url(sectionSlug, type, slug));
};

interface PageItemProps extends FlattenedItem {
  activeContainerSlug: string | undefined;
  sectionSlug: string;
}

const PageItem = ({
  type,
  title,
  slug,
  level,
  sectionSlug,
  containerSlug,
  activeContainerSlug,
}: PageItemProps) => (
  <a
    id={`outline-item-${slug}`}
    href={url(sectionSlug, type, slug)}
    className={classNames(
      'block p-3 border-l-[8px] text-current hover:text-delivery-primary hover:no-underline',
      activeContainerSlug &&
        (containerSlug === activeContainerSlug || slug == activeContainerSlug) &&
        'border-delivery-primary-100',
      isCurrentUrl(sectionSlug, type, slug)
        ? '!border-delivery-primary bg-delivery-primary-50'
        : 'border-transparent',
    )}
  >
    <div style={{ marginLeft: level * 20 }}>{title}</div>
  </a>
);
