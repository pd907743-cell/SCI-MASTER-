# Supabase database foundation

The initial SciMaster schema is in
[`supabase/migrations/20261104090000_initial_platform.sql`](../supabase/migrations/20261104090000_initial_platform.sql).
It targets Supabase PostgreSQL (including Supabase Auth and Storage), seeds the
JAMB/WAEC/NECO boards and Physics/Chemistry/Biology/Mathematics subjects, and
enables RLS on all application tables.

## Local development and deployment

Install the Supabase CLI and Docker, then:

```sh
supabase start
supabase db reset
```

Run the transactional seed/RLS/behavior checks against the freshly migrated
local database:

```sh
psql "<local database URL from supabase status>" \
  -v ON_ERROR_STOP=1 \
  -f supabase/tests/security_and_behaviour.sql
```

The test transaction rolls back its fixture users, content, attempts, and
orders when all assertions pass.

For a linked hosted project, review the target project and migration first,
then apply with:

```sh
supabase link --project-ref <project-ref>
supabase db push
```

Do not commit project credentials. Generate application types from the
development project after migrations are applied:

```sh
supabase gen types typescript --local > src/lib/database.types.ts
```

The current React app is not yet connected to Supabase. When adding that
integration, use a browser-safe project URL and publishable/anon key (for
example, `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`). Never put a
service-role key in Vite environment variables or client code. Use authenticated
RPCs or a trusted Edge Function for workflows that need privileged operations.

## Data access and content workflow

- Students are identified by `auth.uid()`; `profiles` is created by an Auth
  trigger. Signup metadata never grants application roles.
- `user_roles` supports `admin` and `content_editor`. The first admin must be
  bootstrapped by an operator through a controlled SQL procedure or trusted
  server environment. There is intentionally no public signup path to a staff
  role.
- Bootstrap the initial admin only after verifying the account in Supabase
  Auth. In the project's SQL editor as a trusted database operator, resolve
  that account's UUID by its verified email, insert the `admin` row into
  `public.user_roles`, and record the bootstrap in `public.admin_audit_log`.
  Do not expose a public bootstrap RPC or put an email/UUID in a committed
  migration.
- Admins can additionally read profiles for users with an access order,
  supporting receipt review and WhatsApp follow-up. Content editors cannot
  read other profiles, orders, or learner activity.
- Editors create and edit draft/review content. Admins control publication.
  Published question versions and their options/solutions are immutable;
  corrections require a new version. Publication changes are audited.
- Students need an active `full_access` entitlement to read lessons, question
  content, flashcards, mnemonics, and CBT content. Public catalog names and
  published paper metadata may be browsed without entitlement.
- `question_solutions` has no student read policy. The client must not query it
  directly; `get_attempt_review(attempt_id)` only returns solutions for the
  authenticated owner's submitted attempt, subject to the exam's review
  policy.
- Attempt rows, selected answers, scores, order decisions, and entitlements are
  not client-writable. Use `start_exam_attempt`, `save_attempt_answer`,
  `submit_exam_attempt`, `create_access_order`, `submit_access_order`,
  `review_access_order`, `set_user_role`, and `revoke_student_access` for those
  actions. User-facing RPCs derive the actor from the verified Supabase JWT,
  not a supplied user ID.
- The `payment-receipts` Storage bucket is private. Students upload beneath
  `<auth.uid()>/<order-id>/...`; staff review via authenticated access. The
  approved product amount is fixed to 400000 kobo (₦4,000) in the database.
  Admin receipt review is manual and is not a payment-provider confirmation.

## Important RPC behavior

1. Call `create_access_order()` and use its UUID to form the private receipt
   object path. Upload a JPEG, PNG, or PDF no larger than 10 MiB.
2. Call `submit_access_order(order_id, object_path, transaction_reference)`
   after upload. The function checks ownership, path, and stored object.
3. An admin calls `review_access_order(order_id, approve, reason)`. Approval
   and lifetime entitlement creation happen in one database transaction.
   `revoke_student_access(user_id, reason)` supports audited admin revocation;
   the last admin role cannot be revoked through `set_user_role`.
4. Call `start_exam_attempt(exam_id)`. It snapshots fixed or randomly selected
   published question versions into the attempt. The database, not the browser
   timer, controls the deadline and score.
5. Save responses through `save_attempt_answer(...)`, submit once through
   `submit_exam_attempt(...)`, and request feedback through
   `get_attempt_review(attempt_id)` when available.

## Pre-production access-control checks

Test with separate anonymous, unpaid-student, paid-student, content-editor, and
admin JWTs. Include negative checks, not only successful queries:

- Anonymous/unpaid users cannot read lesson bodies, question stems/options,
  flashcards, mnemonics, CBT item lists, correct answers, private receipts, or
  another user's profile/progress/attempts/orders.
- Paid students see only published learning content and cannot select from
  `question_solutions` or mutate attempts, scores, entitlements, order status,
  roles, or published question versions.
- An editor can manage drafts but cannot publish them, edit published exam
  lists, or read payment review data.
- An admin can publish content and verify receipts. Admin actions should have
  corresponding audit records.
- Attempt review is unavailable before submission, for another user's attempt,
  or before an `after_window` exam's availability window ends.
- Upload paths cannot cross user/order boundaries. The receipt bucket must
  remain private.

These policies are a baseline; verify them against real Supabase JWT claims and
Storage behavior in a staging project before importing production student or
exam data.
