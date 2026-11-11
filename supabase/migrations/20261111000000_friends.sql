-- Friends: profiles, mutual friendships made by invite code, short messages
-- that show on a friend's widget for 24 hours, and blocking/reporting
-- (App Store guideline 1.2).
--
-- Security model: every table has row level security, and the app's role
-- (`authenticated`) gets only the columns and actions it needs. Anything
-- that must touch two people's rows at once (accepting an invite,
-- unfriending) goes through a security definer function that checks the
-- caller itself.

-- ---------------------------------------------------------------------------
-- Profiles: the name friends see. Kept in sync with auth metadata, which the
-- app sets at sign-up (and after Sign in with Apple), so the app never
-- writes this table directly.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) between 1 and 30),
  created_at timestamptz not null default now()
);

create function public.sync_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Trimmed and capped so an unusual name can never fail a sign-up.
  new_name text := left(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 30);
begin
  insert into public.profiles (id, display_name)
  values (new.id, new_name)
  on conflict (id) do update
    set display_name = coalesce(excluded.display_name, public.profiles.display_name);
  return new;
end;
$$;

create trigger sync_profile
after insert or update of raw_user_meta_data on auth.users
for each row execute function public.sync_profile();

-- Accounts made before this migration.
insert into public.profiles (id, display_name)
select id, left(nullif(btrim(raw_user_meta_data ->> 'display_name'), ''), 30)
from auth.users
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Friendships: one row per direction, so each person owns their own settings
-- for a friend. Rows are only ever created or removed in pairs, by
-- redeem_invite() and remove_friend().
-- ---------------------------------------------------------------------------

create table public.friendships (
  user_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  -- Whether this friend's messages may replace the teaching on my widget.
  show_on_widget boolean not null default true,
  -- Quiets notifications from this friend (for later).
  muted boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

create index friendships_friend_id_idx on public.friendships (friend_id);

-- ---------------------------------------------------------------------------
-- Invites: single-use codes that expire after 7 days, created by
-- create_invite() and accepted by redeem_invite().
-- ---------------------------------------------------------------------------

create table public.invites (
  code text primary key,
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  redeemed_by uuid references public.profiles (id) on delete set null,
  redeemed_at timestamptz
);

create index invites_inviter_id_idx on public.invites (inviter_id);

-- ---------------------------------------------------------------------------
-- Messages: up to 80 characters, so they fit the lock screen widget. A shared
-- teaching copies its short text into body and keeps teaching_id for the
-- reference.
-- ---------------------------------------------------------------------------

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) <= 80 and btrim(body) <> ''),
  teaching_id text check (char_length(teaching_id) <= 40),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  -- Set by the recipient to take a message off their widget.
  hidden_at timestamptz,
  check (sender_id <> recipient_id)
);

create index messages_recipient_idx on public.messages (recipient_id, created_at desc);
create index messages_sender_idx on public.messages (sender_id);

-- ---------------------------------------------------------------------------
-- Blocks and reports.
-- ---------------------------------------------------------------------------

create table public.blocks (
  blocker_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index blocks_blocked_id_idx on public.blocks (blocked_id);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  reported_id uuid not null references public.profiles (id) on delete cascade,
  message_id uuid references public.messages (id) on delete set null,
  -- A copy, because messages expire and can be deleted before review.
  message_body text,
  reason text check (char_length(reason) <= 500),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row level security.
-- (select auth.uid()) is evaluated once per query rather than once per row.
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.invites enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

-- My own profile, and my friends'.
create policy "profiles: read self and friends" on public.profiles
for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1 from public.friendships f
    where f.user_id = (select auth.uid()) and f.friend_id = profiles.id
  )
);

create policy "friendships: read own" on public.friendships
for select to authenticated
using (user_id = (select auth.uid()));

create policy "friendships: change own settings" on public.friendships
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "invites: read own" on public.invites
for select to authenticated
using (inviter_id = (select auth.uid()));

create policy "invites: revoke own" on public.invites
for delete to authenticated
using (inviter_id = (select auth.uid()));

-- Senders see what they sent. Recipients see unexpired messages, and only
-- while still friends with the sender (unfriending or blocking hides them).
create policy "messages: read sent and received" on public.messages
for select to authenticated
using (
  sender_id = (select auth.uid())
  or (
    recipient_id = (select auth.uid())
    and expires_at > now()
    and exists (
      select 1 from public.friendships f
      where f.user_id = (select auth.uid()) and f.friend_id = messages.sender_id
    )
  )
);

-- Only to friends. Blocking removes the friendship, so it stops this too.
create policy "messages: send to friends" on public.messages
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.friendships f
    where f.user_id = (select auth.uid()) and f.friend_id = messages.recipient_id
  )
);

create policy "messages: recipient hides" on public.messages
for update to authenticated
using (recipient_id = (select auth.uid()))
with check (recipient_id = (select auth.uid()));

create policy "messages: sender unsends" on public.messages
for delete to authenticated
using (sender_id = (select auth.uid()));

create policy "blocks: read own" on public.blocks
for select to authenticated
using (blocker_id = (select auth.uid()));

create policy "blocks: block others" on public.blocks
for insert to authenticated
with check (blocker_id = (select auth.uid()));

create policy "blocks: unblock" on public.blocks
for delete to authenticated
using (blocker_id = (select auth.uid()));

create policy "reports: file" on public.reports
for insert to authenticated
with check (reporter_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Table and column privileges. Policies pick the rows; these pick the
-- actions and columns, so e.g. a sender can't backdate expires_at.
-- Signed-out requests (anon) get nothing.
-- ---------------------------------------------------------------------------

revoke all on public.profiles, public.friendships, public.invites,
  public.messages, public.blocks, public.reports
from anon, authenticated;

grant select on public.profiles to authenticated;
grant select on public.friendships to authenticated;
grant update (show_on_widget, muted) on public.friendships to authenticated;
grant select, delete on public.invites to authenticated;
grant select, delete on public.messages to authenticated;
grant insert (recipient_id, body, teaching_id) on public.messages to authenticated;
grant update (hidden_at) on public.messages to authenticated;
grant select, delete on public.blocks to authenticated;
grant insert (blocked_id) on public.blocks to authenticated;
grant insert (reported_id, message_id, reason) on public.reports to authenticated;

-- ---------------------------------------------------------------------------
-- Triggers that keep blocks and reports honest.
-- ---------------------------------------------------------------------------

-- Blocking ends the friendship in both directions.
create function public.unfriend_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.friendships
  where (user_id = new.blocker_id and friend_id = new.blocked_id)
     or (user_id = new.blocked_id and friend_id = new.blocker_id);
  return new;
end;
$$;

create trigger unfriend_on_block
after insert on public.blocks
for each row execute function public.unfriend_on_block();

-- A reported message must be one the reporter received; its sender and text
-- are filled in from the message itself rather than trusted from the app.
create function public.fill_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  reported_message public.messages;
begin
  if new.message_id is not null then
    select * into reported_message from public.messages where id = new.message_id;
    if not found or reported_message.recipient_id <> new.reporter_id then
      raise exception 'message_not_found' using errcode = 'P0001';
    end if;
    new.reported_id := reported_message.sender_id;
    new.message_body := reported_message.body;
  else
    new.message_body := null;
  end if;
  return new;
end;
$$;

create trigger fill_report
before insert on public.reports
for each row execute function public.fill_report();

-- ---------------------------------------------------------------------------
-- Functions the app calls (supabase.rpc). They run with elevated rights, so
-- each one checks who is calling. Errors use stable codes in the message
-- for the app to map to friendly text.
-- ---------------------------------------------------------------------------

-- Returns a new 8-character code, e.g. K7QXM2PA. No I, O, 0 or 1, so it's
-- easy to read aloud and type.
create function public.create_invite()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  new_code text;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = 'P0001';
  end if;
  if (
    select count(*) from public.invites
    where inviter_id = me and redeemed_at is null and expires_at > now()
  ) >= 20 then
    raise exception 'too_many_invites' using errcode = 'P0001';
  end if;

  loop
    -- 32 letters, so each random byte maps evenly onto one of them.
    bytes := extensions.gen_random_bytes(8);
    new_code := '';
    for i in 0..7 loop
      new_code := new_code || substr(alphabet, get_byte(bytes, i) % 32 + 1, 1);
    end loop;
    begin
      insert into public.invites (code, inviter_id) values (new_code, me);
      return new_code;
    exception when unique_violation then
      -- Astronomically unlikely; just draw again.
    end;
  end loop;
end;
$$;

-- Accepts a friend's invite and makes the friendship, in both directions.
-- Returns the new friend. Expired, used, unknown and blocked codes all give
-- the same error, so a code reveals nothing about who blocked whom.
create function public.redeem_invite(invite_code text)
returns table (friend_id uuid, display_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  invite public.invites;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = 'P0001';
  end if;

  -- Accept "k7qx-m2pa" as well as "K7QXM2PA".
  select * into invite from public.invites i
  where i.code = regexp_replace(upper(invite_code), '[^A-Z0-9]', '', 'g')
  for update;

  if not found
    or invite.redeemed_at is not null
    or invite.expires_at <= now()
    or exists (
      select 1 from public.blocks b
      where (b.blocker_id = me and b.blocked_id = invite.inviter_id)
         or (b.blocker_id = invite.inviter_id and b.blocked_id = me)
    )
  then
    raise exception 'invite_invalid' using errcode = 'P0001';
  end if;
  if invite.inviter_id = me then
    raise exception 'invite_own' using errcode = 'P0001';
  end if;

  insert into public.friendships (user_id, friend_id)
  values (me, invite.inviter_id), (invite.inviter_id, me)
  on conflict do nothing;

  update public.invites
  set redeemed_by = me, redeemed_at = now()
  where code = invite.code;

  return query
  select p.id, p.display_name from public.profiles p where p.id = invite.inviter_id;
end;
$$;

-- Ends a friendship for both people.
create function public.remove_friend(friend uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = 'P0001';
  end if;
  delete from public.friendships
  where (user_id = me and friend_id = friend)
     or (user_id = friend and friend_id = me);
end;
$$;

-- Supabase lets every role call new functions by default; narrow that.
revoke execute on function
  public.sync_profile(), public.unfriend_on_block(), public.fill_report(),
  public.create_invite(), public.redeem_invite(text), public.remove_friend(uuid)
from public, anon, authenticated;

grant execute on function
  public.create_invite(), public.redeem_invite(text), public.remove_friend(uuid)
to authenticated;
