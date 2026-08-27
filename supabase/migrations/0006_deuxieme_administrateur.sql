-- Tombola Connect — reconnaît une deuxième adresse administrateur
--
-- Louis-Marie utilise deux adresses e-mail selon les appareils. Les deux
-- doivent pouvoir accéder à l'outil de préparation des lots imprimés.

create or replace function generer_lots_imprimes(p_nombre int)
returns table (reference text, cle_activation text)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- coalesce en chaîne vide : si jamais le jeton ne portait aucun e-mail,
  -- on doit refuser l'accès (fermé par défaut), pas l'autoriser.
  if coalesce(auth.jwt() ->> 'email', '') not in ('jexy.gavina@protonmail.com', 'jexy.gavina@gmail.com') then
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
