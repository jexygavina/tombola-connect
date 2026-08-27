-- Tombola Connect — archiver un carnet
--
-- Une fois une tombola terminée, l'organisateur ne veut plus la voir dans
-- sa liste principale mais peut vouloir la retrouver plus tard. "Archiver"
-- ne change rien à la visibilité publique ni au fonctionnement du carnet :
-- ça ne fait que le sortir de la liste "Mes carnets" par défaut.

alter table carnets
  add column archive boolean not null default false;
