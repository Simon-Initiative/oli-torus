import React from 'react';

interface CourseContentOutlineProps {
  sectionSlug: string;
  hierarchy: any;
}

export const CourseContentOutline = ({ sectionSlug, hierarchy }: CourseContentOutlineProps) => {
  console.log(hierarchy);

  return (
    <div className="px-6 lg:px-2 lg:py-5">
      <div className="hidden lg:block mb-4 font-bold">Course Content</div>
      <div>
        <ContainerItem sectionSlug={sectionSlug} item={hierarchy} level={0} />
      </div>
    </div>
  );
};

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

interface OutlineItemProps {
  item: HierarchyItem;
  level: number;
  sectionSlug: string;
}

const OutlineItem = ({ item, level, sectionSlug }: OutlineItemProps) =>
  item.type === 'container' ? (
    <ContainerItem sectionSlug={sectionSlug} item={item} level={level} />
  ) : (
    <PageItem sectionSlug={sectionSlug} item={item} level={level} />
  );

interface ContainerItemProps {
  item: Container | Root;
  level: number;
  sectionSlug: string;
}

const ContainerItem = ({ item, level, sectionSlug }: ContainerItemProps) => (
  <div>
    {item.type === 'container' && (
      <div className="my-4">
        <a href={url(sectionSlug, item.type, item.slug)}>{item.title}</a>
      </div>
    )}
    <div>
      {item.children.map((c) => (
        <OutlineItem key={c.id} item={c} level={level + 1} sectionSlug={sectionSlug} />
      ))}
    </div>
  </div>
);

interface PageItemProps {
  item: Page;
  level: number;
  sectionSlug: string;
}

const PageItem = ({ item: { type, title, slug }, level, sectionSlug }: PageItemProps) => (
  <div className="my-4" style={{ marginLeft: level * 10 }}>
    <a href={url(sectionSlug, type, slug)}>{title}</a>
  </div>
);

const url = (sectionSlug: string, type: string, slug: string) =>
  `/sections/${sectionSlug}/${type}/${slug}`;
