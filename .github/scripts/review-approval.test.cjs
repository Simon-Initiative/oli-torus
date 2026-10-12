const assert = require("node:assert/strict");
const { test } = require("node:test");
const getApprovalTeam = require("./review-approval.cjs");

function fixture({
  memberships = {},
  membershipErrors = {},
  teamErrors = {},
} = {}) {
  const calls = [];
  return {
    calls,
    context: {
      actor: "person-rerunning-workflow",
      repo: { owner: "Simon-Initiative" },
      payload: { review: { user: { login: "review-author" } } },
    },
    github: {
      rest: {
        teams: {
          getByName: async (parameters) => {
            calls.push(["team", parameters]);
            if (teamErrors[parameters.team_slug])
              throw teamErrors[parameters.team_slug];
            return { data: { slug: parameters.team_slug } };
          },
          getMembershipForUserInOrg: async (parameters) => {
            calls.push(["membership", parameters]);
            if (membershipErrors[parameters.team_slug])
              throw membershipErrors[parameters.team_slug];
            if (!(parameters.team_slug in memberships)) {
              throw Object.assign(new Error("Not a member"), { status: 404 });
            }
            return { data: { state: memberships[parameters.team_slug] } };
          },
        },
      },
    },
  };
}

test("classifies an active Development approval using the review author, not the rerun actor", async () => {
  const input = fixture({ memberships: { development: "active" } });
  assert.equal(await getApprovalTeam(input), "development");
  assert.deepEqual(input.calls, [
    ["team", { org: "Simon-Initiative", team_slug: "development" }],
    [
      "membership",
      {
        org: "Simon-Initiative",
        team_slug: "development",
        username: "review-author",
      },
    ],
  ]);
});

test("classifies a QA-only approval using the same review author", async () => {
  const input = fixture({ memberships: { qa: "active" } });
  assert.equal(await getApprovalTeam(input), "qa");
  assert.deepEqual(input.calls.slice(2), [
    ["team", { org: "Simon-Initiative", team_slug: "qa" }],
    [
      "membership",
      {
        org: "Simon-Initiative",
        team_slug: "qa",
        username: "review-author",
      },
    ],
  ]);
});

test("Development takes precedence when both memberships are active", async () => {
  assert.equal(
    await getApprovalTeam(
      fixture({
        memberships: {
          development: "active",
          qa: "active",
        },
      })
    ),
    "development"
  );
});

test("does not classify reviewers outside both teams", async () => {
  assert.equal(await getApprovalTeam(fixture()), null);
});

for (const team of ["development", "qa"]) {
  for (const state of ["pending", null]) {
    test(`does not classify ${team} membership with state ${state}`, async () => {
      assert.equal(
        await getApprovalTeam(fixture({ memberships: { [team]: state } })),
        null
      );
    });
  }

  for (const status of [401, 403, 429, 500]) {
    test(`fails visibly when the ${team} membership lookup returns ${status}`, async () => {
      const error = Object.assign(new Error("Membership lookup failed"), {
        status,
      });
      await assert.rejects(
        getApprovalTeam(fixture({ membershipErrors: { [team]: error } })),
        error
      );
    });
  }

  test(`fails visibly on a ${team} network error`, async () => {
    const error = new Error("Network unavailable");
    await assert.rejects(
      getApprovalTeam(fixture({ membershipErrors: { [team]: error } })),
      error
    );
  });

  test(`fails for inaccessible ${team} before attempting its membership lookup`, async () => {
    const error = Object.assign(new Error("Team not found"), { status: 404 });
    const input = fixture({ teamErrors: { [team]: error } });
    await assert.rejects(getApprovalTeam(input), error);
    assert.equal(
      input.calls.some(
        ([operation, parameters]) =>
          operation === "membership" && parameters.team_slug === team
      ),
      false
    );
  });
}

test("pending Development membership still permits an active QA membership", async () => {
  assert.equal(
    await getApprovalTeam(
      fixture({
        memberships: {
          development: "pending",
          qa: "active",
        },
      })
    ),
    "qa"
  );
});

test("does not fall back to QA when the Development membership lookup fails", async () => {
  const error = Object.assign(new Error("Access denied"), { status: 403 });
  const input = fixture({
    memberships: { qa: "active" },
    membershipErrors: { development: error },
  });
  await assert.rejects(getApprovalTeam(input), error);
  assert.equal(input.calls.length, 2);
});
