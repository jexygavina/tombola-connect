# Règles de travail — Tombola Connect

Ce dépôt héberge la plateforme web de Louis-Marie pour ses carnets de
tombola « connectés ». Louis-Marie n'est pas développeur : les règles
ci-dessous priment sur les habitudes générales.

## Langue

Toujours répondre en français. Les commentaires de code, les messages de
commit, et tous les textes visibles dans l'interface (organisateur comme
public) sont en français, sans jargon technique côté organisateur.

## Ne jamais faire taper de commande

Louis-Marie ne doit jamais avoir à ouvrir un terminal. Toute étape qui le
concerne (créer un projet Supabase, coller une clé, connecter Vercel) est
décrite dans le README en clic-par-clic, jamais en ligne de commande.

## Tester en local

Les pages appellent Supabase en JavaScript : ces appels sont bloqués si on
ouvre les fichiers HTML directement depuis l'explorateur de fichiers
(protocole `file://`). Pour une démonstration ou un test local, toujours
servir les fichiers via un petit serveur local, par exemple :

```
python3 -m http.server 8000
```

puis ouvrir `http://localhost:8000/page/index.html`.

## Proposer d'enregistrer et publier après chaque changement

Après toute modification de code, proposer à Louis-Marie de committer (avec
un message en français expliquant le pourquoi du changement) et de pousser
la branche. Ne jamais pousser sans qu'il en ait connaissance.

## Ne jamais pousser sur `main` directement

Tout changement passe par une branche dédiée et une pull request vers
`main`, jamais un push direct sur `main`. Louis-Marie n'a pas d'aperçu
Vercel automatique tant que le déploiement n'est pas connecté : le relire
avant de fusionner reste nécessaire.

## Philosophie technique du projet

- Pas de framework, pas d'étape de build : HTML/CSS/JS écrits à la main, un
  fichier = une page. Le client Supabase JS est chargé en `<script>` CDN.
- Backend : Supabase (Postgres + Auth + Realtime). Toute évolution de la
  base de données passe par une nouvelle migration dans
  `supabase/migrations/`, jamais par une modification manuelle dans le
  tableau de bord Supabase sans la reporter dans le dépôt.
- Aucune donnée personnelle sur les acheteurs de billets (pas de nom,
  e-mail, téléphone). Ne jamais ajouter un tel champ « pour plus tard » :
  c'est une contrainte RGPD délibérée, pas un oubli.
- La vérification de billet et les résultats publics passent toujours par
  des fonctions Postgres `SECURITY DEFINER` exposées en RPC, jamais par un
  `SELECT` public direct sur la table des billets : ça empêche l'énumération
  en masse des codes. Le tirage au sort a lieu côté base, réservé à
  l'organisateur propriétaire du carnet.
