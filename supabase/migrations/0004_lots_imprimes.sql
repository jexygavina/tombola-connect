-- Tombola Connect — lier un carnet à un lot de billets déjà imprimé
--
-- Les billets sont imprimés à l'avance, en gros lots, avant qu'une
-- association achète le carnet et le configure sur la plateforme. Le QR
-- code de chaque billet doit donc pointer vers une adresse fixe, choisie
-- au moment de l'impression — pas vers l'identifiant du carnet, qui
-- n'existe pas encore à ce moment-là.
--
-- Deux QR codes différents sont imprimés pour un même lot :
--   - un QR "public", identique sur chaque billet, qui pointe simplement
--     vers la page de consultation du carnet (carnet.html?ref=...) ;
--   - un QR "d'activation", imprimé une seule fois sur la couverture du
--     carnet physique (jamais sur les billets), qui contient en plus une
--     clé secrète nécessaire pour relier un carnet à cette référence.
--
-- Un acheteur qui scanne son billet ne connaît donc jamais la clé
-- d'activation, et ne peut pas créer un carnet à la place de l'association.
--
-- La table "references_impression" est pré-remplie par Louis-Marie (via le
-- SQL Editor de Supabase, qui s'exécute avec des droits d'administration)
-- à chaque nouveau lot envoyé à l'impression. Elle n'a aucune policy :
-- ni le public ni les organisateurs connectés ne peuvent la lire ou la
-- modifier directement, seule la fonction ci-dessous le peut.

create table references_impression (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  cle_activation text not null unique,
  carnet_id uuid references carnets(id),
  cree_le timestamptz not null default now()
);

alter table references_impression enable row level security;

alter table carnets
  add column reference_imprimee text unique;

create or replace function activer_reference_imprimee(p_reference text, p_cle_activation text, p_carnet_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from carnets
    where id = p_carnet_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Ce carnet ne vous appartient pas.';
  end if;

  -- Une seule instruction UPDATE avec sa condition : sous accès concurrent,
  -- Postgres sérialise les tentatives sur la même ligne, la seconde ne
  -- trouvant alors plus carnet_id à NULL. Impossible de relier deux fois
  -- la même référence, même si deux personnes essayaient au même instant.
  update references_impression
  set carnet_id = p_carnet_id
  where reference = trim(p_reference)
  and cle_activation = trim(p_cle_activation)
  and carnet_id is null;

  if not found then
    raise exception 'Ce code d''activation est invalide ou a déjà été utilisé.';
  end if;

  update carnets set reference_imprimee = trim(p_reference) where id = p_carnet_id;
end;
$$;

grant execute on function activer_reference_imprimee(text, text, uuid) to authenticated;
