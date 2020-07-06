import { ProjectSlug, ResourceSlug } from 'data/types';
import { SiblingActivity, ActivityContext } from 'data/content/activity';
import { BreadcrumbTrail } from 'components/common/BreadcrumbTrail';

const Sibling = ({ sibling, children, projectSlug, resourceSlug }
  : { sibling: SiblingActivity | null, children: any,
    projectSlug: ProjectSlug, resourceSlug: ResourceSlug }) => {

  if (sibling === null) {
    return (
      <li className="page-item disabled">
        <a className="page-link" href="#">{children}</a>
      </li>
    );
  }
  return (
    <li className="page-item">
      <a className="page-link"
        href={`/project/${projectSlug}/resource/${resourceSlug}/activity/${sibling.activitySlug}`}>
        {children}
      </a>
    </li>
  );

};

export const Navigation = (props: ActivityContext) => {

  const { projectSlug, resourceSlug, resourceTitle,
    activitySlug, title, previousActivity, nextActivity } = props;

  const page = {
    slug: resourceSlug,
    title: resourceTitle,
  };
  const activity = {
    slug: activitySlug,
    title,
  };

  return (
    <div className="d-flex justify-content-between">
      <BreadcrumbTrail projectSlug={projectSlug} page={page} activity={activity}/>
    </div>
  );

};

