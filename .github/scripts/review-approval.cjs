/**
 * Return the GitHub team slug for the review author's active team membership.
 * Uses the review author rather than the workflow actor (which can differ on reruns).
 * The torus-dev team supplies Development approvals and takes precedence over QA.
 * Lookup/configuration errors propagate so the Jira notification cannot proceed.
 */
module.exports = async function getApprovalTeam({ github, context }) {
  for (const teamSlug of ["torus-dev", "torus-qa"]) {
    const team = { org: context.repo.owner, team_slug: teamSlug };

    // A missing/inaccessible team must fail, rather than look like a non-member.
    await github.rest.teams.getByName(team);

    try {
      const { data } = await github.rest.teams.getMembershipForUserInOrg({
        ...team,
        username: context.payload.review.user.login,
      });

      if (data.state === "active") {
        return teamSlug;
      }
    } catch (error) {
      if (error.status !== 404) {
        throw error;
      }
    }
  }

  return null;
};
