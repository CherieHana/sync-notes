-- 跨端同步备忘录 —— Supabase 服务端结构
-- 用法：Supabase 控制台 → SQL Editor → 新建查询 → 粘贴全文 → Run
-- 本脚本可重复执行，不会破坏已有数据。

-- ---------------------------------------------------------------------------
-- 1. 笔记表
-- ---------------------------------------------------------------------------
create table if not exists public.notes (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body           text not null default '',
  version        integer not null default 1,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  last_device_id text
);

comment on table public.notes is '纯文本笔记；正文首行即标题，标题由客户端派生';
comment on column public.notes.version is '乐观锁版本号，客户端每次写入递增加一';
comment on column public.notes.deleted_at is '软删除标记，非空即视为已删除';
comment on column public.notes.last_device_id is '最后一次写入的设备标识，用于回显过滤';

create index if not exists notes_user_updated_idx
  on public.notes (user_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- 2. 行级权限：只能读写属于自己的行
-- ---------------------------------------------------------------------------
alter table public.notes enable row level security;

drop policy if exists notes_select_own on public.notes;
create policy notes_select_own on public.notes
  for select using (auth.uid() = user_id);

drop policy if exists notes_insert_own on public.notes;
create policy notes_insert_own on public.notes
  for insert with check (auth.uid() = user_id);

drop policy if exists notes_update_own on public.notes;
create policy notes_update_own on public.notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists notes_delete_own on public.notes;
create policy notes_delete_own on public.notes
  for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.notes to authenticated;

-- ---------------------------------------------------------------------------
-- 3. 更新时间以服务端时钟为准
--    客户端只负责把 version 递增加一，updated_at 一律由触发器覆盖，
--    这样手机和电脑的系统时间不一致也不会影响增量同步。
-- ---------------------------------------------------------------------------
create or replace function public.notes_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists notes_touch_updated_at on public.notes;
create trigger notes_touch_updated_at
  before update on public.notes
  for each row
  execute function public.notes_touch_updated_at();

-- ---------------------------------------------------------------------------
-- 4. 实时推送
--    replica identity full 让更新/删除事件带上完整旧行，
--    Realtime 才能在 RLS 下正确判断这条变更是否该推给当前用户。
-- ---------------------------------------------------------------------------
alter table public.notes replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notes'
  ) then
    alter publication supabase_realtime add table public.notes;
  end if;
end;
$$;
