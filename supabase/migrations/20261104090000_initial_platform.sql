create type public.app_role as enum ('admin', 'content_editor');
create type public.content_status as enum ('draft', 'review', 'published', 'archived');
create type public.exam_selection_mode as enum ('fixed', 'random');
create type public.exam_review_policy as enum ('after_submit', 'after_window');
create type public.attempt_status as enum ('in_progress', 'submitted');
create type public.access_order_status as enum ('pending', 'verified', 'rejected');
create type public.entitlement_status as enum ('active', 'revoked');

create table public.exam_boards (
  code text primary key check (code in ('JAMB', 'WAEC', 'NECO')),
  name text not null,
  active boolean not null default true
);

create table public.subjects (
  code text primary key check (code in ('PHYSICS', 'CHEMISTRY', 'BIOLOGY', 'MATHEMATICS')),
  name text not null,
  active boolean not null default true,
  sort_order smallint not null default 0
);

create table public.topics (
  id uuid primary key default gen_random_uuid(),
  subject_code text not null references public.subjects(code),
  slug text not null,
  title text not null,
  sort_order integer not null default 0,
  unique (subject_code, slug),
  unique (id, subject_code)
);

create table public.subtopics (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null,
  subject_code text not null,
  slug text not null,
  title text not null,
  sort_order integer not null default 0,
  foreign key (topic_id, subject_code) references public.topics(id, subject_code),
  unique (topic_id, slug),
  unique (id, subject_code)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  subtopic_id uuid not null references public.subtopics(id),
  slug text not null,
  title text not null,
  summary text not null default '',
  body_markdown text not null,
  estimated_minutes smallint check (estimated_minutes is null or estimated_minutes > 0),
  status public.content_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subtopic_id, slug)
);

create table public.exam_papers (
  id uuid primary key default gen_random_uuid(),
  board_code text not null references public.exam_boards(code),
  exam_year smallint not null check (exam_year >= 1999),
  subject_code text not null references public.subjects(code),
  session_code text not null default 'main',
  paper_code text not null default 'paper-1',
  status public.content_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (board_code, exam_year, subject_code, session_code, paper_code),
  unique (id, subject_code)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create table public.question_versions (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  subject_code text not null references public.subjects(code),
  subtopic_id uuid not null,
  stem_markdown text not null,
  difficulty smallint check (difficulty between 1 and 5),
  source_citation text not null default '',
  rights_status text not null default 'pending'
    check (rights_status in ('pending', 'licensed', 'original', 'public_domain')),
  status public.content_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (subtopic_id, subject_code)
    references public.subtopics(id, subject_code),
  unique (question_id, version_number),
  unique (id, subject_code)
);

create table public.question_options (
  version_id uuid not null references public.question_versions(id) on delete cascade,
  option_key text not null check (option_key in ('A', 'B', 'C', 'D', 'E')),
  body_markdown text not null,
  position smallint not null check (position > 0),
  primary key (version_id, option_key),
  unique (version_id, position)
);

create table public.question_solutions (
  version_id uuid primary key references public.question_versions(id) on delete cascade,
  correct_option_key text not null,
  explanation_markdown text not null default '',
  foreign key (version_id, correct_option_key)
    references public.question_options(version_id, option_key)
    on delete cascade
);

create table public.paper_questions (
  paper_id uuid not null,
  question_version_id uuid not null,
  subject_code text not null,
  question_number integer not null check (question_number > 0),
  marks numeric(6, 2) not null default 1 check (marks > 0),
  primary key (paper_id, question_number),
  unique (paper_id, question_version_id),
  foreign key (paper_id, subject_code)
    references public.exam_papers(id, subject_code) on delete cascade,
  foreign key (question_version_id, subject_code)
    references public.question_versions(id, subject_code)
);

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  subtopic_id uuid references public.subtopics(id) on delete cascade,
  front text not null,
  back text not null,
  sort_order integer not null default 0,
  status public.content_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(lesson_id, subtopic_id) = 1)
);

create table public.mnemonics (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  subtopic_id uuid references public.subtopics(id) on delete cascade,
  title text not null,
  body text not null,
  sort_order integer not null default 0,
  status public.content_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(lesson_id, subtopic_id) = 1)
);

create table public.cbt_exams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subject_code text not null references public.subjects(code),
  board_code text references public.exam_boards(code),
  exam_year smallint check (exam_year is null or exam_year >= 1999),
  selection_mode public.exam_selection_mode not null default 'fixed',
  question_count integer not null check (question_count > 0),
  duration_seconds integer not null check (duration_seconds between 60 and 86400),
  review_policy public.exam_review_policy not null default 'after_submit',
  available_from timestamptz,
  available_until timestamptz,
  status public.content_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (available_from is null or available_until is null or available_from < available_until),
  check (review_policy <> 'after_window' or available_until is not null),
  check (board_code is not null or exam_year is null),
  unique (id, subject_code)
);

create table public.cbt_exam_questions (
  exam_id uuid not null,
  question_version_id uuid not null,
  subject_code text not null,
  position integer not null check (position > 0),
  marks numeric(6, 2) not null default 1 check (marks > 0),
  primary key (exam_id, position),
  unique (exam_id, question_version_id),
  foreign key (exam_id, subject_code)
    references public.cbt_exams(id, subject_code) on delete cascade,
  foreign key (question_version_id, subject_code)
    references public.question_versions(id, subject_code)
);

create table public.exam_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  exam_id uuid not null,
  subject_code text not null,
  status public.attempt_status not null default 'in_progress',
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  submitted_at timestamptz,
  score numeric(8, 2),
  max_score numeric(8, 2) not null default 0 check (max_score >= 0),
  foreign key (exam_id, subject_code)
    references public.cbt_exams(id, subject_code) on delete restrict,
  check (score is null or (score >= 0 and score <= max_score)),
  check (
    (status = 'in_progress' and submitted_at is null and score is null)
    or (status = 'submitted' and submitted_at is not null and score is not null)
  ),
  unique (id, subject_code)
);

create table public.attempt_questions (
  attempt_id uuid not null,
  question_version_id uuid not null,
  subject_code text not null,
  position integer not null check (position > 0),
  marks numeric(6, 2) not null check (marks > 0),
  primary key (attempt_id, question_version_id),
  unique (attempt_id, position),
  foreign key (attempt_id, subject_code)
    references public.exam_attempts(id, subject_code) on delete cascade,
  foreign key (question_version_id, subject_code)
    references public.question_versions(id, subject_code)
);

create table public.attempt_answers (
  attempt_id uuid not null,
  question_version_id uuid not null,
  selected_option_key text,
  saved_at timestamptz not null default now(),
  primary key (attempt_id, question_version_id),
  foreign key (attempt_id, question_version_id)
    references public.attempt_questions(attempt_id, question_version_id) on delete cascade,
  foreign key (question_version_id, selected_option_key)
    references public.question_options(version_id, option_key)
);

create table public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  completion_percent smallint not null default 0 check (completion_percent between 0 and 100),
  first_accessed_at timestamptz not null default now(),
  last_accessed_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (user_id, lesson_id)
);

create table public.flashcard_reviews (
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  flashcard_id uuid not null references public.flashcards(id) on delete cascade,
  mastery_rating smallint not null check (mastery_rating between 1 and 5),
  reviewed_at timestamptz not null default now(),
  next_due_at timestamptz,
  primary key (user_id, flashcard_id)
);

create table public.access_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  amount_kobo integer not null default 400000 check (amount_kobo = 400000),
  currency text not null default 'NGN' check (currency = 'NGN'),
  status public.access_order_status not null default 'pending',
  transaction_reference text,
  receipt_object_path text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  rejection_reason text,
  created_at timestamptz not null default now(),
  check (
    (status = 'verified' and reviewed_at is not null
      and reviewed_by is not null and submitted_at is not null
      and receipt_object_path is not null)
    or status <> 'verified'
  ),
  unique (id, user_id)
);

create unique index access_orders_one_pending_per_user
  on public.access_orders(user_id) where status = 'pending';

create table public.student_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_code text not null default 'full_access' check (product_code = 'full_access'),
  status public.entitlement_status not null default 'active',
  source_order_id uuid not null unique,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  unique (user_id, product_code),
  check (
    (status = 'active' and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null)
  ),
  check (expires_at is null or expires_at > starts_at),
  foreign key (source_order_id, user_id)
    references public.access_orders(id, user_id) on delete restrict
);

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index lessons_status_subtopic_idx on public.lessons(status, subtopic_id);
create index question_versions_status_subject_idx
  on public.question_versions(status, subject_code, subtopic_id);
create index paper_questions_question_idx on public.paper_questions(question_version_id);
create index exam_papers_lookup_idx
  on public.exam_papers(board_code, exam_year, subject_code, status);
create index cbt_exams_listing_idx on public.cbt_exams(status, subject_code);
create index exam_attempts_user_started_idx on public.exam_attempts(user_id, started_at desc);
create index access_orders_user_status_idx on public.access_orders(user_id, status);
create index student_entitlements_active_idx
  on public.student_entitlements(user_id, product_code, starts_at)
  where status = 'active';
create index audit_log_entity_idx
  on public.admin_audit_log(entity_type, entity_id, created_at desc);

insert into public.exam_boards(code, name) values
  ('JAMB', 'Joint Admissions and Matriculation Board'),
  ('WAEC', 'West African Examinations Council'),
  ('NECO', 'National Examinations Council');

insert into public.subjects(code, name, sort_order) values
  ('PHYSICS', 'Physics', 1),
  ('CHEMISTRY', 'Chemistry', 2),
  ('BIOLOGY', 'Biology', 3),
  ('MATHEMATICS', 'Mathematics', 4);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = (select auth.uid()) and role = 'admin'
  );
$$;

create function public.is_content_editor()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = (select auth.uid()) and role = 'content_editor'
  );
$$;

create function public.has_active_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.student_entitlements
    where user_id = (select auth.uid())
      and product_code = 'full_access'
      and status = 'active'
      and starts_at <= now()
      and (expires_at is null or expires_at > now())
  );
$$;

create function public.require_verified_entitlement_order()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.access_orders
    where id = new.source_order_id
      and user_id = new.user_id
      and status = 'verified'
  ) then
    raise exception 'An entitlement requires a verified order belonging to the same user';
  end if;
  return new;
end;
$$;

create trigger entitlement_verified_order_guard
  before insert or update of user_id, source_order_id on public.student_entitlements
  for each row execute function public.require_verified_entitlement_order();

create function public.validate_current_exam_year()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.exam_year > extract(year from current_date)::integer then
    raise exception 'Exam year cannot be in the future';
  end if;
  return new;
end;
$$;

create trigger exam_papers_year_guard
  before insert or update of exam_year on public.exam_papers
  for each row execute function public.validate_current_exam_year();

create trigger cbt_exams_year_guard
  before insert or update of exam_year on public.cbt_exams
  for each row
  when (new.exam_year is not null)
  execute function public.validate_current_exam_year();

create function public.guard_question_version_immutability()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'published' then
      raise exception 'Published question versions cannot be deleted';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    if old.status = 'published' then
      raise exception 'Published question versions are immutable; create a new version';
    end if;
    if new.status = 'published' and not public.is_admin() then
      raise exception 'Only an admin can publish question versions';
    end if;
    if new.status = 'published' then
      if new.rights_status = 'pending' then
        raise exception 'Question rights must be reviewed before publication';
      end if;
      if (select count(*) from public.question_options where version_id = new.id) < 2
         or not exists (
           select 1 from public.question_solutions where version_id = new.id
         ) then
        raise exception 'A published question needs at least two options and a solution';
      end if;
    end if;
    return new;
  end if;

  if new.status = 'published' and not public.is_admin() then
    raise exception 'Only an admin can publish question versions';
  end if;
  if new.status = 'published' then
    if new.rights_status = 'pending' then
      raise exception 'Question rights must be reviewed before publication';
    end if;
    if (select count(*) from public.question_options where version_id = new.id) < 2
       or not exists (
         select 1 from public.question_solutions where version_id = new.id
       ) then
      raise exception 'A published question needs at least two options and a solution';
    end if;
  end if;
  return new;
end;
$$;

create trigger question_version_guard
  before insert or update or delete on public.question_versions
  for each row execute function public.guard_question_version_immutability();

create function public.guard_question_child_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_version_id uuid;
begin
  if tg_op = 'UPDATE' then
    if exists (
      select 1 from public.question_versions
      where id = old.version_id and status = 'published'
    ) then
      raise exception 'Options and solutions for published question versions are immutable';
    end if;
  end if;

  v_version_id := case when tg_op = 'DELETE' then old.version_id else new.version_id end;
  if exists (
    select 1 from public.question_versions
    where id = v_version_id and status = 'published'
  ) then
    raise exception 'Options and solutions for published question versions are immutable';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger question_options_guard
  before insert or update or delete on public.question_options
  for each row execute function public.guard_question_child_mutation();

create trigger question_solutions_guard
  before insert or update or delete on public.question_solutions
  for each row execute function public.guard_question_child_mutation();

create function public.set_publication_timestamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;

create function public.audit_content_publication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'published' then
    if tg_op = 'INSERT' then
      insert into public.admin_audit_log(actor_user_id, action, entity_type, entity_id, details)
      values ((select auth.uid()), 'content_published', tg_table_name, new.id::text,
              jsonb_build_object('status', new.status));
    elsif old.status is distinct from new.status then
      insert into public.admin_audit_log(actor_user_id, action, entity_type, entity_id, details)
      values ((select auth.uid()), 'content_published', tg_table_name, new.id::text,
              jsonb_build_object('status', new.status));
    end if;
  end if;
  return new;
end;
$$;

create trigger lessons_publication_timestamp before insert or update on public.lessons
  for each row execute function public.set_publication_timestamp();
create trigger papers_publication_timestamp before insert or update on public.exam_papers
  for each row execute function public.set_publication_timestamp();
create trigger questions_publication_timestamp before insert or update on public.question_versions
  for each row execute function public.set_publication_timestamp();
create trigger flashcards_publication_timestamp before insert or update on public.flashcards
  for each row execute function public.set_publication_timestamp();
create trigger mnemonics_publication_timestamp before insert or update on public.mnemonics
  for each row execute function public.set_publication_timestamp();
create trigger cbt_exams_publication_timestamp before insert or update on public.cbt_exams
  for each row execute function public.set_publication_timestamp();

create trigger lessons_publication_audit after insert or update on public.lessons
  for each row execute function public.audit_content_publication();
create trigger papers_publication_audit after insert or update on public.exam_papers
  for each row execute function public.audit_content_publication();
create trigger questions_publication_audit after insert or update on public.question_versions
  for each row execute function public.audit_content_publication();
create trigger flashcards_publication_audit after insert or update on public.flashcards
  for each row execute function public.audit_content_publication();
create trigger mnemonics_publication_audit after insert or update on public.mnemonics
  for each row execute function public.audit_content_publication();
create trigger cbt_exams_publication_audit after insert or update on public.cbt_exams
  for each row execute function public.audit_content_publication();

create function public.start_exam_attempt(p_exam_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exam public.cbt_exams%rowtype;
  v_attempt_id uuid;
  v_count integer;
begin
  if auth.uid() is null or not public.has_active_access() then
    raise exception 'Active student access is required';
  end if;

  select * into v_exam
  from public.cbt_exams
  where id = p_exam_id and status = 'published'
  for share;

  if not found then
    raise exception 'Published exam not found';
  end if;
  if v_exam.available_from is not null and now() < v_exam.available_from then
    raise exception 'Exam is not available yet';
  end if;
  if v_exam.available_until is not null and now() >= v_exam.available_until then
    raise exception 'Exam is no longer available';
  end if;

  insert into public.exam_attempts(user_id, exam_id, subject_code, expires_at)
  values (auth.uid(), v_exam.id, v_exam.subject_code,
          now() + make_interval(secs => v_exam.duration_seconds))
  returning id into v_attempt_id;

  if v_exam.selection_mode = 'fixed' then
    select count(*) into v_count
    from public.cbt_exam_questions ceq
    join public.question_versions qv on qv.id = ceq.question_version_id
    where ceq.exam_id = v_exam.id and qv.status = 'published';

    if v_count <> v_exam.question_count then
      raise exception 'Published exam does not have the configured number of published questions';
    end if;

    insert into public.attempt_questions(attempt_id, question_version_id, subject_code, position, marks)
    select v_attempt_id, ceq.question_version_id, ceq.subject_code, ceq.position, ceq.marks
    from public.cbt_exam_questions ceq
    join public.question_versions qv on qv.id = ceq.question_version_id
    where ceq.exam_id = v_exam.id and qv.status = 'published'
    order by ceq.position;
  else
    with candidates as (
      select distinct qv.id
      from public.question_versions qv
      join public.paper_questions pq on pq.question_version_id = qv.id
      join public.exam_papers ep on ep.id = pq.paper_id
      where qv.status = 'published'
        and qv.subject_code = v_exam.subject_code
        and ep.status = 'published'
        and (v_exam.board_code is null or ep.board_code = v_exam.board_code)
        and (v_exam.exam_year is null or ep.exam_year = v_exam.exam_year)
    ),
    picked as (
      select id from candidates order by random() limit v_exam.question_count
    ),
    ranked as (
      select qv.id, qv.subject_code,
             row_number() over (order by random())::integer as position
      from picked p
      join public.question_versions qv on qv.id = p.id
    )
    insert into public.attempt_questions(attempt_id, question_version_id, subject_code, position, marks)
    select v_attempt_id, id, subject_code, position, 1
    from ranked;

    get diagnostics v_count = row_count;
    if v_count <> v_exam.question_count then
      raise exception 'Not enough published questions are available for this exam';
    end if;
  end if;

  update public.exam_attempts
  set max_score = (select coalesce(sum(marks), 0)
                   from public.attempt_questions where attempt_id = v_attempt_id)
  where id = v_attempt_id;

  return v_attempt_id;
end;
$$;

create function public.save_attempt_answer(
  p_attempt_id uuid,
  p_question_version_id uuid,
  p_option_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.exam_attempts%rowtype;
begin
  select * into v_attempt
  from public.exam_attempts
  where id = p_attempt_id and user_id = auth.uid()
  for update;
  if not found then
    raise exception 'Attempt not found';
  end if;
  if v_attempt.status <> 'in_progress' or now() >= v_attempt.expires_at then
    raise exception 'Attempt is no longer accepting answers';
  end if;
  if not exists (
    select 1 from public.attempt_questions
    where attempt_id = p_attempt_id and question_version_id = p_question_version_id
  ) then
    raise exception 'Question is not part of this attempt';
  end if;

  insert into public.attempt_answers(attempt_id, question_version_id, selected_option_key, saved_at)
  values (p_attempt_id, p_question_version_id, p_option_key, now())
  on conflict (attempt_id, question_version_id)
  do update set selected_option_key = excluded.selected_option_key, saved_at = excluded.saved_at;
end;
$$;

create function public.submit_exam_attempt(p_attempt_id uuid)
returns table (attempt_status public.attempt_status, score numeric, max_score numeric, submitted_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.exam_attempts%rowtype;
  v_score numeric(8, 2);
begin
  select * into v_attempt
  from public.exam_attempts
  where id = p_attempt_id and user_id = auth.uid()
  for update;
  if not found then
    raise exception 'Attempt not found';
  end if;
  if v_attempt.status <> 'in_progress' then
    raise exception 'Attempt has already been submitted';
  end if;

  select coalesce(sum(aq.marks), 0)::numeric(8, 2)
    into v_score
  from public.attempt_questions aq
  join public.question_solutions solution
    on solution.version_id = aq.question_version_id
  join public.attempt_answers answer
    on answer.attempt_id = aq.attempt_id
   and answer.question_version_id = aq.question_version_id
   and answer.selected_option_key = solution.correct_option_key
  where aq.attempt_id = p_attempt_id;

  update public.exam_attempts
  set status = 'submitted',
      submitted_at = least(now(), expires_at),
      score = v_score
  where id = p_attempt_id;

  return query
  select a.status, a.score, a.max_score, a.submitted_at
  from public.exam_attempts a where a.id = p_attempt_id;
end;
$$;

create function public.get_attempt_review(p_attempt_id uuid)
returns table (
  question_version_id uuid,
  question_order integer,
  stem_markdown text,
  options jsonb,
  selected_option_key text,
  correct_option_key text,
  explanation_markdown text,
  marks numeric,
  awarded_marks numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.exam_attempts%rowtype;
  v_policy public.exam_review_policy;
  v_available_until timestamptz;
begin
  select * into v_attempt
  from public.exam_attempts
  where id = p_attempt_id and user_id = auth.uid();
  if not found or v_attempt.status <> 'submitted' then
    raise exception 'Submitted attempt not found';
  end if;

  select e.review_policy, e.available_until into v_policy, v_available_until
  from public.cbt_exams e where e.id = v_attempt.exam_id;
  if v_policy = 'after_window' and (v_available_until is null or now() < v_available_until) then
    raise exception 'Review is not available yet';
  end if;

  return query
  select aq.question_version_id,
         aq.position,
         qv.stem_markdown,
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'key', qo.option_key, 'text', qo.body_markdown
           ) order by qo.position)
           from public.question_options qo
           where qo.version_id = qv.id
         ), '[]'::jsonb),
         answer.selected_option_key,
         solution.correct_option_key,
         solution.explanation_markdown,
         aq.marks,
         case when answer.selected_option_key = solution.correct_option_key
              then aq.marks else 0 end::numeric
  from public.attempt_questions aq
  join public.question_versions qv on qv.id = aq.question_version_id
  join public.question_solutions solution on solution.version_id = qv.id
  left join public.attempt_answers answer
    on answer.attempt_id = aq.attempt_id
   and answer.question_version_id = aq.question_version_id
  where aq.attempt_id = p_attempt_id
  order by aq.position;
end;
$$;

create function public.create_access_order()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if public.has_active_access() then
    raise exception 'Account already has active access';
  end if;

  select id into v_order_id
  from public.access_orders
  where user_id = auth.uid() and status = 'pending';
  if found then
    return v_order_id;
  end if;

  insert into public.access_orders(user_id)
  values (auth.uid())
  returning id into v_order_id;
  return v_order_id;
end;
$$;

create function public.submit_access_order(
  p_order_id uuid,
  p_receipt_object_path text,
  p_transaction_reference text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.access_orders%rowtype;
begin
  select * into v_order
  from public.access_orders
  where id = p_order_id and user_id = auth.uid()
  for update;
  if not found
     or v_order.status not in ('pending', 'rejected')
     or (v_order.status = 'pending' and v_order.receipt_object_path is not null) then
    raise exception 'Order cannot be submitted';
  end if;
  if p_receipt_object_path is null
     or split_part(p_receipt_object_path, '/', 1) <> auth.uid()::text
     or split_part(p_receipt_object_path, '/', 2) <> p_order_id::text
     or not exists (
       select 1 from storage.objects
       where bucket_id = 'payment-receipts' and name = p_receipt_object_path
     ) then
    raise exception 'Receipt must be uploaded to this order private receipt folder';
  end if;

  update public.access_orders
  set status = 'pending',
      receipt_object_path = p_receipt_object_path,
      transaction_reference = nullif(trim(p_transaction_reference), ''),
      submitted_at = now(),
      reviewed_at = null,
      reviewed_by = null,
      rejection_reason = null
  where id = p_order_id;
end;
$$;

create function public.review_access_order(
  p_order_id uuid,
  p_approve boolean,
  p_rejection_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.access_orders%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admin role required';
  end if;

  select * into v_order
  from public.access_orders
  where id = p_order_id and status = 'pending' and receipt_object_path is not null
  for update;
  if not found then
    raise exception 'Submitted pending order not found';
  end if;

  update public.access_orders
  set status = case when p_approve then 'verified'::public.access_order_status
                    else 'rejected'::public.access_order_status end,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      rejection_reason = case when p_approve then null
                              else nullif(trim(p_rejection_reason), '') end
  where id = p_order_id;

  if p_approve then
    insert into public.student_entitlements(user_id, source_order_id)
    values (v_order.user_id, v_order.id)
    on conflict (user_id, product_code) do update
      set status = 'active', source_order_id = excluded.source_order_id,
          starts_at = now(), expires_at = null, revoked_at = null, revoked_by = null;
  end if;

  insert into public.admin_audit_log(actor_user_id, action, entity_type, entity_id, details)
  values (auth.uid(),
          case when p_approve then 'access_order_verified' else 'access_order_rejected' end,
          'access_order', p_order_id::text,
          jsonb_build_object('user_id', v_order.user_id, 'amount_kobo', v_order.amount_kobo,
                             'rejection_reason', case when p_approve then null
                                                      else nullif(trim(p_rejection_reason), '') end));
end;
$$;

create function public.set_user_role(
  p_user_id uuid,
  p_role public.app_role,
  p_granted boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin role required';
  end if;

  if p_granted then
    insert into public.user_roles(user_id, role, granted_by)
    values (p_user_id, p_role, auth.uid())
    on conflict (user_id, role) do nothing;
  else
    if p_role = 'admin' then
      perform 1
      from public.user_roles
      where role = 'admin'
      order by user_id
      for update;
      if (select count(*) from public.user_roles where role = 'admin') <= 1 then
        raise exception 'Cannot revoke the last admin role';
      end if;
    end if;
    delete from public.user_roles where user_id = p_user_id and role = p_role;
  end if;

  insert into public.admin_audit_log(actor_user_id, action, entity_type, entity_id, details)
  values (auth.uid(),
          case when p_granted then 'role_granted' else 'role_revoked' end,
          'user_role', p_user_id::text, jsonb_build_object('role', p_role));
end;
$$;

create function public.revoke_student_access(p_user_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin role required';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception 'A reason is required to revoke student access';
  end if;

  update public.student_entitlements
  set status = 'revoked', revoked_at = now(), revoked_by = auth.uid()
  where user_id = p_user_id
    and product_code = 'full_access'
    and status = 'active';
  if not found then
    raise exception 'Active student entitlement not found';
  end if;

  insert into public.admin_audit_log(actor_user_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'student_access_revoked', 'student_entitlement', p_user_id::text,
          jsonb_build_object('reason', trim(p_reason)));
end;
$$;

alter table public.exam_boards enable row level security;
alter table public.subjects enable row level security;
alter table public.topics enable row level security;
alter table public.subtopics enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.lessons enable row level security;
alter table public.exam_papers enable row level security;
alter table public.questions enable row level security;
alter table public.question_versions enable row level security;
alter table public.question_options enable row level security;
alter table public.question_solutions enable row level security;
alter table public.paper_questions enable row level security;
alter table public.flashcards enable row level security;
alter table public.mnemonics enable row level security;
alter table public.cbt_exams enable row level security;
alter table public.cbt_exam_questions enable row level security;
alter table public.exam_attempts enable row level security;
alter table public.attempt_questions enable row level security;
alter table public.attempt_answers enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.flashcard_reviews enable row level security;
alter table public.access_orders enable row level security;
alter table public.student_entitlements enable row level security;
alter table public.admin_audit_log enable row level security;

create policy "catalogs are readable"
  on public.exam_boards for select to anon, authenticated using (active);
create policy "active subjects are readable"
  on public.subjects for select to anon, authenticated using (active);
create policy "topics are readable"
  on public.topics for select to anon, authenticated using (true);
create policy "subtopics are readable"
  on public.subtopics for select to anon, authenticated using (true);

create policy "profiles are private to their owner"
  on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "admins read profiles for payment support"
  on public.profiles for select to authenticated
  using (
    public.is_admin()
    and exists (
      select 1 from public.access_orders o
      where o.user_id = profiles.id
    )
  );
create policy "profile owners update their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "users can read their own roles"
  on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
create policy "admins manage user roles"
  on public.user_roles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "published lessons require access; staff can review drafts"
  on public.lessons for select to anon, authenticated
  using (
    (status = 'published' and public.has_active_access())
    or public.is_admin() or public.is_content_editor()
  );
create policy "editors create unpublished lessons"
  on public.lessons for insert to authenticated
  with check (
    (public.is_content_editor() and status in ('draft', 'review') and created_by = (select auth.uid()))
    or (public.is_admin())
  );
create policy "editors update only unpublished lessons"
  on public.lessons for update to authenticated
  using (
    public.is_admin()
    or (public.is_content_editor() and status in ('draft', 'review'))
  )
  with check (
    public.is_admin()
    or (public.is_content_editor() and status in ('draft', 'review'))
  );
create policy "staff delete unpublished lessons"
  on public.lessons for delete to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')));

create policy "published papers are listed"
  on public.exam_papers for select to anon, authenticated
  using (status = 'published' or public.is_admin() or public.is_content_editor());
create policy "staff create papers"
  on public.exam_papers for insert to authenticated
  with check (
    (public.is_content_editor() and status in ('draft', 'review') and created_by = (select auth.uid()))
    or public.is_admin()
  );
create policy "staff update papers"
  on public.exam_papers for update to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')))
  with check (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')));
create policy "staff delete unpublished papers"
  on public.exam_papers for delete to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')));

create policy "question identities are staff only"
  on public.questions for select to authenticated using (public.is_admin() or public.is_content_editor());
create policy "staff create question identities"
  on public.questions for insert to authenticated
  with check ((public.is_admin() or public.is_content_editor()) and created_by = (select auth.uid()));
create policy "staff manage question identities"
  on public.questions for update to authenticated
  using (public.is_admin() or public.is_content_editor())
  with check (public.is_admin() or public.is_content_editor());
create policy "staff delete question identities"
  on public.questions for delete to authenticated using (public.is_admin() or public.is_content_editor());

create policy "published questions require access; staff can review drafts"
  on public.question_versions for select to anon, authenticated
  using (
    (status = 'published' and public.has_active_access())
    or public.is_admin() or public.is_content_editor()
  );
create policy "editors create unpublished question versions"
  on public.question_versions for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and ((public.is_content_editor() and status in ('draft', 'review')) or public.is_admin())
  );
create policy "editors update unpublished question versions"
  on public.question_versions for update to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')))
  with check (
    (public.is_admin() and status in ('draft', 'review', 'published', 'archived'))
    or (public.is_content_editor() and status in ('draft', 'review'))
  );
create policy "staff delete unpublished question versions"
  on public.question_versions for delete to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')));

create policy "published options require access; staff can review drafts"
  on public.question_options for select to anon, authenticated
  using (
    exists (
      select 1 from public.question_versions qv
      where qv.id = version_id and qv.status = 'published' and public.has_active_access()
    )
    or public.is_admin() or public.is_content_editor()
  );
create policy "staff manage options on unpublished questions"
  on public.question_options for all to authenticated
  using (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.question_versions qv
      where qv.id = version_id and qv.status in ('draft', 'review')
    ))
  )
  with check (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.question_versions qv
      where qv.id = version_id and qv.status in ('draft', 'review')
    ))
  );
create policy "solutions are staff only"
  on public.question_solutions for all to authenticated
  using (public.is_admin() or public.is_content_editor())
  with check (public.is_admin() or public.is_content_editor());

create policy "paper questions require student access or staff role"
  on public.paper_questions for select to anon, authenticated
  using (
    exists (
      select 1 from public.exam_papers ep
      join public.question_versions qv on qv.id = paper_questions.question_version_id
      where ep.id = paper_questions.paper_id
        and ep.status = 'published'
        and qv.status = 'published'
        and public.has_active_access()
    )
    or public.is_admin() or public.is_content_editor()
  );
create policy "staff create paper questions for unpublished papers"
  on public.paper_questions for insert to authenticated
  with check (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.exam_papers ep
      where ep.id = paper_questions.paper_id and ep.status in ('draft', 'review')
    ))
  );
create policy "staff update paper questions for unpublished papers"
  on public.paper_questions for update to authenticated
  using (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.exam_papers ep
      where ep.id = paper_questions.paper_id and ep.status in ('draft', 'review')
    ))
  )
  with check (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.exam_papers ep
      where ep.id = paper_questions.paper_id and ep.status in ('draft', 'review')
    ))
  );
create policy "staff delete paper questions for unpublished papers"
  on public.paper_questions for delete to authenticated
  using (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.exam_papers ep
      where ep.id = paper_questions.paper_id and ep.status in ('draft', 'review')
    ))
  );

create policy "published flashcards require access; staff can review drafts"
  on public.flashcards for select to anon, authenticated
  using (
    (status = 'published' and public.has_active_access())
    or public.is_admin() or public.is_content_editor()
  );
create policy "staff manage flashcards"
  on public.flashcards for all to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')))
  with check (
    public.is_admin()
    or (public.is_content_editor() and status in ('draft', 'review') and created_by = (select auth.uid()))
  );
create policy "published mnemonics require access; staff can review drafts"
  on public.mnemonics for select to anon, authenticated
  using (
    (status = 'published' and public.has_active_access())
    or public.is_admin() or public.is_content_editor()
  );
create policy "staff manage mnemonics"
  on public.mnemonics for all to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')))
  with check (
    public.is_admin()
    or (public.is_content_editor() and status in ('draft', 'review') and created_by = (select auth.uid()))
  );

create policy "published CBT exams require access; staff can review drafts"
  on public.cbt_exams for select to anon, authenticated
  using (
    (status = 'published' and public.has_active_access())
    or public.is_admin() or public.is_content_editor()
  );
create policy "staff manage CBT exams"
  on public.cbt_exams for all to authenticated
  using (public.is_admin() or (public.is_content_editor() and status in ('draft', 'review')))
  with check (
    public.is_admin()
    or (public.is_content_editor() and status in ('draft', 'review') and created_by = (select auth.uid()))
  );
create policy "published CBT items require access"
  on public.cbt_exam_questions for select to anon, authenticated
  using (
    exists (
      select 1 from public.cbt_exams exam
      join public.question_versions qv on qv.id = cbt_exam_questions.question_version_id
      where exam.id = cbt_exam_questions.exam_id
        and exam.status = 'published'
        and qv.status = 'published'
        and public.has_active_access()
    )
    or public.is_admin() or public.is_content_editor()
  );
create policy "staff create CBT questions for unpublished exams"
  on public.cbt_exam_questions for insert to authenticated
  with check (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.cbt_exams exam
      where exam.id = cbt_exam_questions.exam_id and exam.status in ('draft', 'review')
    ))
  );
create policy "staff update CBT questions for unpublished exams"
  on public.cbt_exam_questions for update to authenticated
  using (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.cbt_exams exam
      where exam.id = cbt_exam_questions.exam_id and exam.status in ('draft', 'review')
    ))
  )
  with check (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.cbt_exams exam
      where exam.id = cbt_exam_questions.exam_id and exam.status in ('draft', 'review')
    ))
  );
create policy "staff delete CBT questions for unpublished exams"
  on public.cbt_exam_questions for delete to authenticated
  using (
    public.is_admin()
    or (public.is_content_editor() and exists (
      select 1 from public.cbt_exams exam
      where exam.id = cbt_exam_questions.exam_id and exam.status in ('draft', 'review')
    ))
  );

create policy "students read their own attempts"
  on public.exam_attempts for select to authenticated using (user_id = (select auth.uid()));
create policy "students read their own attempt questions"
  on public.attempt_questions for select to authenticated
  using (exists (
    select 1 from public.exam_attempts a
    where a.id = attempt_id and a.user_id = (select auth.uid())
  ));
create policy "students read their own saved answers"
  on public.attempt_answers for select to authenticated
  using (exists (
    select 1 from public.exam_attempts a
    where a.id = attempt_id and a.user_id = (select auth.uid())
  ));

create policy "students manage their own lesson progress"
  on public.lesson_progress for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and public.has_active_access()
    and exists (select 1 from public.lessons l where l.id = lesson_id and l.status = 'published')
  );
create policy "students manage their own flashcard reviews"
  on public.flashcard_reviews for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and public.has_active_access()
    and exists (select 1 from public.flashcards f where f.id = flashcard_id and f.status = 'published')
  );

create policy "students and admins read access orders"
  on public.access_orders for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
create policy "students and admins read entitlements"
  on public.student_entitlements for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
create policy "admins read audit log"
  on public.admin_audit_log for select to authenticated using (public.is_admin());

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger lessons_updated_at before update on public.lessons
  for each row execute function public.set_updated_at();
create trigger exam_papers_updated_at before update on public.exam_papers
  for each row execute function public.set_updated_at();
create trigger question_versions_updated_at before update on public.question_versions
  for each row execute function public.set_updated_at();
create trigger flashcards_updated_at before update on public.flashcards
  for each row execute function public.set_updated_at();
create trigger mnemonics_updated_at before update on public.mnemonics
  for each row execute function public.set_updated_at();
create trigger cbt_exams_updated_at before update on public.cbt_exams
  for each row execute function public.set_updated_at();

revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public to anon, authenticated;
grant select on public.exam_boards, public.subjects, public.topics, public.subtopics,
  public.exam_papers, public.lessons, public.question_versions, public.question_options,
  public.paper_questions, public.flashcards, public.mnemonics, public.cbt_exams,
  public.cbt_exam_questions to anon, authenticated;
grant select on public.profiles, public.user_roles, public.exam_attempts,
  public.attempt_questions, public.attempt_answers, public.lesson_progress,
  public.flashcard_reviews, public.access_orders, public.student_entitlements,
  public.admin_audit_log, public.questions, public.question_solutions to authenticated;
grant update (display_name, phone) on public.profiles to authenticated;
grant insert, update, delete on public.lesson_progress, public.flashcard_reviews to authenticated;
grant insert, update, delete on public.lessons, public.exam_papers, public.questions,
  public.question_versions, public.question_options, public.question_solutions,
  public.paper_questions, public.flashcards, public.mnemonics, public.cbt_exams,
  public.cbt_exam_questions to authenticated;

revoke execute on function public.set_updated_at(),
  public.handle_new_user(),
  public.require_verified_entitlement_order(),
  public.validate_current_exam_year(),
  public.guard_question_version_immutability(),
  public.guard_question_child_mutation(),
  public.set_publication_timestamp(),
  public.audit_content_publication()
from public;

revoke all on function public.is_admin() from public;
revoke all on function public.is_content_editor() from public;
revoke all on function public.has_active_access() from public;
revoke all on function public.start_exam_attempt(uuid) from public;
revoke all on function public.save_attempt_answer(uuid, uuid, text) from public;
revoke all on function public.submit_exam_attempt(uuid) from public;
revoke all on function public.get_attempt_review(uuid) from public;
revoke all on function public.create_access_order() from public;
revoke all on function public.submit_access_order(uuid, text, text) from public;
revoke all on function public.review_access_order(uuid, boolean, text) from public;
revoke all on function public.set_user_role(uuid, public.app_role, boolean) from public;
revoke all on function public.revoke_student_access(uuid, text) from public;

grant execute on function public.is_admin(), public.is_content_editor(),
  public.has_active_access() to anon, authenticated;
grant execute on function public.start_exam_attempt(uuid),
  public.save_attempt_answer(uuid, uuid, text),
  public.submit_exam_attempt(uuid),
  public.get_attempt_review(uuid),
  public.create_access_order(),
  public.submit_access_order(uuid, text, text),
  public.review_access_order(uuid, boolean, text),
  public.set_user_role(uuid, public.app_role, boolean),
  public.revoke_student_access(uuid, text) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-receipts',
  'payment-receipts',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table storage.objects enable row level security;

create policy "students upload receipts for their own orders"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'payment-receipts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.access_orders o
      where o.id::text = (storage.foldername(name))[2]
        and o.user_id = (select auth.uid())
        and (o.status = 'rejected'
          or (o.status = 'pending' and o.receipt_object_path is null))
    )
  );
create policy "students and admins read submitted receipts"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'payment-receipts'
    and (
      exists (
        select 1 from public.access_orders o
        where o.receipt_object_path = name and o.user_id = (select auth.uid())
      )
      or public.is_admin()
    )
  );

comment on table public.question_solutions is
  'Never grant direct student SELECT. Return answer keys only through get_attempt_review after server-checked submission.';
comment on table public.admin_audit_log is
  'Append-only audit records for privileged payment and role workflows.';
