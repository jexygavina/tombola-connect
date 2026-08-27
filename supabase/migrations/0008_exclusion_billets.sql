-- Tombola Connect — exclure un billet abîmé du tirage
--
-- Un billet déchiré, perdu ou rendu illisible ne doit plus pouvoir être
-- tiré au sort, sans pour autant supprimer son enregistrement (on garde
-- la trace qu'il existe, juste plus dans le tirage). L'organisateur peut
-- l'exclure puis le réintégrer à tout moment via exclure_billet().

alter table billets
  add column exclu boolean not null default false;

create or replace function exclure_billet(p_carnet_id uuid, p_code text, p_exclu boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nb_lignes int;
begin
  if not exists (
    select 1 from carnets
    where id = p_carnet_id and organisateur_id = auth.uid()
  ) then
    raise exception 'Ce carnet ne vous appartient pas.';
  end if;

  update billets
  set exclu = p_exclu
  where carnet_id = p_carnet_id
  and normaliser_code(code) = normaliser_code(p_code);

  get diagnostics v_nb_lignes = row_count;
  return v_nb_lignes > 0;
end;
$$;

grant execute on function exclure_billet(uuid, text, boolean) to authenticated;

-- Le tirage doit désormais ignorer les billets exclus, en plus de ceux
-- déjà gagnants sur ce carnet.
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

  if v_billet_gagnant_id is null then
    select billets.id into v_nouveau_gagnant_id
    from billets
    where billets.carnet_id = v_carnet_id
    and not billets.exclu
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
