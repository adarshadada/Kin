-- Safe to rerun. Run in Supabase SQL Editor.
create table if not exists profiles(
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  bio text not null default '' check (length(bio) <= 160),
  created_at timestamptz not null default now());
create table if not exists posts(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references profiles on delete cascade,
  body text not null default '' check (length(body) <= 500),
  media_url text,
  created_at timestamptz not null default now(),
  check (length(body) > 0 or media_url is not null));
create index if not exists posts_user_time on posts(user_id, created_at desc);
create table if not exists likes(
  user_id uuid not null default auth.uid() references profiles on delete cascade,
  post_id uuid not null references posts on delete cascade,
  primary key (user_id, post_id));
create table if not exists comments(
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts on delete cascade,
  user_id uuid not null default auth.uid() references profiles on delete cascade,
  body text not null check (length(body) between 1 and 300),
  created_at timestamptz not null default now());
create index if not exists comments_post on comments(post_id, created_at);
create table if not exists follows(
  follower_id uuid not null default auth.uid() references profiles on delete cascade,
  followee_id uuid not null references profiles on delete cascade,
  primary key (follower_id, followee_id), check (follower_id <> followee_id));
create table if not exists messages(
  id bigint generated always as identity primary key,
  sender_id uuid not null default auth.uid() references profiles on delete cascade,
  recipient_id uuid not null references profiles on delete cascade,
  body text not null check (length(body) between 1 and 1000),
  created_at timestamptz not null default now());
create index if not exists messages_pair on messages(sender_id, recipient_id, created_at desc);
create table if not exists reports(
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references profiles on delete cascade,
  post_id uuid not null references posts on delete cascade,
  reason text not null default '',
  created_at timestamptz not null default now());

create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, username) values (new.id, lower(new.raw_user_meta_data->>'username'));
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies where schemaname='public' loop
    execute format('drop policy %I on %I', r.policyname, r.tablename);
  end loop;
end $$;

alter table profiles enable row level security;
alter table posts enable row level security;
alter table likes enable row level security;
alter table comments enable row level security;
alter table follows enable row level security;
alter table messages enable row level security;
alter table reports enable row level security;

create policy p_read on profiles for select to authenticated using (true);
create policy p_upd on profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy posts_read on posts for select to authenticated using (true);
create policy posts_ins on posts for insert to authenticated with check (user_id = auth.uid());
create policy posts_upd on posts for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy posts_del on posts for delete to authenticated using (user_id = auth.uid());
create policy likes_read on likes for select to authenticated using (true);
create policy likes_ins on likes for insert to authenticated with check (user_id = auth.uid());
create policy likes_del on likes for delete to authenticated using (user_id = auth.uid());
create policy com_read on comments for select to authenticated using (true);
create policy com_ins on comments for insert to authenticated with check (user_id = auth.uid());
create policy com_del on comments for delete to authenticated using (user_id = auth.uid());
create policy fol_read on follows for select to authenticated using (true);
create policy fol_ins on follows for insert to authenticated with check (follower_id = auth.uid());
create policy fol_del on follows for delete to authenticated using (follower_id = auth.uid());
create policy msg_read on messages for select to authenticated using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy msg_ins on messages for insert to authenticated with check (sender_id = auth.uid());
create policy rep_ins on reports for insert to authenticated with check (reporter_id = auth.uid());

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
drop policy if exists media_ins on storage.objects;
create policy media_ins on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists media_del on storage.objects;
create policy media_del on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

do $$ begin
  alter publication supabase_realtime add table messages;
exception when duplicate_object then null; end $$;
