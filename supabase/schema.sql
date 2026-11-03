-- Run in Supabase SQL Editor. All user content permissions enforced by RLS.
create extension if not exists pgcrypto;
create table if not exists public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
create table if not exists public.books (
 id uuid primary key default gen_random_uuid(), title text not null check(length(title) between 1 and 180),
 author text not null default 'Site Author', description text not null default '', genre text not null default 'Fiction',
 status text not null default 'Ongoing' check(status in ('Ongoing','Completed','Hiatus')),
 cover_url text, published boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.chapters (
 id uuid primary key default gen_random_uuid(), book_id uuid not null references public.books(id) on delete cascade,
 title text not null check(length(title) between 1 and 200), body text not null default '',
 position integer not null default 1, published boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(), chapter_id uuid not null references public.chapters(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 1500),
 created_at timestamptz not null default now()
);
create table if not exists public.bookmarks (
 user_id uuid not null references auth.users(id) on delete cascade,
 book_id uuid not null references public.books(id) on delete cascade,
 chapter_id uuid references public.chapters(id) on delete set null,
 updated_at timestamptz not null default now(), primary key(user_id,book_id)
);
create table if not exists public.chapter_views (
 chapter_id uuid primary key references public.chapters(id) on delete cascade,
 views bigint not null default 0
);
create index if not exists idx_chapters_book_position on public.chapters(book_id,position);
create index if not exists idx_comments_chapter on public.comments(chapter_id,created_at);
create index if not exists idx_bookmarks_user on public.bookmarks(user_id);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.admins where user_id = (select auth.uid()));
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;
alter table public.admins enable row level security;
alter table public.books enable row level security;
alter table public.chapters enable row level security;
alter table public.comments enable row level security;
alter table public.bookmarks enable row level security;
alter table public.chapter_views enable row level security;
create policy "admin read self" on public.admins for select to authenticated using(user_id=(select auth.uid()));
-- Never create an admins insert/update/delete policy. Grant admin via SQL editor only.
create policy "read published books" on public.books for select to anon,authenticated using(published or (select public.is_admin()));
create policy "admin insert books" on public.books for insert to authenticated with check((select public.is_admin()));
create policy "admin update books" on public.books for update to authenticated using((select public.is_admin())) with check((select public.is_admin()));
create policy "admin delete books" on public.books for delete to authenticated using((select public.is_admin()));
create policy "read published chapters" on public.chapters for select to anon,authenticated using(
 (published and exists(select 1 from public.books b where b.id=book_id and b.published)) or (select public.is_admin()));
create policy "admin insert chapters" on public.chapters for insert to authenticated with check((select public.is_admin()));
create policy "admin update chapters" on public.chapters for update to authenticated using((select public.is_admin())) with check((select public.is_admin()));
create policy "admin delete chapters" on public.chapters for delete to authenticated using((select public.is_admin()));
create policy "read comments" on public.comments for select to anon,authenticated using(
 exists(select 1 from public.chapters c join public.books b on b.id=c.book_id where c.id=chapter_id and c.published and b.published) or (select public.is_admin()));
create policy "write own comments" on public.comments for insert to authenticated with check(
 user_id=(select auth.uid()) and exists(select 1 from public.chapters c join public.books b on b.id=c.book_id where c.id=chapter_id and c.published and b.published));
create policy "delete own comments or admin" on public.comments for delete to authenticated using(user_id=(select auth.uid()) or (select public.is_admin()));
create policy "read own bookmarks" on public.bookmarks for select to authenticated using(user_id=(select auth.uid()));
create policy "insert own bookmarks" on public.bookmarks for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.books where id=book_id and published));
create policy "update own bookmarks" on public.bookmarks for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()) and exists(select 1 from public.books where id=book_id and published));
create policy "delete own bookmarks" on public.bookmarks for delete to authenticated using(user_id=(select auth.uid()));
create policy "read views" on public.chapter_views for select to anon,authenticated using(
 exists(select 1 from public.chapters c join public.books b on b.id=c.book_id where c.id=chapter_id and c.published and b.published) or (select public.is_admin()));
-- Anonymous public view counter. Throttle at edge/WAF in production; this is not unique readers.
create or replace function public.record_chapter_view(p_chapter_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if exists(select 1 from public.chapters c join public.books b on b.id=c.book_id where c.id=p_chapter_id and c.published and b.published) then
  insert into public.chapter_views(chapter_id,views) values(p_chapter_id,1)
  on conflict(chapter_id) do update set views=public.chapter_views.views+1;
 end if;
end $$;
revoke all on function public.record_chapter_view(uuid) from public;
grant execute on function public.record_chapter_view(uuid) to anon,authenticated;
-- Cover bucket: public read, admin-only uploads; avoid exposing service role key in browser.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('covers','covers',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "read covers" on storage.objects for select to anon,authenticated using(bucket_id='covers');
create policy "admin upload covers" on storage.objects for insert to authenticated with check(bucket_id='covers' and (select public.is_admin()));
create policy "admin change covers" on storage.objects for update to authenticated using(bucket_id='covers' and (select public.is_admin())) with check(bucket_id='covers' and (select public.is_admin()));
create policy "admin delete covers" on storage.objects for delete to authenticated using(bucket_id='covers' and (select public.is_admin()));
-- After creating YOUR admin user in Authentication > Users, run separately:
-- insert into public.admins(user_id) values ('YOUR-USER-UUID');
