-- Tombola Connect — empêche de lister tous les carnets de la plateforme
--
-- Vendu à plusieurs associations différentes, ce produit ne doit jamais
-- permettre à un visiteur de parcourir la liste de toutes les tombolas
-- créées par tout le monde (nom de l'association, date de tirage...),
-- même si chaque tombola prise individuellement n'a rien de secret.
--
-- La lecture publique reposait sur une policy "using (true)" : pratique
-- pour afficher UN carnet précis (par son id ou sa référence), mais elle
-- autorisait tout autant un SELECT sans filtre listant tout. On la
-- remplace par une lecture réservée à l'organisateur propriétaire, et une
-- fonction RPC qui ne renvoie jamais qu'un seul carnet, précisément
-- identifié — jamais une liste. C'est la même logique que celle déjà
-- appliquée aux billets depuis le début.

drop policy "carnets_lecture_publique" on carnets;

create policy "carnets_lecture_par_organisateur"
  on carnets for select
  using (organisateur_id = auth.uid());

create or replace function carnet_public(p_id uuid default null, p_reference text default null)
returns table (
  id uuid,
  nom text,
  description text,
  date_tirage timestamptz,
  organisation_nom text,
  organisation_presentation text,
  organisation_contact text
)
language sql
security definer
set search_path = public
stable
as $$
  select carnets.id, carnets.nom, carnets.description, carnets.date_tirage,
         carnets.organisation_nom, carnets.organisation_presentation, carnets.organisation_contact
  from carnets
  where (p_id is not null and carnets.id = p_id)
  or (p_reference is not null and carnets.reference_imprimee = p_reference)
  limit 1;
$$;

grant execute on function carnet_public(uuid, text) to anon, authenticated;
