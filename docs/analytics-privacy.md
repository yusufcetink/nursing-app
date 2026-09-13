# Analytics privacy boundary

Aslı App activity analytics is collected only to measure person-level product usage and
active time for approved research. Access to individual summaries and timelines is
restricted to the Admin role.

The client emits typed interaction identifiers and entity IDs. It must not emit password,
JWT, email, verification/reset code, quiz response text, free-form form content, or other
raw personal data. The server independently enforces a small metadata-key allow-list and
length limits before serializing `MetadataJson`.

`screen_leave` and `session_end` durations use foreground-active time. Background time is
excluded. Delivery failures are retried asynchronously and never block the learning flow;
`ClientEventId` prevents retries from creating duplicate research records.

Operational deployments should define an approved retention period, document the legal
basis/consent shown to participants, restrict database and Admin access, and delete or
anonymize research data when that period ends.
