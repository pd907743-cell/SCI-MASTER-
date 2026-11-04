\set ON_ERROR_STOP on

begin;

create function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is distinct from true then
    raise exception 'Assertion failed: %', p_message;
  end if;
end;
$$;

create function pg_temp.assert_error(p_sql text, p_expected_state text, p_message text)
returns void
language plpgsql
as $$
declare
  v_actual_state text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_actual_state = returned_sqlstate;
    if v_actual_state = p_expected_state then
      return;
    end if;
    raise exception 'Assertion failed: % (expected SQLSTATE %, got %)',
      p_message, p_expected_state, v_actual_state;
  end;
  raise exception 'Assertion failed: % (statement unexpectedly succeeded)', p_message;
end;
$$;

insert into auth.users (id, raw_user_meta_data) values
  ('10000000-0000-4000-8000-000000000001', '{"display_name":"Test Admin"}'),
  ('10000000-0000-4000-8000-000000000002', '{"display_name":"Test Student"}'),
  ('10000000-0000-4000-8000-000000000003', '{"display_name":"Other Student"}'),
  ('10000000-0000-4000-8000-000000000004', '{"display_name":"Test Editor"}');

insert into public.access_orders
  (id, user_id, status, receipt_object_path, submitted_at)
values
  ('40000000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000003',
   'pending',
   '10000000-0000-4000-8000-000000000003/40000000-0000-4000-8000-000000000002/receipt.pdf',
   now());
insert into storage.objects (bucket_id, name) values
  ('payment-receipts',
   '10000000-0000-4000-8000-000000000003/40000000-0000-4000-8000-000000000002/receipt.pdf');

insert into public.user_roles (user_id, role, granted_by) values
  ('10000000-0000-4000-8000-000000000001', 'admin', '10000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000004', 'content_editor', '10000000-0000-4000-8000-000000000001');

insert into public.topics (id, subject_code, slug, title) values
  ('20000000-0000-4000-8000-000000000001', 'PHYSICS', 'test-mechanics', 'Test mechanics');
insert into public.subtopics (id, topic_id, subject_code, slug, title) values
  ('20000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001',
   'PHYSICS', 'test-motion', 'Test motion');

insert into public.lessons (id, subtopic_id, slug, title, body_markdown, status, created_by) values
  ('20000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000002',
   'published-test', 'Published lesson', 'Published body', 'published',
   '10000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000002',
   'draft-test', 'Draft lesson', 'Draft body', 'draft',
   '10000000-0000-4000-8000-000000000004');

insert into public.exam_papers
  (id, board_code, exam_year, subject_code, session_code, paper_code, status, created_by)
values
  ('20000000-0000-4000-8000-000000000005', 'JAMB', 2025, 'PHYSICS',
   'main', 'paper-1', 'published', '10000000-0000-4000-8000-000000000001');
select pg_temp.assert_error(
  'insert into public.exam_papers(board_code, exam_year, subject_code, session_code, paper_code) '
    || 'values (''JAMB'', 1998, ''PHYSICS'', ''test'', ''invalid-year'')',
  '23514',
  'database rejects examination years before 1999');
select pg_temp.assert_error(
  'insert into public.exam_papers(board_code, exam_year, subject_code, session_code, paper_code) '
    || 'values (''JAMB'', extract(year from current_date)::integer + 1, '
    || '''PHYSICS'', ''test'', ''future-year'')',
  'P0001',
  'database rejects future examination years');

insert into public.questions (id, created_by) values
  ('20000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001');
insert into public.question_versions
  (id, question_id, version_number, subject_code, subtopic_id, stem_markdown, rights_status, created_by)
values
  ('20000000-0000-4000-8000-000000000007',
   '20000000-0000-4000-8000-000000000006', 1, 'PHYSICS',
   '20000000-0000-4000-8000-000000000002', 'Test question: select B',
   'original', '10000000-0000-4000-8000-000000000001');
insert into public.question_options (version_id, option_key, body_markdown, position) values
  ('20000000-0000-4000-8000-000000000007', 'A', 'Wrong answer', 1),
  ('20000000-0000-4000-8000-000000000007', 'B', 'Correct answer', 2);
insert into public.question_solutions (version_id, correct_option_key, explanation_markdown) values
  ('20000000-0000-4000-8000-000000000007', 'B', 'The test answer is B.');
select pg_temp.assert_error(
  'update public.question_solutions set correct_option_key = ''E'' '
    || 'where version_id = ''20000000-0000-4000-8000-000000000007''',
  '23503',
  'solution must reference an option belonging to its own question version');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
update public.question_versions
set status = 'published'
where id = '20000000-0000-4000-8000-000000000007';
reset role;

insert into public.paper_questions (paper_id, question_version_id, subject_code, question_number)
values ('20000000-0000-4000-8000-000000000005',
        '20000000-0000-4000-8000-000000000007', 'PHYSICS', 1);

insert into public.cbt_exams
  (id, title, subject_code, board_code, exam_year, selection_mode, question_count,
   duration_seconds, status, created_by)
values
  ('30000000-0000-4000-8000-000000000001', 'Fixed test', 'PHYSICS', 'JAMB', 2025,
   'fixed', 1, 600, 'published', '10000000-0000-4000-8000-000000000001'),
  ('30000000-0000-4000-8000-000000000002', 'Random test', 'PHYSICS', 'JAMB', 2025,
   'random', 1, 600, 'published', '10000000-0000-4000-8000-000000000001'),
  ('30000000-0000-4000-8000-000000000003', 'Draft test', 'PHYSICS', 'JAMB', 2025,
   'fixed', 1, 600, 'draft', '10000000-0000-4000-8000-000000000004');

insert into public.cbt_exam_questions (exam_id, question_version_id, subject_code, position, marks)
values ('30000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000007', 'PHYSICS', 1, 2);

do $$
declare
  v_public_exec_count integer;
  v_unpinned_definer_count integer;
begin
  perform pg_temp.assert_true(
    (select count(*) = 0
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
    'every public application table has row-level security enabled');
  perform pg_temp.assert_true((select count(*) = 3 from public.exam_boards),
    'migration seeds all three examination boards');
  perform pg_temp.assert_true((select count(*) = 4 from public.subjects),
    'migration seeds all four initial subjects');
  perform pg_temp.assert_true(
    (select count(*) = 3
     from pg_trigger
     where tgname in (
       'on_auth_user_created',
       'question_version_guard',
       'entitlement_verified_order_guard'
     ) and not tgisinternal),
    'profile, question immutability, and entitlement guards are installed');

  select count(*) into v_public_exec_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  where n.nspname = 'public'
    and p.prosecdef
    and p.prorettype <> 'trigger'::regtype
    and acl.grantee = 0
    and acl.privilege_type = 'EXECUTE';
  perform pg_temp.assert_true(v_public_exec_count = 0,
    'callable SECURITY DEFINER functions must not be executable by PUBLIC');

  select count(*) into v_unpinned_definer_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and not coalesce(p.proconfig, array[]::text[]) @> array['search_path=""'];
  perform pg_temp.assert_true(v_unpinned_definer_count = 0,
    'SECURITY DEFINER functions must set an empty search_path');
end;
$$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select pg_temp.assert_true((select count(*) = 3 from public.exam_boards),
  'anonymous visitor can read public exam-board catalog');
select pg_temp.assert_true((select count(*) = 4 from public.subjects),
  'anonymous visitor can read public subject catalog');
select pg_temp.assert_true((select count(*) = 1 from public.exam_papers),
  'anonymous visitor can read published paper metadata');
select pg_temp.assert_true((select count(*) = 0 from public.lessons),
  'anonymous visitor cannot read lesson bodies');
select pg_temp.assert_true((select count(*) = 0 from public.question_versions),
  'anonymous visitor cannot read question stems');
select pg_temp.assert_true((select count(*) = 0 from public.question_options),
  'anonymous visitor cannot read question options');
select pg_temp.assert_true((select count(*) = 0 from public.paper_questions),
  'anonymous visitor cannot read question-paper mappings');
select pg_temp.assert_true((select count(*) = 0 from public.cbt_exams),
  'anonymous visitor cannot read CBT exams');
select pg_temp.assert_true((select count(*) = 0 from storage.objects),
  'anonymous visitor cannot read private receipts');
select pg_temp.assert_error(
  'select * from public.question_solutions',
  '42501',
  'anonymous visitor has no answer-key table privilege');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select pg_temp.assert_true((select count(*) = 1 from public.profiles),
  'student can read own profile');
select pg_temp.assert_true((select count(*) = 0 from public.profiles
  where id = '10000000-0000-4000-8000-000000000003'),
  'student cannot read another student profile');
select pg_temp.assert_true((select count(*) = 0 from public.lessons),
  'unpaid student cannot read lessons');
select pg_temp.assert_true((select count(*) = 0 from public.question_versions),
  'unpaid student cannot read questions');
select pg_temp.assert_true((select count(*) = 0 from public.question_solutions),
  'student cannot directly read answer keys');
select pg_temp.assert_true((select count(*) = 0 from public.access_orders),
  'student cannot read another student payment order');
select pg_temp.assert_true((select count(*) = 0 from public.exam_attempts),
  'student cannot read another student attempts');
select pg_temp.assert_true((select count(*) = 0 from storage.objects),
  'student cannot read another student receipts');
select pg_temp.assert_error(
  'select public.start_exam_attempt(''30000000-0000-4000-8000-000000000001'')',
  'P0001',
  'unpaid student cannot start an exam');
select pg_temp.assert_error(
  'insert into public.student_entitlements(user_id, source_order_id) values '
    || '(''10000000-0000-4000-8000-000000000002'', '
    || '''40000000-0000-4000-8000-000000000001'')',
  '42501',
  'student cannot grant themselves an entitlement');
select pg_temp.assert_error(
  'insert into public.user_roles(user_id, role) values '
    || '(''10000000-0000-4000-8000-000000000002'', ''admin'')',
  '42501',
  'student cannot grant themselves an admin role');
select pg_temp.assert_error(
  'update public.access_orders set status = ''verified''',
  '42501',
  'student cannot alter payment status');
select pg_temp.assert_error(
  'select public.review_access_order(''40000000-0000-4000-8000-000000000001'', true, null)',
  'P0001',
  'student cannot approve payments');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select pg_temp.assert_true((select count(*) = 1 from public.lessons where status = 'draft'),
  'content editor can read drafts');
select pg_temp.assert_true((select count(*) = 1 from public.question_solutions),
  'content editor can review answer keys');
select pg_temp.assert_true((select count(*) = 0 from public.access_orders),
  'content editor cannot read payment records');
select pg_temp.assert_true((select count(*) = 0 from public.exam_attempts),
  'content editor cannot read student attempts');
select pg_temp.assert_true((select count(*) = 0 from public.profiles
  where id = '10000000-0000-4000-8000-000000000002'),
  'content editor cannot read student profiles');
select pg_temp.assert_error(
  'update public.cbt_exams set status = ''published'' '
    || 'where id = ''30000000-0000-4000-8000-000000000003''',
  '42501',
  'content editor cannot publish an exam');
select pg_temp.assert_true((select status = 'draft' from public.cbt_exams
  where id = '30000000-0000-4000-8000-000000000003'),
  'content editor cannot publish an exam');
select pg_temp.assert_error(
  'select public.set_user_role(''10000000-0000-4000-8000-000000000002'', ''admin'', true)',
  'P0001',
  'content editor cannot grant roles');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select public.create_access_order() as student_order \gset
select public.create_access_order() as duplicate_order \gset
select pg_temp.assert_true(:'student_order'::uuid = :'duplicate_order'::uuid,
  'repeated order creation reuses the pending order');
insert into storage.objects (bucket_id, name)
values ('payment-receipts',
        '10000000-0000-4000-8000-000000000002/' || :'student_order' || '/receipt.pdf');
select public.submit_access_order(
  :'student_order'::uuid,
  '10000000-0000-4000-8000-000000000002/' || :'student_order' || '/receipt.pdf',
  'TEST-REFERENCE');
select pg_temp.assert_true((select count(*) = 1 from storage.objects
  where name = '10000000-0000-4000-8000-000000000002/'
    || :'student_order' || '/receipt.pdf'),
  'student can read own submitted receipt');
select pg_temp.assert_true((select count(*) = 0 from storage.objects
  where name like '10000000-0000-4000-8000-000000000003/%'),
  'student cannot read another student receipt');
select pg_temp.assert_error(
  'select public.submit_access_order(' || quote_literal(:'student_order') || '::uuid, '
    || quote_literal('10000000-0000-4000-8000-000000000002/' || :'student_order' || '/replacement.pdf')
    || ', ''REPLACEMENT'')',
  'P0001',
  'student cannot replace a receipt while pending review');
select pg_temp.assert_error(
  'select public.review_access_order(' || quote_literal(:'student_order') || '::uuid, true, null)',
  'P0001',
  'student cannot approve own payment');
select pg_temp.assert_true((select status = 'pending' from public.access_orders
  where id = :'student_order'::uuid),
  'payment remains pending until admin review');
select pg_temp.assert_true((select count(*) = 0 from public.student_entitlements),
  'receipt submission does not grant access');
select pg_temp.assert_error(
  'select public.review_access_order(' || quote_literal(:'student_order') || '::uuid, true, null)',
  'P0001',
  'non-admin account cannot approve submitted payment');
select pg_temp.assert_true((select status = 'pending' from public.access_orders
  where id = :'student_order'::uuid),
  'unauthorized approval attempt leaves payment pending');
select pg_temp.assert_true((select count(*) = 0 from public.question_solutions),
  'answer keys remain hidden before attempt submission');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select pg_temp.assert_error(
  'select public.review_access_order(' || quote_literal(:'student_order') || '::uuid, true, null)',
  'P0001',
  'content editor cannot approve payments');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select pg_temp.assert_true((select count(*) = 1 from public.profiles
  where id = '10000000-0000-4000-8000-000000000002'),
  'admin can read the profile associated with a payment order');
select public.review_access_order(:'student_order'::uuid, true, null);
select pg_temp.assert_true((select status = 'verified' from public.access_orders
  where id = :'student_order'::uuid),
  'admin approval updates payment status');
select pg_temp.assert_true((select count(*) = 1 from public.student_entitlements
  where user_id = '10000000-0000-4000-8000-000000000002'
    and status = 'active'),
  'admin approval grants exactly one active entitlement');
select pg_temp.assert_true((select count(*) = 1 from public.admin_audit_log
  where action = 'access_order_verified'
    and entity_id = :'student_order'),
  'payment approval is audited');
select pg_temp.assert_error(
  'select public.set_user_role(''10000000-0000-4000-8000-000000000001'', ''admin'', false)',
  'P0001',
  'last admin account cannot remove its own admin role');
select pg_temp.assert_error(
  'update public.question_versions set stem_markdown = ''Changed'' '
    || 'where id = ''20000000-0000-4000-8000-000000000007''',
  'P0001',
  'published question version is immutable even to an admin');
select pg_temp.assert_error(
  'insert into public.student_entitlements(user_id, source_order_id) values '
    || '(''10000000-0000-4000-8000-000000000003'', '
    || quote_literal(:'student_order') || ')',
  '42501',
  'admin cannot bypass entitlement workflow with a direct insert');
reset role;
select pg_temp.assert_error(
  'insert into public.student_entitlements(user_id, source_order_id) values '
    || '(''10000000-0000-4000-8000-000000000003'', '
    || quote_literal(:'student_order') || ')',
  'P0001',
  'database trigger rejects an entitlement linked to another user order');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select pg_temp.assert_true(public.has_active_access(),
  'approved payment activates student access');
select pg_temp.assert_true((select count(*) = 1 from public.lessons where status = 'published'),
  'paid student can read published lessons');
select pg_temp.assert_true((select count(*) = 0 from public.lessons where status <> 'published'),
  'paid student cannot read draft lessons');
select pg_temp.assert_true((select count(*) = 2 from public.cbt_exams),
  'paid student sees only published CBT exams');
select pg_temp.assert_true((select count(*) = 1 from public.question_versions),
  'paid student can read published question stems');
select pg_temp.assert_true((select count(*) = 2 from public.question_options),
  'paid student can read published options');
select pg_temp.assert_true((select count(*) = 0 from public.question_solutions),
  'paid student still cannot directly read answer keys');
select pg_temp.assert_error(
  'insert into public.exam_attempts(user_id, exam_id, subject_code, expires_at) '
    || 'values (''10000000-0000-4000-8000-000000000002'', '
    || '''30000000-0000-4000-8000-000000000001'', ''PHYSICS'', now() + interval ''10 minutes'')',
  '42501',
  'student cannot forge attempt records');
select pg_temp.assert_error(
  'update public.exam_attempts set score = 999',
  '42501',
  'student cannot directly alter exam scores');
select public.start_exam_attempt('30000000-0000-4000-8000-000000000001')
  as fixed_attempt \gset
select pg_temp.assert_error(
  'select * from public.get_attempt_review(' || quote_literal(:'fixed_attempt') || '::uuid)',
  'P0001',
  'answer review is blocked before submission');
select pg_temp.assert_true((select count(*) = 0 from public.question_solutions),
  'starting an attempt does not expose direct answer keys');
select public.save_attempt_answer(
  :'fixed_attempt'::uuid, '20000000-0000-4000-8000-000000000007', 'B');
select pg_temp.assert_error(
  'select * from public.get_attempt_review(' || quote_literal(:'fixed_attempt') || '::uuid)',
  'P0001',
  'answer review remains blocked before submission');
select score as submitted_score
from public.submit_exam_attempt(:'fixed_attempt'::uuid) \gset
select pg_temp.assert_true(:'submitted_score'::numeric = 2,
  'server-side scoring awards the correct marks');
select pg_temp.assert_true((select count(*) = 1 from public.get_attempt_review(
  :'fixed_attempt'::uuid) where correct_option_key = 'B'),
  'owner receives answer key only through submitted-attempt review');
select pg_temp.assert_true((select count(*) = 0 from public.question_solutions),
  'review RPC does not grant direct answer-key table access');
select public.start_exam_attempt('30000000-0000-4000-8000-000000000002')
  as random_attempt \gset
select pg_temp.assert_true((select count(*) = 1 from public.attempt_questions
  where attempt_id = :'random_attempt'::uuid),
  'random CBT snapshots the configured question count');
select public.save_attempt_answer(
  :'random_attempt'::uuid, '20000000-0000-4000-8000-000000000007', 'A');
select score as random_score
from public.submit_exam_attempt(:'random_attempt'::uuid) \gset
select pg_temp.assert_true(:'random_score'::numeric = 0,
  'server-side scoring rejects the wrong option');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select pg_temp.assert_true((select count(*) = 0 from public.exam_attempts),
  'another student cannot read the first student attempts');
select pg_temp.assert_true((select count(*) = 0 from public.attempt_answers),
  'another student cannot read the first student answers');
select pg_temp.assert_true((select count(*) = 0 from public.lesson_progress),
  'another student cannot read the first student progress');
select pg_temp.assert_true((select count(*) = 0 from public.access_orders
  where user_id = '10000000-0000-4000-8000-000000000002'),
  'another student cannot read the first student payment order');
select pg_temp.assert_true((select count(*) = 0 from public.student_entitlements),
  'another student cannot read the first student entitlement');
select pg_temp.assert_error(
  'select * from public.get_attempt_review(' || quote_literal(:'fixed_attempt') || '::uuid)',
  'P0001',
  'another student cannot obtain the first student answer review');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
update public.question_options
set body_markdown = 'Tampered answer'
where version_id = '20000000-0000-4000-8000-000000000007' and option_key = 'B';
select pg_temp.assert_true((select body_markdown = 'Correct answer'
  from public.question_options
  where version_id = '20000000-0000-4000-8000-000000000007' and option_key = 'B'),
  'editor cannot mutate an option on a published question');
reset role;
select pg_temp.assert_true((select count(*) = 1 from public.admin_audit_log
  where action = 'content_published'
    and entity_id = '20000000-0000-4000-8000-000000000007'),
  'question publication is audited');

rollback;
\echo 'SciMaster database security and behavior assertions passed.'
