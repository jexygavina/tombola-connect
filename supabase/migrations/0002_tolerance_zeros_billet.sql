-- Tombola Connect — tolère les zéros de tête lors de la vérification d'un billet
--
-- Un billet enregistré sous "064" doit être retrouvé même si l'acheteur
-- tape "64" : on compare une version normalisée du code (le préfixe
-- éventuel inchangé + la partie numérique finale sans ses zéros de tête)
-- plutôt que le texte brut. Le code reste stocké tel qu'imprimé sur le
-- billet, seule la comparaison lors de la vérification change.

create or replace function normaliser_code(p_code text)
returns text
language plpgsql
immutable
as $$
declare
  v_code text := upper(trim(p_code));
  v_chiffres text;
  v_prefixe text;
  v_nombre text;
begin
  -- Repère la suite de chiffres à la toute fin du code (ex: "064" dans
  -- "A-064"). Sans chiffres finaux, rien à normaliser.
  v_chiffres := substring(v_code from '([0-9]+)$');
  if v_chiffres is null then
    return v_code;
  end if;

  v_prefixe := left(v_code, length(v_code) - length(v_chiffres));
  v_nombre := ltrim(v_chiffres, '0');
  if v_nombre = '' then
    v_nombre := '0';
  end if;

  return v_prefixe || v_nombre;
end;
$$;

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
  where carnet_id = p_carnet_id
  and normaliser_code(code) = normaliser_code(p_code)
  limit 1;

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
