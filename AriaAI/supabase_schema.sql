-- AriaAI — Supabase schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query)

-- ============================================================
-- Tables
-- ============================================================

create table if not exists public.profiles (
    id           uuid        references auth.users on delete cascade primary key,
    username     text        unique not null,
    display_name text,
    created_at   timestamptz default now() not null
);

create table if not exists public.friendships (
    id         uuid        default gen_random_uuid() primary key,
    user_id    uuid        references public.profiles on delete cascade not null,
    friend_id  uuid        references public.profiles on delete cascade not null,
    created_at timestamptz default now() not null,
    unique(user_id, friend_id)
);

create table if not exists public.group_conversations (
    id            uuid        default gen_random_uuid() primary key,
    name          text        not null,
    created_by    uuid        references public.profiles on delete set null,
    created_at    timestamptz default now() not null,
    last_activity timestamptz default now() not null
);

create table if not exists public.group_members (
    id        uuid        default gen_random_uuid() primary key,
    group_id  uuid        references public.group_conversations on delete cascade not null,
    user_id   uuid        references public.profiles on delete cascade not null,
    joined_at timestamptz default now() not null,
    unique(group_id, user_id)
);

create table if not exists public.group_messages (
    id         uuid        default gen_random_uuid() primary key,
    group_id   uuid        references public.group_conversations on delete cascade not null,
    sender_id  uuid        references public.profiles on delete set null,
    role       text        not null check (role in ('user', 'assistant')),
    content    text        not null,
    created_at timestamptz default now() not null
);

-- Keep last_activity in sync whenever a message is inserted
create or replace function public.update_group_last_activity()
returns trigger language plpgsql as $$
begin
    update public.group_conversations
    set    last_activity = now()
    where  id = new.group_id;
    return new;
end;
$$;

create trigger trg_group_last_activity
after insert on public.group_messages
for each row execute function public.update_group_last_activity();

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.profiles          enable row level security;
alter table public.friendships       enable row level security;
alter table public.group_conversations enable row level security;
alter table public.group_members     enable row level security;
alter table public.group_messages    enable row level security;

-- profiles
create policy "Anyone can read profiles"
    on public.profiles for select using (true);

create policy "Users can insert their own profile"
    on public.profiles for insert with check (auth.uid() = id);

create policy "Users can update their own profile"
    on public.profiles for update using (auth.uid() = id);

-- friendships
create policy "Users see own friendships"
    on public.friendships for select
    using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "Users can add friendships"
    on public.friendships for insert with check (auth.uid() = user_id);

create policy "Users can remove own friendships"
    on public.friendships for delete using (auth.uid() = user_id);

-- group_conversations
create policy "Group members can see their groups"
    on public.group_conversations for select using (
        exists (
            select 1 from public.group_members
            where group_id = public.group_conversations.id
              and user_id  = auth.uid()
        )
    );

create policy "Authenticated users can create groups"
    on public.group_conversations for insert with check (auth.uid() = created_by);

create policy "Group members can update group metadata"
    on public.group_conversations for update using (
        exists (
            select 1 from public.group_members
            where group_id = public.group_conversations.id
              and user_id  = auth.uid()
        )
    );

-- group_members
create policy "Members can see group membership"
    on public.group_members for select using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = public.group_members.group_id
              and gm.user_id  = auth.uid()
        )
    );

create policy "Group creator can add members"
    on public.group_members for insert with check (
        auth.uid() = user_id
        or exists (
            select 1 from public.group_conversations gc
            where gc.id         = group_id
              and gc.created_by = auth.uid()
        )
    );

-- group_messages
create policy "Group members can read messages"
    on public.group_messages for select using (
        exists (
            select 1 from public.group_members
            where group_id = public.group_messages.group_id
              and user_id  = auth.uid()
        )
    );

create policy "Group members can send messages"
    on public.group_messages for insert with check (
        exists (
            select 1 from public.group_members
            where group_id = public.group_messages.group_id
              and user_id  = auth.uid()
        )
    );

-- ============================================================
-- Realtime — enable publication for group_messages
-- ============================================================

-- Allow Supabase Realtime to stream inserts on group_messages
alter publication supabase_realtime add table public.group_messages;
