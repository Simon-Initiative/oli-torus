import { ActivityContext } from 'data/content/activity';
import { BreadcrumbTrail } from 'components/common/BreadcrumbTrail';

export const Navigation = (props: ActivityContext) => {

  const { projectSlug, resourceSlug, resourceTitle,
    activitySlug, title } = props;

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

