/**
 * Allow the Jira QA handoff only for an active Development team reviewer.
 * Uses the review author rather than the workflow actor (which can differ on reruns).
 * Lookup/configuration errors propagate so the Jira notification cannot proceed.
 */
module.exports = async function isDevelopmentReviewer({ github, context }) {
  const team = { org: context.repo.owner, team_slug: "development" };

  // A missing/inaccessible team must fail, rather than look like a non-member.
  await github.rest.teams.getByName(team);

  try {
    const { data } = await github.rest.teams.getMembershipForUserInOrg({
      ...team,
      username: context.payload.review.user.login,
    });

    return data.state === "active";
  } catch (error) {
    if (error.status === 404) {
      return false;
    }

    throw error;
  }
};
