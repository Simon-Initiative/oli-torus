# Approach

1. Parse Jira ticket key/URL and fetch issue details from MCP.
2. Read description + comments, extracting engineering clarifications and concrete constraints.
3. Read epic context docs if Jira ticket belongs to an epic.
4. Produce a brief in-chat technical approach and short numbered implementation plan.
5. Revise brief plan based on user feedback.
6. On user approval, implement directly with narrow scope and required tests.
7. Run compile + relevant tests and return concise execution summary.
