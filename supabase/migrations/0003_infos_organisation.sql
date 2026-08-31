-- Tombola Connect — informations sur l'organisation, par carnet
--
-- Louis-Marie vend ce produit à plusieurs associations différentes : ces
-- informations (nom, présentation, contact) doivent donc être propres à
-- chaque carnet, et non fixes pour toute la plateforme. Elles ne sont pas
-- sensibles (c'est ce que l'organisateur veut justement montrer au
-- public), la policy de lecture publique existante sur "carnets" suffit.

alter table carnets
  add column organisation_nom text,
  add column organisation_presentation text,
  add column organisation_contact text;
