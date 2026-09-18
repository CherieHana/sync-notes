-- 跨端同步备忘录 —— Supabase 服务端结构
-- 用法：Supabase 控制台 → SQL Editor → 新建查询 → 粘贴全文 → Run
-- 本脚本可重复执行，不会破坏已有数据。
--
-- 包含三张表（笔记、目录、图片）、行级权限、服务端时间触发器、
-- 实时推送发布，以及存图片用的私有存储桶。

-- ---------------------------------------------------------------------------
-- 1. 目录表
--    只有一层，不做嵌套。删除走软删除，笔记回到「未分类」由客户端处理，
--    所以这里不需要级联删除。
-- ---------------------------------------------------------------------------
create table if not exists public.folders (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name           text not null default '新目录',
  version        integer not null default 1,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  last_device_id text
);

comment on table public.folders is '单层目录，字段与同步语义和 notes 保持一致';

create index if not exists folders_user_updated_idx
  on public.folders (user_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- 2. 笔记表
--    body 是纯文本，首行即标题。锁定相关的三列只是「界面层的一道门」：
--    正文始终是明文，passphrase_hash 用来在客户端校验口令。
-- ---------------------------------------------------------------------------
create table if not exists public.notes (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body            text not null default '',
  folder_id       uuid references public.folders (id) on delete set null,
  locked          boolean not null default false,
  passphrase_hash text,
  passphrase_salt text,
  version         integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  last_device_id  text
);

-- 从旧版本升级上来的库，补上新增的列。已经是新结构时这些语句是空操作。
alter table public.notes
  add column if not exists folder_id uuid references public.folders (id) on delete set null;
alter table public.notes
  add column if not exists locked boolean not null default false;
alter table public.notes
  add column if not exists passphrase_hash text;
alter table public.notes
  add column if not exists passphrase_salt text;

comment on table public.notes is '纯文本笔记；正文首行即标题，标题由客户端派生';
comment on column public.notes.version is '乐观锁版本号，客户端每次写入递增加一';
comment on column public.notes.deleted_at is '软删除标记，非空即视为已删除';
comment on column public.notes.last_device_id is '最后一次写入的设备标识，用于回显过滤';
comment on column public.notes.locked is '是否加锁，仅影响客户端是否要求输入口令';
comment on column public.notes.passphrase_hash is '口令的 PBKDF2-SHA256 十六进制摘要';
comment on column public.notes.passphrase_salt is '口令派生用的随机盐，十六进制';

create index if not exists notes_user_updated_idx
  on public.notes (user_id, updated_at desc);

create index if not exists notes_folder_idx
  on public.notes (folder_id) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- 3. 图片表
--    图片文件本体放在存储桶里，这张表只记录元数据。
--    图片一旦上传就不再修改，所以不需要版本号和乐观锁，按 id upsert 即可。
-- ---------------------------------------------------------------------------
create table if not exists public.note_images (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  storage_path text not null,
  byte_size    integer not null default 0,
  width        integer,
  height       integer,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

comment on table public.note_images is '笔记里插入的图片的元数据，文件本体在 note-images 桶';
comment on column public.note_images.storage_path is '桶内路径，形如 <user_id>/<image_id>.jpg';
comment on column public.note_images.deleted_at is '软删除标记；客户端会定期清理已无引用的图片';

create index if not exists note_images_user_updated_idx
  on public.note_images (user_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- 4. 行级权限：只能读写属于自己的行
-- ---------------------------------------------------------------------------
alter table public.folders enable row level security;
alter table public.notes enable row level security;
alter table public.note_images enable row level security;

drop policy if exists folders_own on public.folders;
create policy folders_own on public.folders
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

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

drop policy if exists note_images_own on public.note_images;
create policy note_images_own on public.note_images
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on public.folders to authenticated;
grant select, insert, update, delete on public.notes to authenticated;
grant select, insert, update, delete on public.note_images to authenticated;

-- ---------------------------------------------------------------------------
-- 5. 更新时间以服务端时钟为准
--    客户端只负责把 version 递增加一，updated_at 一律由触发器覆盖，
--    这样手机和电脑的系统时间不一致也不会影响增量同步。
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
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
  execute function public.touch_updated_at();

drop trigger if exists folders_touch_updated_at on public.folders;
create trigger folders_touch_updated_at
  before update on public.folders
  for each row
  execute function public.touch_updated_at();

drop trigger if exists note_images_touch_updated_at on public.note_images;
create trigger note_images_touch_updated_at
  before update on public.note_images
  for each row
  execute function public.touch_updated_at();

-- 上一版用的函数，现在合并成 touch_updated_at 了
drop function if exists public.notes_touch_updated_at();

-- ---------------------------------------------------------------------------
-- 6. 实时推送
--    replica identity full 让更新/删除事件带上完整旧行，
--    Realtime 才能在 RLS 下正确判断这条变更是否该推给当前用户。
--    图片表不进实时通道：它只在插入时变化一次，靠拉取水位就够了。
-- ---------------------------------------------------------------------------
alter table public.notes replica identity full;
alter table public.folders replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'notes'
  ) then
    alter publication supabase_realtime add table public.notes;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'folders'
  ) then
    alter publication supabase_realtime add table public.folders;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. 图片存储桶
--    私有桶，路径第一段放 user_id，策略据此判断归属，
--    这样每个人的图片在服务端也是互相隔离的。
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('note-images', 'note-images', false)
on conflict (id) do nothing;

drop policy if exists note_images_read_own on storage.objects;
create policy note_images_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'note-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists note_images_insert_own on storage.objects;
create policy note_images_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'note-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists note_images_update_own on storage.objects;
create policy note_images_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'note-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists note_images_delete_own on storage.objects;
create policy note_images_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'note-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
