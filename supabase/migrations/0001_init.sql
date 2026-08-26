-- Tombola Connect — schéma initial
-- Choix structurant : on ne stocke jamais d'identité d'acheteur (RGPD).
-- Toute vérification se fait "code par code" via des fonctions RPC
-- SECURITY DEFINER, jamais par un SELECT public direct sur les billets :
-- ça empêche quiconque de lister ou d'aspirer tous les codes d'un carnet.

create extension if not exists pgcrypto;

-- ============================================================================
-- Tables
-- ============================================================================

create table carnets (
  id uuid primary key default gen_random_uuid(),
  organisateur_id uuid not null references auth.users(id) on delete cascade,
  nom text not null,
  description text,
  date_tirage timestamptz,
  cree_le timestamptz not null default now()
);

create table billets (
  id uuid primary key default gen_random_uuid(),
  carnet_id uuid not null references carnets(id) on delete cascade,
  -- Code tel qu'imprimé. Comparé en majuscules/sans espaces pour tolérer
  -- une saisie manuelle légèrement différente (ex: minuscules) sans dupliquer
  -- la logique de normalisation partout ailleurs.
  code text not null,
  cree_le timestamptz not null default now(),
  unique (carnet_id, code)
);

create table lots (
  id uuid primary key default gen_random_uuid(),
  carnet_id uuid not null references carnets(id) on delete cascade,
  rang int not null check (rang > 0),
  nom text not null,
  description text,
  -- Rempli uniquement par effectuer_tirage(). Tant qu'il est NULL, le lot
  -- n'a pas encore été tiré.
  billet_gagnant_id uuid references billets(id),
  unique (carnet_id, rang)
);

-- ============================================================================
-- Activation de la sécurité au niveau ligne (RLS)
-- ============================================================================

alter table carnets enable row level security;
alter table billets enable row level security;
alter table lots enable row level security;

-- Carnets : les infos (nom, description, date) ne sont pas sensibles et
-- doivent être visibles sur la page publique du carnet et sur l'accueil
-- (liste des tombolas pour la vérification de billet). Seule la création
-- et la modification restent réservées à l'organisateur propriétaire.
create policy "carnets_lecture_publique"
  on carnets for select
  using (true);

create policy "carnets_creation_par_organisateur"
  on carnets for insert
  with check (organisateur_id = auth.uid());

create policy "carnets_modification_par_organisateur"
  on carnets for update
  using (organisateur_id = auth.uid())
  with check (organisateur_id = auth.uid());

create policy "carnets_suppression_par_organisateur"
  on carnets for delete
  using (organisateur_id = auth.uid());

-- Billets : AUCUN accès public, même en lecture. On ne passe que par les
-- fonctions RPC ci-dessous (verifier_billet, resultats_carnet) qui
-- s'exécutent en SECURITY DEFINER et ne renvoient jamais la liste complète.
-- L'organisateur peut consulter/gérer les billets de ses propres carnets
-- (utile pour le tableau de bord), mais toujours billet par billet ou en
-- comptage, jamais exposé au public.
create policy "billets_gestion_par_organisateur"
  on billets for all
  using (
    exists (
      select 1 from carnets
      where carnets.id = billets.carnet_id
      and carnets.organisateur_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from carnets
      where carnets.id = billets.carnet_id
      and carnets.organisateur_id = auth.uid()
    )
  );

-- Lots : lecture publique autorisée, mais la ligne ne contient jamais le
-- code du billet gagnant — seulement billet_gagnant_id, un identifiant
-- opaque sans valeur sans accès à la table billets (qui reste fermée au
-- public). Cette lecture publique sert uniquement à faire fonctionner le
-- direct (Realtime) : le visiteur voit qu'un lot vient d'être tiré et
-- redemande alors le code réel via resultats_carnet (RPC), qui seul a le
-- droit de faire la jointure vers billets.
create policy "lots_lecture_publique"
  on lots for select
  using (true);

create policy "lots_gestion_par_organisateur"
  on lots for insert
  with check (
    exists (
      select 1 from carnets
      where carnets.id = lots.carnet_id
      and carnets.organisateur_id = auth.uid()
    )
  );

create policy "lots_modification_par_organisateur"
  on lots for update
  using (
    exists (
      select 1 from carnets
      where carnets.id = lots.carnet_id
      and carnets.organisateur_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from carnets
      where carnets.id = lots.carnet_id
      and carnets.organisateur_id = auth.uid()
    )
  );

create policy "lots_suppression_par_organisateur"
  on lots for delete
  using (
    exists (
      select 1 from carnets
      where carnets.id = lots.carnet_id
      and carnets.organisateur_id = auth.uid()
    )
  );

-- Diffusion en direct : la page publique du carnet écoute les changements
-- de la table lots (postgres_changes) pour afficher les gagnants sans
-- recharger la page.
alter publication supabase_realtime add table lots;

-- ============================================================================
-- Fonctions RPC
-- ============================================================================

-- Enregistre une liste de codes de billets déjà imprimés pour un carnet.
-- Appelée par l'organisateur après avoir saisi une plage (préfixe + numéro
-- de début/fin, transformée côté page en liste de codes) ou collé une liste
-- brute. SECURITY DEFINER pour pouvoir insérer dans "billets" sans exposer
-- de policy d'insertion plus permissive que nécessaire ; la vérification du
-- propriétaire se fait explicitement au début de la fonction.
create or replace function generer_billets(p_carnet_id uuid, p_codes text[])
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nb_inseres int;
begin
  if not exists (
    select 1 from carnets
    where id = p_carnet_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Ce carnet ne vous appartient pas.';
  end if;

  with codes_normalises as (
    select distinct upper(trim(code)) as code
    from unnest(p_codes) as code
    where trim(code) <> ''
  )
  insert into billets (carnet_id, code)
  select p_carnet_id, code from codes_normalises
  on conflict (carnet_id, code) do nothing;

  get diagnostics v_nb_inseres = row_count;
  return v_nb_inseres;
end;
$$;

-- Vérifie un code de billet pour un carnet donné, sans jamais exposer la
-- liste des billets existants : une seule ligne de résultat, correspondant
-- exactement au code demandé. Utilisable par le public (anon) et par les
-- organisateurs connectés.
create or replace function verifier_billet(p_carnet_id uuid, p_code text)
returns table (existe boolean, gagnant boolean, rang int, nom_lot text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_billet_id uuid;
  v_rang int;
  v_nom text;
begin
  select id into v_billet_id
  from billets
  where carnet_id = p_carnet_id and code = upper(trim(p_code));

  if v_billet_id is null then
    return query select false, false, null::int, null::text;
    return;
  end if;

  select lots.rang, lots.nom into v_rang, v_nom
  from lots
  where lots.carnet_id = p_carnet_id and lots.billet_gagnant_id = v_billet_id;

  return query select true, (v_rang is not null), v_rang, v_nom;
end;
$$;

-- Résultats publics d'un carnet : la liste des lots, classés par rang, avec
-- le code du billet gagnant une fois (et seulement une fois) le tirage fait.
-- C'est la seule façon d'obtenir un code de billet gagnant depuis le public :
-- jamais de SELECT direct sur la table billets.
create or replace function resultats_carnet(p_carnet_id uuid)
returns table (rang int, nom_lot text, description text, code_gagnant text)
language sql
security definer
set search_path = public
stable
as $$
  select lots.rang, lots.nom, lots.description, billets.code
  from lots
  left join billets on billets.id = lots.billet_gagnant_id
  where lots.carnet_id = p_carnet_id
  order by lots.rang;
$$;

-- Tire au sort le billet gagnant d'un lot précis. Réservé à l'organisateur
-- propriétaire du carnet (vérifié via auth.uid()). Le tirage lui-même a
-- lieu ici, côté base, pour que "jamais deux fois le même gagnant sur un
-- même carnet" soit une garantie de la base de données et non une règle
-- que le code JS pourrait oublier de respecter.
create or replace function effectuer_tirage(p_lot_id uuid)
returns table (rang int, nom_lot text, code_gagnant text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_carnet_id uuid;
  v_billet_gagnant_id uuid;
  v_nouveau_gagnant_id uuid;
begin
  select lots.carnet_id, lots.billet_gagnant_id
  into v_carnet_id, v_billet_gagnant_id
  from lots
  where lots.id = p_lot_id;

  if v_carnet_id is null then
    raise exception 'Ce lot n''existe pas.';
  end if;

  if not exists (
    select 1 from carnets
    where id = v_carnet_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Ce carnet ne vous appartient pas.';
  end if;

  -- Si le lot a déjà été tiré, on renvoie le résultat existant plutôt que
  -- de retirer au sort (idempotent : un double-clic ou un rechargement de
  -- page ne change pas le gagnant).
  if v_billet_gagnant_id is null then
    select billets.id into v_nouveau_gagnant_id
    from billets
    where billets.carnet_id = v_carnet_id
    and billets.id not in (
      select lots.billet_gagnant_id from lots
      where lots.carnet_id = v_carnet_id and lots.billet_gagnant_id is not null
    )
    order by random()
    limit 1;

    if v_nouveau_gagnant_id is null then
      raise exception 'Tous les billets enregistrés ont déjà été tirés : impossible de tirer ce lot.';
    end if;

    update lots set billet_gagnant_id = v_nouveau_gagnant_id where id = p_lot_id;
  end if;

  return query
  select lots.rang, lots.nom, billets.code
  from lots
  join billets on billets.id = lots.billet_gagnant_id
  where lots.id = p_lot_id;
end;
$$;

-- ============================================================================
-- Droits d'exécution
-- ============================================================================

-- Le public (visiteurs non connectés) doit pouvoir vérifier un billet et
-- consulter les résultats, mais jamais tirer au sort ni générer des billets.
grant execute on function verifier_billet(uuid, text) to anon, authenticated;
grant execute on function resultats_carnet(uuid) to anon, authenticated;
grant execute on function generer_billets(uuid, text[]) to authenticated;
grant execute on function effectuer_tirage(uuid) to authenticated;
