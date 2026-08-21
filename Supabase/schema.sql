create table if not exists public.app_config (
    id text primary key,
    categories text[] not null default '{}',
    base_points integer not null,
    points_per_redemption integer not null,
    next_reward_points integer not null,
    daily_survey_goal integer not null
);

create table if not exists public.member_profiles (
    id text primary key,
    name text not null,
    tier text not null,
    member_code text not null,
    member_since_year integer not null
);

create table if not exists public.member_activity (
    member_id text primary key references public.member_profiles(id) on delete cascade,
    saved_perk_ids text[] not null default '{}',
    redeemed_perk_ids text[] not null default '{}',
    completed_survey_ids text[] not null default '{}',
    selected_interest_ids text[] not null default '{shopping,wellness}',
    weekly_digest_enabled boolean not null default true,
    nearby_perks_enabled boolean not null default true,
    biometric_unlock_enabled boolean not null default false,
    updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_member_activity_updated_at on public.member_activity;
create trigger set_member_activity_updated_at
before update on public.member_activity
for each row
execute function public.set_updated_at();

create table if not exists public.interests (
    id text primary key,
    title text not null,
    icon_name text not null,
    is_active boolean not null default true,
    display_order integer not null default 0
);

create table if not exists public.perks (
    id text primary key,
    title text not null,
    description text not null,
    partner text not null,
    category text not null,
    expiration text not null,
    distance text not null,
    distance_in_miles double precision not null,
    days_until_expiration integer not null,
    short_detail text not null,
    redemption_instructions text not null,
    terms text not null,
    estimated_savings integer not null,
    member_code text not null,
    icon_name text not null,
    tint_hex text not null,
    is_active boolean not null default true,
    display_order integer not null default 0
);

create table if not exists public.perk_collections (
    id text primary key,
    title text not null,
    subtitle text not null,
    category text not null,
    search_text text not null default '',
    sort text not null,
    icon_name text not null,
    tint_hex text not null,
    is_active boolean not null default true,
    display_order integer not null default 0
);

create table if not exists public.surveys (
    id text primary key,
    title text not null,
    description text not null,
    estimated_time text not null,
    audience text not null,
    points integer not null,
    match_score integer not null,
    match_reason text not null,
    interest_ids text[] not null default '{}',
    questions text[] not null default '{}',
    icon_name text not null,
    tint_hex text not null,
    is_active boolean not null default true,
    display_order integer not null default 0
);

create table if not exists public.survey_responses (
    member_id text not null references public.member_profiles(id) on delete cascade,
    survey_id text not null references public.surveys(id) on delete cascade,
    question_index integer not null,
    question text not null,
    answer text not null,
    submitted_at timestamptz not null default now(),
    primary key (member_id, survey_id, question_index)
);

create table if not exists public.perk_redemptions (
    member_id text not null references public.member_profiles(id) on delete cascade,
    perk_id text not null references public.perks(id) on delete cascade,
    redeemed_at timestamptz not null default now(),
    primary key (member_id, perk_id)
);

create table if not exists public.saved_perks (
    member_id text not null references public.member_profiles(id) on delete cascade,
    perk_id text not null references public.perks(id) on delete cascade,
    saved_at timestamptz not null default now(),
    primary key (member_id, perk_id)
);

alter table public.app_config enable row level security;
alter table public.member_profiles enable row level security;
alter table public.member_activity enable row level security;
alter table public.interests enable row level security;
alter table public.perks enable row level security;
alter table public.perk_collections enable row level security;
alter table public.surveys enable row level security;
alter table public.survey_responses enable row level security;
alter table public.perk_redemptions enable row level security;
alter table public.saved_perks enable row level security;

drop policy if exists "Read app config" on public.app_config;
create policy "Read app config" on public.app_config for select using (true);

drop policy if exists "Read member profiles" on public.member_profiles;
create policy "Read member profiles" on public.member_profiles
for select using (id = auth.uid()::text);

drop policy if exists "Insert own member profile" on public.member_profiles;
create policy "Insert own member profile" on public.member_profiles
for insert with check (id = auth.uid()::text);

drop policy if exists "Update own member profile" on public.member_profiles;
create policy "Update own member profile" on public.member_profiles
for update using (id = auth.uid()::text) with check (id = auth.uid()::text);

drop policy if exists "Read member activity" on public.member_activity;
create policy "Read member activity" on public.member_activity
for select using (member_id = auth.uid()::text);

drop policy if exists "Insert member activity" on public.member_activity;
create policy "Insert member activity" on public.member_activity
for insert with check (member_id = auth.uid()::text);

drop policy if exists "Update member activity" on public.member_activity;
create policy "Update member activity" on public.member_activity
for update using (member_id = auth.uid()::text)
with check (member_id = auth.uid()::text);

drop policy if exists "Read interests" on public.interests;
create policy "Read interests" on public.interests for select using (true);

drop policy if exists "Read perks" on public.perks;
create policy "Read perks" on public.perks for select using (true);

drop policy if exists "Read perk collections" on public.perk_collections;
create policy "Read perk collections" on public.perk_collections for select using (true);

drop policy if exists "Read surveys" on public.surveys;
create policy "Read surveys" on public.surveys for select using (true);

drop policy if exists "Read own survey responses" on public.survey_responses;
create policy "Read own survey responses" on public.survey_responses
for select using (member_id = auth.uid()::text);

drop policy if exists "Insert own survey responses" on public.survey_responses;
create policy "Insert own survey responses" on public.survey_responses
for insert with check (member_id = auth.uid()::text);

drop policy if exists "Update own survey responses" on public.survey_responses;
create policy "Update own survey responses" on public.survey_responses
for update using (member_id = auth.uid()::text)
with check (member_id = auth.uid()::text);

drop policy if exists "Read own perk redemptions" on public.perk_redemptions;
create policy "Read own perk redemptions" on public.perk_redemptions
for select using (member_id = auth.uid()::text);

drop policy if exists "Insert own perk redemptions" on public.perk_redemptions;
create policy "Insert own perk redemptions" on public.perk_redemptions
for insert with check (member_id = auth.uid()::text);

drop policy if exists "Read own saved perks" on public.saved_perks;
create policy "Read own saved perks" on public.saved_perks
for select using (member_id = auth.uid()::text);

drop policy if exists "Insert own saved perks" on public.saved_perks;
create policy "Insert own saved perks" on public.saved_perks
for insert with check (member_id = auth.uid()::text);

drop policy if exists "Update own saved perks" on public.saved_perks;
create policy "Update own saved perks" on public.saved_perks
for update using (member_id = auth.uid()::text)
with check (member_id = auth.uid()::text);

drop policy if exists "Delete own saved perks" on public.saved_perks;
create policy "Delete own saved perks" on public.saved_perks
for delete using (member_id = auth.uid()::text);

insert into public.app_config (
    id,
    categories,
    base_points,
    points_per_redemption,
    next_reward_points,
    daily_survey_goal
) values (
    'default',
    array['All', 'Food', 'Fitness', 'Travel', 'Retail'],
    2450,
    75,
    3000,
    300
) on conflict (id) do update set
    categories = excluded.categories,
    base_points = excluded.base_points,
    points_per_redemption = excluded.points_per_redemption,
    next_reward_points = excluded.next_reward_points,
    daily_survey_goal = excluded.daily_survey_goal;

insert into public.member_profiles (
    id,
    name,
    tier,
    member_code,
    member_since_year
) values (
    'demo-member',
    'Emanuil',
    'Pulse Plus',
    'PULSE-2450',
    2026
) on conflict (id) do update set
    name = excluded.name,
    tier = excluded.tier,
    member_code = excluded.member_code,
    member_since_year = excluded.member_since_year;

insert into public.member_activity (member_id)
values ('demo-member')
on conflict (member_id) do nothing;

insert into public.interests (id, title, icon_name, display_order) values
    ('entertainment', 'Entertainment', 'play.tv', 10),
    ('shopping', 'Shopping', 'cart', 20),
    ('wellness', 'Wellness', 'heart', 30),
    ('travel', 'Travel', 'airplane.departure', 40)
on conflict (id) do update set
    title = excluded.title,
    icon_name = excluded.icon_name,
    display_order = excluded.display_order,
    is_active = true;

insert into public.perks (
    id,
    title,
    description,
    partner,
    category,
    expiration,
    distance,
    distance_in_miles,
    days_until_expiration,
    short_detail,
    redemption_instructions,
    terms,
    estimated_savings,
    member_code,
    icon_name,
    tint_hex,
    display_order
) values
    ('sweetgreen-lunch-credit', 'Sweetgreen lunch credit', '$12 off your next weekday order at participating locations.', 'Sweetgreen', 'Food', 'Expires Friday', '0.4 mi', 0.4, 5, 'Lunch near the office', 'Show your member code at checkout or apply the offer in the partner app.', 'Valid once per member. Weekday orders only. Cannot be combined with other offers.', 12, 'PULSE-SG12', 'fork.knife', '#1A8C6B', 10),
    ('classpass-trial-boost', 'ClassPass trial boost', 'Get 20 bonus credits when you start a monthly plan.', 'ClassPass', 'Fitness', '6 days left', '1.2 mi', 1.2, 6, 'Bonus credits for classes', 'Tap redeem, then create or connect your ClassPass account before booking.', 'New monthly plans only. Bonus credits expire 30 days after activation.', 39, 'PULSE-FIT20', 'figure.run', '#266BC7', 20),
    ('hoteltonight-escape', 'HotelTonight escape', 'Save 18% on last-minute stays booked this month.', 'HotelTonight', 'Travel', 'Ends Aug 31', 'Online', 99, 14, 'Last-minute trip savings', 'Use the generated promo code before confirming an eligible hotel stay.', 'Eligible stays only. Taxes, fees, and blackout dates may apply.', 48, 'PULSE-STAY18', 'airplane.departure', '#BA422E', 30),
    ('everlane-essentials', 'Everlane essentials', 'Take 15% off workwear staples and everyday basics.', 'Everlane', 'Retail', 'New today', 'Online', 99, 21, 'Workwear and basics', 'Open the partner offer and apply the member discount at checkout.', 'Applies to full-price items. Excludes gift cards, final sale, and prior purchases.', 25, 'PULSE-EV15', 'bag', '#7A57BF', 40)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    partner = excluded.partner,
    category = excluded.category,
    expiration = excluded.expiration,
    distance = excluded.distance,
    distance_in_miles = excluded.distance_in_miles,
    days_until_expiration = excluded.days_until_expiration,
    short_detail = excluded.short_detail,
    redemption_instructions = excluded.redemption_instructions,
    terms = excluded.terms,
    estimated_savings = excluded.estimated_savings,
    member_code = excluded.member_code,
    icon_name = excluded.icon_name,
    tint_hex = excluded.tint_hex,
    display_order = excluded.display_order,
    is_active = true;

insert into public.perk_collections (
    id,
    title,
    subtitle,
    category,
    search_text,
    sort,
    icon_name,
    tint_hex,
    display_order
) values
    ('lunch-break', 'Lunch break', 'Nearby food perks for the workday.', 'Food', '', 'nearest', 'fork.knife', '#1A8C6B', 10),
    ('wellness', 'Wellness', 'Fitness and recovery offers with strong value.', 'Fitness', '', 'bestValue', 'heart', '#BA422E', 20),
    ('online-deals', 'Online deals', 'Remote-friendly offers you can use anywhere.', 'All', 'Online', 'bestValue', 'desktopcomputer', '#266BC7', 30),
    ('ending-soon', 'Ending soon', 'Perks to use before they expire.', 'All', '', 'endingSoon', 'clock', '#7A57BF', 40)
on conflict (id) do update set
    title = excluded.title,
    subtitle = excluded.subtitle,
    category = excluded.category,
    search_text = excluded.search_text,
    sort = excluded.sort,
    icon_name = excluded.icon_name,
    tint_hex = excluded.tint_hex,
    display_order = excluded.display_order,
    is_active = true;

insert into public.surveys (
    id,
    title,
    description,
    estimated_time,
    audience,
    points,
    match_score,
    match_reason,
    interest_ids,
    questions,
    icon_name,
    tint_hex,
    display_order
) values
    ('streaming-habits', 'Streaming habits', 'Tell us how you choose shows, subscriptions, and weekend watchlists.', '6 min', 'Entertainment', 120, 92, 'Matched because you saved travel and lifestyle offers and have weekly digest enabled.', array['entertainment', 'travel'], array['Which streaming services do you currently use?', 'How do you decide what to watch next?', 'What would make you switch or cancel a subscription?'], 'play.tv', '#266BC7', 10),
    ('grocery-routine', 'Grocery routine', 'Share where you shop, what you value, and how deals affect your cart.', '4 min', 'Shopping', 80, 86, 'Matched because retail and food rewards are active in your marketplace.', array['shopping'], array['Where do you buy groceries most often?', 'Which deal types change what you buy?', 'How often do you use loyalty rewards at checkout?'], 'cart', '#1A8C6B', 20),
    ('fitness-goals', 'Fitness goals', 'Help wellness partners understand classes, gear, and recovery habits.', '8 min', 'Wellness', 150, 94, 'Matched because wellness rewards and nearby offers are enabled for your profile.', array['wellness'], array['What fitness goals are you focused on this month?', 'Which wellness perks would you redeem fastest?', 'How do you choose between classes, gyms, and at-home workouts?'], 'figure.run', '#BA422E', 30)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    estimated_time = excluded.estimated_time,
    audience = excluded.audience,
    points = excluded.points,
    match_score = excluded.match_score,
    match_reason = excluded.match_reason,
    interest_ids = excluded.interest_ids,
    questions = excluded.questions,
    icon_name = excluded.icon_name,
    tint_hex = excluded.tint_hex,
    display_order = excluded.display_order,
    is_active = true;
