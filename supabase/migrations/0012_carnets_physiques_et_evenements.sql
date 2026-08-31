-- Tombola Connect — correction du modèle métier : carnet physique ≠ événement
--
-- Erreur de conception à corriger : jusqu'ici, l'organisateur tapait ou
-- collait lui-même les codes de ses billets ("Enregistrer une plage de
-- billets"). Ce n'est pas comment Louis-Marie vend son produit : les
-- carnets physiques sont imprimés À L'AVANCE, avant qu'aucune association
-- ne les achète et donc avant qu'aucun événement n'existe. Chaque carnet
-- physique porte déjà, en base, tous ses billets numérotés, plus un code
-- d'activation unique imprimé sur sa couverture. Vendu tel quel (par
-- exemple sur Amazon), il n'est rattaché à rien tant que personne ne l'a
-- activé.
--
-- Le vrai flux organisateur est donc : créer un événement (nom, lots,
-- date de tirage) → puis ACTIVER un ou plusieurs carnets physiques déjà
-- achetés en entrant leur code d'activation → ce qui rattache d'un coup
-- tous les billets déjà présents dans ce carnet à l'événement. Un carnet
-- ne peut être activé qu'une seule fois.
--
-- On renomme donc la table "carnets" (l'événement piloté par
-- l'organisateur) en "evenements", et on introduit une vraie table
-- "carnets_physiques" pour représenter l'objet vendu. Les mécanismes
-- devenus incohérents avec ce modèle (saisie manuelle de billets,
-- références/clés de "lots imprimés" posées sur l'événement) sont
-- retirés au profit de ce nouveau système, plus proche de la réalité.
--
-- Attention : les données de test existantes (billets enregistrés à la
-- main, carnets créés avec l'ancien mécanisme de référence) ne sont pas
-- migrables vers ce nouveau modèle et seront perdues pour les billets.
-- Les événements eux-mêmes (nom, description, lots) sont conservés.

-- ============================================================================
-- 1. Renommage de "carnets" en "evenements"
-- ============================================================================

alter table carnets rename to evenements;

-- Les anciennes policies gardent leur définition (elles suivent la table
-- renommée), mais leurs noms restent trompeurs : on les recrée proprement.
drop policy if exists "carnets_lecture_par_organisateur" on evenements;
drop policy if exists "carnets_creation_par_organisateur" on evenements;
drop policy if exists "carnets_modification_par_organisateur" on evenements;
drop policy if exists "carnets_suppression_par_organisateur" on evenements;

create policy "evenements_lecture_par_organisateur"
  on evenements for select
  using (organisateur_id = auth.uid());

create policy "evenements_creation_par_organisateur"
  on evenements for insert
  with check (organisateur_id = auth.uid());

create policy "evenements_modification_par_organisateur"
  on evenements for update
  using (organisateur_id = auth.uid())
  with check (organisateur_id = auth.uid());

create policy "evenements_suppression_par_organisateur"
  on evenements for delete
  using (organisateur_id = auth.uid());

-- La colonne reference_imprimee n'a plus lieu d'être sur l'événement : ce
-- concept (référence publique + activation) se rattache maintenant à un
-- carnet physique précis, pas à l'événement dans son ensemble (un même
-- événement peut recevoir plusieurs carnets physiques activés).
alter table evenements drop column if exists reference_imprimee;

-- ============================================================================
-- 2. Table lots : on renomme la colonne de rattachement pour rester clair
-- ============================================================================

alter table lots rename column carnet_id to evenement_id;

drop policy if exists "lots_lecture_publique" on lots;
drop policy if exists "lots_gestion_par_organisateur" on lots;
drop policy if exists "lots_modification_par_organisateur" on lots;
drop policy if exists "lots_suppression_par_organisateur" on lots;

create policy "lots_lecture_publique"
  on lots for select
  using (true);

create policy "lots_gestion_par_organisateur"
  on lots for insert
  with check (
    exists (
      select 1 from evenements
      where evenements.id = lots.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  );

create policy "lots_modification_par_organisateur"
  on lots for update
  using (
    exists (
      select 1 from evenements
      where evenements.id = lots.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from evenements
      where evenements.id = lots.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  );

create policy "lots_suppression_par_organisateur"
  on lots for delete
  using (
    exists (
      select 1 from evenements
      where evenements.id = lots.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  );

-- ============================================================================
-- 3. Nouvelle table : carnets physiques (l'objet vendu, ex: sur Amazon)
-- ============================================================================

create table carnets_physiques (
  id uuid primary key default gen_random_uuid(),
  -- Imprimée en QR sur CHAQUE billet du carnet : sert uniquement à
  -- retrouver la page publique de l'événement une fois le carnet activé.
  -- Ne permet à elle seule ni de lister, ni d'activer quoi que ce soit.
  reference_publique text not null unique,
  -- Imprimée en QR une seule fois, sur la couverture du carnet (jamais
  -- sur les billets) : seule elle permet l'activation.
  code_activation text not null unique,
  -- NULL tant que personne n'a activé ce carnet.
  evenement_id uuid references evenements(id),
  cree_le timestamptz not null default now()
);

alter table carnets_physiques enable row level security;
-- Aucune policy : ni le public ni les organisateurs ne peuvent lire ou
-- modifier cette table directement. Toute opération passe par les
-- fonctions RPC ci-dessous (activer_carnet, generer_carnets_physiques),
-- qui vérifient elles-mêmes les droits.

-- ============================================================================
-- 4. Table billets : rattachée à un carnet physique, plus à un événement
--    directement enregistré à la main
-- ============================================================================

-- Les billets existants (saisis à la main dans l'ancien flux, pour des
-- carnets de test) n'ont pas de carnet physique d'origine : impossible
-- de les faire correspondre au nouveau modèle. On repart de zéro pour
-- cette table — et on retire d'abord les gagnants déjà tirés sur les
-- événements de test, puisqu'ils pointaient justement vers ces billets.
update lots set billet_gagnant_id = null;
delete from billets;

alter table billets
  add column carnet_physique_id uuid references carnets_physiques(id) on delete cascade,
  add column evenement_id uuid references evenements(id);

-- La policy existante référence carnet_id : il faut la supprimer avant de
-- pouvoir supprimer cette colonne (sinon Postgres refuse le DROP COLUMN,
-- l'objet en dépendant encore).
drop policy if exists "billets_gestion_par_organisateur" on billets;

-- L'ancienne colonne carnet_id (l'événement) n'a plus de sens : un billet
-- appartient d'abord à un carnet physique, et n'est rattaché à un
-- événement qu'une fois ce carnet activé (evenement_id, rempli par
-- activer_carnet()).
alter table billets drop column if exists carnet_id;

alter table billets alter column carnet_physique_id set not null;

-- Un code de billet est unique au sein de son carnet physique (le carnet
-- physique est numéroté par l'imprimeur, indépendamment des autres).
alter table billets add constraint billets_carnet_physique_code_uniq unique (carnet_physique_id, code);

-- Une fois rattaché à un événement, un code de billet doit y rester
-- unique (deux carnets physiques activés sur le même événement ne
-- doivent jamais se chevaucher).
create unique index billets_evenement_code_uniq on billets (evenement_id, code) where evenement_id is not null;

create policy "billets_lecture_par_organisateur"
  on billets for select
  using (
    exists (
      select 1 from evenements
      where evenements.id = billets.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  );

create policy "billets_modification_par_organisateur"
  on billets for update
  using (
    exists (
      select 1 from evenements
      where evenements.id = billets.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from evenements
      where evenements.id = billets.evenement_id
      and evenements.organisateur_id = auth.uid()
    )
  );

-- Pas de policy d'insertion pour les organisateurs : les billets sont
-- créés uniquement par generer_carnets_physiques() (avant même qu'un
-- événement existe), jamais saisis à la main.

-- ============================================================================
-- 5. Fonctions à mettre à jour pour le nouveau schéma
-- ============================================================================

-- CREATE OR REPLACE FUNCTION refuse de renommer un paramètre existant
-- (ERROR 42P13), même en gardant les mêmes types : il faut d'abord
-- supprimer l'ancienne version (p_carnet_id) avant de recréer avec le
-- nouveau nom (p_evenement_id). Le DROP efface les autorisations
-- (grant execute) déjà en place : on les repose juste après.
drop function if exists verifier_billet(uuid, text);

create function verifier_billet(p_evenement_id uuid, p_code text)
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
  where evenement_id = p_evenement_id and normaliser_code(code) = normaliser_code(p_code)
  limit 1;

  if v_billet_id is null then
    return query select false, false, null::int, null::text;
    return;
  end if;

  select lots.rang, lots.nom into v_rang, v_nom
  from lots
  where lots.evenement_id = p_evenement_id and lots.billet_gagnant_id = v_billet_id;

  return query select true, (v_rang is not null), v_rang, v_nom;
end;
$$;

grant execute on function verifier_billet(uuid, text) to anon, authenticated;

drop function if exists resultats_carnet(uuid);

create function resultats_carnet(p_evenement_id uuid)
returns table (rang int, nom_lot text, description text, code_gagnant text)
language sql
security definer
set search_path = public
stable
as $$
  select lots.rang, lots.nom, lots.description, billets.code
  from lots
  left join billets on billets.id = lots.billet_gagnant_id
  where lots.evenement_id = p_evenement_id
  order by lots.rang;
$$;

grant execute on function resultats_carnet(uuid) to anon, authenticated;

create or replace function effectuer_tirage(p_lot_id uuid)
returns table (rang int, nom_lot text, code_gagnant text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_evenement_id uuid;
  v_billet_gagnant_id uuid;
  v_nouveau_gagnant_id uuid;
begin
  select lots.evenement_id, lots.billet_gagnant_id
  into v_evenement_id, v_billet_gagnant_id
  from lots
  where lots.id = p_lot_id;

  if v_evenement_id is null then
    raise exception 'Ce lot n''existe pas.';
  end if;

  if not exists (
    select 1 from evenements
    where id = v_evenement_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Cet événement ne vous appartient pas.';
  end if;

  if v_billet_gagnant_id is null then
    select billets.id into v_nouveau_gagnant_id
    from billets
    where billets.evenement_id = v_evenement_id
    and not billets.exclu
    and billets.id not in (
      select lots.billet_gagnant_id from lots
      where lots.evenement_id = v_evenement_id and lots.billet_gagnant_id is not null
    )
    order by random()
    limit 1;

    if v_nouveau_gagnant_id is null then
      raise exception 'Tous les billets rattachés ont déjà été tirés : impossible de tirer ce lot.';
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

drop function if exists exclure_billet(uuid, text, boolean);

create function exclure_billet(p_evenement_id uuid, p_code text, p_exclu boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nb_lignes int;
begin
  if not exists (
    select 1 from evenements
    where id = p_evenement_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Cet événement ne vous appartient pas.';
  end if;

  update billets
  set exclu = p_exclu
  where evenement_id = p_evenement_id
  and normaliser_code(code) = normaliser_code(p_code);

  get diagnostics v_nb_lignes = row_count;
  return v_nb_lignes > 0;
end;
$$;

grant execute on function exclure_billet(uuid, text, boolean) to authenticated;

-- carnet_public() cherchait un événement par id ou par reference_imprimee
-- (colonne supprimée) : elle cherche maintenant uniquement par id. La
-- recherche par référence publique passe désormais par
-- evenement_par_carnet_physique(), qui suit le nouveau chemin (carnet
-- physique → événement rattaché).
drop function if exists carnet_public(uuid, text);

create function evenement_public(p_id uuid)
returns table (
  id uuid,
  nom text,
  description text,
  date_tirage timestamptz,
  organisation_nom text,
  organisation_presentation text,
  organisation_contact text,
  logo text
)
language sql
security definer
set search_path = public
stable
as $$
  select evenements.id, evenements.nom, evenements.description, evenements.date_tirage,
         evenements.organisation_nom, evenements.organisation_presentation, evenements.organisation_contact,
         evenements.logo
  from evenements
  where evenements.id = p_id;
$$;

grant execute on function evenement_public(uuid) to anon, authenticated;

-- Retrouve l'événement rattaché à un carnet physique à partir de sa
-- référence publique (celle imprimée sur les billets) : c'est ce que la
-- page publique du carnet appelle après avoir scanné un billet, avant de
-- charger evenement_public(). Si le carnet n'est pas encore activé,
-- evenement_id est simplement absent du résultat.
create function evenement_pour_carnet_physique(p_reference_publique text)
returns table (evenement_id uuid)
language sql
security definer
set search_path = public
stable
as $$
  select carnets_physiques.evenement_id
  from carnets_physiques
  where carnets_physiques.reference_publique = trim(p_reference_publique);
$$;

grant execute on function evenement_pour_carnet_physique(text) to anon, authenticated;

-- Active un carnet physique déjà acheté : rattache tous ses billets à
-- l'événement de l'organisateur appelant. Un carnet ne peut être activé
-- qu'une fois (la mise à jour n'affecte une ligne que si evenement_id est
-- encore NULL, ce qui reste vrai même en cas de tentative concurrente).
create function activer_carnet(p_evenement_id uuid, p_code_activation text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_carnet_id uuid;
  v_nb_billets int;
begin
  if not exists (
    select 1 from evenements
    where id = p_evenement_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Cet événement ne vous appartient pas.';
  end if;

  update carnets_physiques
  set evenement_id = p_evenement_id
  where code_activation = trim(p_code_activation)
  and evenement_id is null
  returning id into v_carnet_id;

  if v_carnet_id is null then
    raise exception 'Ce code de carnet est invalide ou a déjà été activé.';
  end if;

  update billets set evenement_id = p_evenement_id where carnet_physique_id = v_carnet_id;
  get diagnostics v_nb_billets = row_count;

  return v_nb_billets;
end;
$$;

grant execute on function activer_carnet(uuid, text) to authenticated;

-- Pré-génère N carnets physiques (référence publique + code d'activation
-- + billets déjà numérotés), avant même qu'aucun événement existe :
-- c'est ce que Louis-Marie utilise pour préparer un envoi à l'impression.
-- Réservé à son compte (comme generer_lots_imprimes(), qu'elle remplace).
create function generer_carnets_physiques(p_nombre int, p_prefixe text, p_billets_par_carnet int)
returns table (reference_publique text, code_activation text, nb_billets int)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_prefixe text := coalesce(upper(trim(p_prefixe)), '');
  v_carnet_id uuid;
  v_reference text;
  v_cle text;
  i int;
  j int;
begin
  if coalesce(auth.jwt() ->> 'email', '') not in ('jexy.gavina@protonmail.com', 'jexy.gavina@gmail.com') then
    raise exception 'Cet outil est réservé à l''administrateur de la plateforme.';
  end if;

  if p_nombre < 1 or p_nombre > 200 then
    raise exception 'Choisissez un nombre de carnets entre 1 et 200.';
  end if;

  if p_billets_par_carnet < 1 or p_billets_par_carnet > 2000 then
    raise exception 'Choisissez un nombre de billets par carnet entre 1 et 2000.';
  end if;

  for i in 1..p_nombre loop
    v_reference := encode(gen_random_bytes(6), 'hex');
    v_cle := encode(gen_random_bytes(16), 'hex');

    insert into carnets_physiques (reference_publique, code_activation)
    values (v_reference, v_cle)
    returning id into v_carnet_id;

    for j in 1..p_billets_par_carnet loop
      insert into billets (carnet_physique_id, code)
      values (v_carnet_id, v_prefixe || lpad(j::text, length(p_billets_par_carnet::text), '0'));
    end loop;

    reference_publique := v_reference;
    code_activation := v_cle;
    nb_billets := p_billets_par_carnet;
    return next;
  end loop;
end;
$$;

grant execute on function generer_carnets_physiques(int, text, int) to authenticated;

-- ============================================================================
-- 6. Fonctions et table devenues obsolètes avec ce nouveau modèle
-- ============================================================================

-- L'organisateur ne saisit plus de billets à la main : ils viennent
-- toujours d'un carnet physique pré-généré et activé.
drop function if exists generer_billets(uuid, text[]);

-- L'ancien mécanisme de "lot imprimé" (référence + clé posées sur
-- l'événement) est remplacé par carnets_physiques + activer_carnet().
drop function if exists activer_reference_imprimee(text, text, uuid);
drop function if exists generer_lots_imprimes(int);
drop table if exists references_impression;
