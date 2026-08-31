-- Tombola Connect — icône décorative par carnet
--
-- Une simple icône (choisie parmi une liste proposée, pas une image
-- importée) pour personnaliser chaque tombola sans demander à
-- l'organisateur de fournir un vrai logo. Stockée telle quelle (le
-- caractère emoji), affichée sur la page publique du carnet.

alter table carnets
  add column logo text;

-- carnet_public() doit renvoyer cette nouvelle colonne, en plus de celles
-- déjà exposées publiquement. Postgres n'autorise pas d'ajouter une colonne
-- de sortie à une fonction existante par un simple CREATE OR REPLACE : il
-- faut d'abord la supprimer.
drop function if exists carnet_public(uuid, text);

create function carnet_public(p_id uuid default null, p_reference text default null)
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
  select carnets.id, carnets.nom, carnets.description, carnets.date_tirage,
         carnets.organisation_nom, carnets.organisation_presentation, carnets.organisation_contact,
         carnets.logo
  from carnets
  where (p_id is not null and carnets.id = p_id)
  or (p_reference is not null and carnets.reference_imprimee = p_reference)
  limit 1;
$$;

-- Le DROP FUNCTION efface les droits d'exécution : on les redonne.
grant execute on function carnet_public(uuid, text) to anon, authenticated;
