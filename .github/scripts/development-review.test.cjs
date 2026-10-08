const assert = require("node:assert/strict");
const { test } = require("node:test");
const isDevelopmentReviewer = require("./development-review.cjs");

function fixture({ state = "active", membershipError, teamError } = {}) {
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
            if (teamError) throw teamError;
            return { data: { slug: "development" } };
          },
          getMembershipForUserInOrg: async (parameters) => {
            calls.push(["membership", parameters]);
            if (membershipError) throw membershipError;
            return { data: { state } };
          },
        },
      },
    },
  };
}

test("allows an active Development reviewer, using the author rather than the rerun actor", async () => {
  const input = fixture();
  assert.equal(await isDevelopmentReviewer(input), true);
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

test("does not allow a QA-only reviewer or other non-member", async () => {
  const input = fixture({ membershipError: { status: 404 } });
  assert.equal(await isDevelopmentReviewer(input), false);
});

test("does not allow pending Development membership", async () => {
  assert.equal(
    await isDevelopmentReviewer(fixture({ state: "pending" })),
    false
  );
});

test("does not allow a response without confirmed active membership", async () => {
  assert.equal(await isDevelopmentReviewer(fixture({ state: null })), false);
});

for (const status of [401, 403, 429, 500]) {
  test(`fails visibly when the membership lookup returns ${status}`, async () => {
    const error = Object.assign(new Error("Membership lookup failed"), {
      status,
    });
    await assert.rejects(
      isDevelopmentReviewer(fixture({ membershipError: error })),
      error
    );
  });
}

test("fails visibly on a network error", async () => {
  const error = new Error("Network unavailable");
  await assert.rejects(
    isDevelopmentReviewer(fixture({ membershipError: error })),
    error
  );
});

test("fails for an inaccessible team before attempting the user lookup", async () => {
  const error = Object.assign(new Error("Team not found"), { status: 404 });
  const input = fixture({ teamError: error });
  await assert.rejects(isDevelopmentReviewer(input), error);
  assert.equal(input.calls.length, 1);
});
