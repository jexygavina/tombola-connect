-- Tombola Connect — génération en série de lots à imprimer
--
-- Réservé à Louis-Marie : c'est lui qui envoie les billets à l'impression,
-- avant même de savoir quelle association achètera quel carnet. Cette
-- fonction crée d'un coup plusieurs paires (référence publique + clé
-- d'activation secrète), enregistrées dans references_impression, prêtes
-- à être transformées en QR codes puis envoyées à l'imprimeur.
--
-- La vérification se fait sur l'e-mail du compte connecté plutôt que sur
-- une table de rôles séparée : plus simple à ce stade, pour un seul
-- administrateur (Louis-Marie lui-même).

create or replace function generer_lots_imprimes(p_nombre int)
returns table (reference text, cle_activation text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.jwt() ->> 'email' is distinct from 'jexy.gavina@protonmail.com' then
    raise exception 'Cet outil est réservé à l''administrateur de la plateforme.';
  end if;

  if p_nombre < 1 or p_nombre > 200 then
    raise exception 'Choisissez un nombre de lots entre 1 et 200.';
  end if;

  return query
  insert into references_impression (reference, cle_activation)
  select
    encode(gen_random_bytes(6), 'hex'),
    encode(gen_random_bytes(16), 'hex')
  from generate_series(1, p_nombre)
  returning references_impression.reference, references_impression.cle_activation;
end;
$$;

grant execute on function generer_lots_imprimes(int) to authenticated;
