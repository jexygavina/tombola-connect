-- Tombola Connect — corrige "function gen_random_bytes(integer) does not exist"
--
-- Chez Supabase, l'extension pgcrypto (qui fournit gen_random_bytes, utilisée
-- pour générer des références et clés d'activation aléatoires) est installée
-- dans un schéma séparé ("extensions"), pas dans "public". La fonction ne
-- cherchait que dans "public" : on ajoute "extensions" à sa recherche.

create or replace function generer_lots_imprimes(p_nombre int)
returns table (reference text, cle_activation text)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.jwt() ->> 'email' is distinct from 'jexy.gavina@protonmail.com'
  and auth.jwt() ->> 'email' is distinct from 'jexy.gavina@gmail.com' then
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
