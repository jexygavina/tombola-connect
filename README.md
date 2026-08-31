# Tombola Connect

Plateforme web pour accompagner vos carnets de tombola papier « connectés » :
chaque billet porte un code unique préimprimé, et cette plateforme permet de
suivre en ligne l'inscription des billets et le tirage au sort, en direct.

## Deux notions à ne pas confondre : le carnet et l'événement

- Un **carnet physique** est l'objet en papier vendu tel quel (par exemple
  sur Amazon), avec ses billets déjà numérotés à l'intérieur et un code
  d'activation imprimé sur sa couverture. Il existe avant même de savoir
  quelle association l'achètera, et n'est rattaché à aucune tombola au
  moment de sa fabrication.
- Un **événement** est la tombola elle-même, créée par une association dans
  son espace organisateur (nom, description, date du tirage, lots à
  gagner). Un événement ne contient aucun billet au départ.

Le lien entre les deux se fait par **activation** : l'organisateur saisit
le code d'activation imprimé sur la couverture d'un carnet qu'il a acheté,
et tous les billets de ce carnet sont alors rattachés à son événement, d'un
coup. Un carnet ne peut être activé qu'une seule fois.

Deux profils :

- **L'organisateur** (l'association) : crée un événement, indique les lots
  à gagner, active un ou plusieurs carnets physiques achetés pour y
  rattacher leurs billets, puis déclenche le tirage lot par lot le jour J.
- **L'acheteur d'un billet** : consulte la page publique de la tombola,
  voit les lots, et vérifie son billet avec juste son code — sans jamais
  donner son nom, son e-mail ou son téléphone.

## Pourquoi si peu d'informations demandées ?

Choix volontaire : on ne demande **jamais** de nom, e-mail ou téléphone à
l'acheteur d'un billet, que ce soit pour vérifier son billet ou consulter les
résultats. Seul le code du billet compte. Moins de données personnelles
stockées, c'est moins de risque en cas de problème (RGPD). Il n'y a donc pas
de table « participants » dans la base de données.

## Ce dont vous avez besoin pour faire tourner la plateforme

Vous n'avez pas besoin de savoir programmer pour ces étapes : il s'agit de
créer deux comptes gratuits (Supabase pour la base de données, Vercel pour
l'hébergement du site) et de copier-coller quelques informations.

### 1. Créer votre projet Supabase (la base de données)

1. Allez sur [supabase.com](https://supabase.com) et créez un compte
   gratuit, puis un nouveau projet (choisissez un mot de passe de base de
   données, gardez-le de côté).
2. Une fois le projet créé, allez dans **Project Settings → API**. Vous y
   trouverez deux informations à copier :
   - la **Project URL** (une adresse commençant par `https://...supabase.co`)
   - la clé **anon public** (une longue chaîne de caractères)
3. Ouvrez le fichier [`assets/tombola.js`](assets/tombola.js) dans ce dépôt,
   et remplacez les deux lignes tout en haut du fichier :

   ```js
   const SUPABASE_URL = "https://VOTRE-PROJET.supabase.co";
   const SUPABASE_ANON_KEY = "VOTRE-CLE-ANON-PUBLIQUE";
   ```

   par vos propres valeurs. (La clé « anon » est publique par nature — elle
   est visible dans le navigateur de tous vos visiteurs — ce n'est pas une
   clé secrète. C'est normal et sans risque : la vraie protection des
   données est assurée par les règles de sécurité appliquées à l'étape
   suivante.)

### 2. Appliquer la structure de la base de données

Dans le tableau de bord Supabase, allez dans **SQL Editor**, créez une
nouvelle requête. Collez et exécutez (**Run**), **dans l'ordre**, le contenu
de chaque fichier du dossier `supabase/migrations/` (un fichier = une
requête = un clic sur Run) :

1. [`0001_init.sql`](supabase/migrations/0001_init.sql) — crée les tables et
   toutes les règles de sécurité.
2. [`0002_tolerance_zeros_billet.sql`](supabase/migrations/0002_tolerance_zeros_billet.sql) —
   permet de vérifier un billet même sans les zéros de tête (« 64 » retrouve
   bien un billet enregistré « 064 »).
3. [`0003_infos_organisation.sql`](supabase/migrations/0003_infos_organisation.sql) —
   ajoute les champs pour présenter l'association organisatrice sur la page
   publique de chaque événement.
4. [`0004_lots_imprimes.sql`](supabase/migrations/0004_lots_imprimes.sql),
   [`0005_generer_lots_imprimes.sql`](supabase/migrations/0005_generer_lots_imprimes.sql),
   [`0006_deuxieme_administrateur.sql`](supabase/migrations/0006_deuxieme_administrateur.sql) et
   [`0011_correction_generation_lots.sql`](supabase/migrations/0011_correction_generation_lots.sql) —
   une première version du système de billets pré-imprimés, entièrement
   remplacée par la migration 0012 ci-dessous. Elles restent dans
   l'historique mais n'ont plus d'effet une fois 0012 appliquée.
5. [`0007_archivage_carnet.sql`](supabase/migrations/0007_archivage_carnet.sql) —
   permet d'archiver un événement terminé pour l'écarter de la liste
   principale.
6. [`0008_exclusion_billets.sql`](supabase/migrations/0008_exclusion_billets.sql) —
   permet d'exclure un billet abîmé ou perdu du tirage au sort, sans le
   supprimer.
7. [`0009_confidentialite_carnets.sql`](supabase/migrations/0009_confidentialite_carnets.sql) —
   empêche de lister tous les événements de la plateforme (voir plus bas).
8. [`0010_icone_carnet.sql`](supabase/migrations/0010_icone_carnet.sql) —
   ajoute une icône décorative au choix pour chaque événement.
9. [`0012_carnets_physiques_et_evenements.sql`](supabase/migrations/0012_carnets_physiques_et_evenements.sql) —
   **rework important** : renomme la table des carnets en `evenements`, et
   introduit la vraie séparation entre carnet physique et événement décrite
   plus haut. Elle remplace l'ancienne saisie manuelle des codes de billets
   par l'organisateur par le système d'activation, et remplace l'outil
   `impression.html` (qui préparait un « lot » = un événement à l'avance)
   par un outil qui prépare de vrais carnets physiques, indépendants de
   tout événement. **Elle supprime les billets et carnets de test existants**
   (les événements et leurs lots sont conservés) : normal, ces données
   n'ont pas d'équivalent dans le nouveau modèle.

Ne relancez pas un script déjà exécuté sur le même projet : chacun n'est
prévu que pour une seule application. Si vous ajoutez ce dépôt à un nouveau
projet Supabase plus tard, il faudra les rejouer tous, dans l'ordre, y
compris 0004/0005/0006/0011 même s'ils sont ensuite recouverts par 0012 —
chaque fichier peut supposer que le précédent a déjà tourné.

### 3. Activer la connexion par e-mail

Dans Supabase, allez dans **Authentication → Providers**, et vérifiez que
« Email » est activé (c'est le cas par défaut). C'est ce qui permet à
l'organisateur de se connecter avec un simple lien reçu par e-mail, sans mot
de passe.

Pensez aussi à ajouter l'adresse de votre site (une fois connu, voir étape
4) dans **Authentication → URL Configuration → Redirect URLs**, sinon le
lien de connexion reçu par e-mail ne fonctionnera pas une fois le site en
ligne.

### 4. Mettre le site en ligne avec Vercel

1. Allez sur [vercel.com](https://vercel.com), créez un compte gratuit et
   connectez-le à votre compte GitHub.
2. Cliquez sur **Add New → Project**, choisissez ce dépôt
   (`tombola-connect`), et laissez les réglages par défaut (aucune commande
   de build n'est nécessaire, c'est un site statique). Cliquez sur
   **Deploy**.
3. Une fois en ligne, Vercel vous donne une adresse (ex :
   `https://tombola-connect.vercel.app`). Ajoutez-la dans Supabase comme
   indiqué à l'étape 3.

Votre site est maintenant accessible : la page d'accueil est
`/page/index.html`, l'espace organisateur `/page/organisateur.html`, et
chaque événement a sa propre page publique `/page/carnet.html?id=...` (le
lien exact est affiché dans l'espace organisateur une fois l'événement
créé).

## Utiliser la plateforme

1. Ouvrez l'espace organisateur, indiquez votre e-mail, cliquez sur le lien
   reçu.
2. Créez un événement (nom de la tombola, description, date du tirage, et
   si vous le souhaitez le nom, la présentation et le contact de
   l'association qui organise, ainsi qu'une icône au choix parmi celles
   proposées — ces informations s'affichent sur la page publique de
   l'événement).
3. Ajoutez les lots, du plus important (rang 1) au dernier. Une erreur de
   frappe ? Chaque lot peut être renommé ou supprimé depuis la liste, et
   l'événement lui-même (nom, description, dates, infos d'organisation)
   peut être modifié à tout moment via « Modifier les informations de
   l'événement ».
4. Activez chaque carnet physique que vous avez acheté : saisissez le code
   d'activation imprimé sur sa couverture dans « Activer un carnet de
   billets ». Tous les billets de ce carnet sont alors rattachés d'un coup à
   votre événement — aucune saisie de code de billet un par un. Vous pouvez
   activer plusieurs carnets sur le même événement si besoin. Un carnet déjà
   activé (sur cet événement ou un autre) ne peut pas l'être une seconde
   fois. Un billet abîmé, perdu ou déchiré avant le tirage ? Indiquez son
   code dans « Exclure un billet du tirage » : il reste enregistré (un
   acheteur peut toujours vérifier son code) mais ne pourra plus être tiré
   au sort. Réintégrable à tout moment.
5. Partagez le lien public de l'événement (affiché dans l'espace
   organisateur) avec les acheteurs de billets. Les billets eux-mêmes
   portent déjà, imprimés par vos soins, le QR qui amène directement sur la
   page de la tombola une fois le carnet activé.
6. Le jour du tirage, ouvrez l'événement dans l'espace organisateur et
   cliquez sur « Tirer ce lot » pour chaque lot, dans l'ordre de votre
   choix. Les visiteurs qui regardent la page publique voient les gagnants
   apparaître en direct, sans recharger la page.
7. Une fois la tombola terminée, cliquez sur « Archiver cet événement » pour
   le sortir de votre liste principale (« Mes événements ») sans rien
   changer pour le public ni pour les billets déjà enregistrés. Un
   événement archivé reste consultable dans la section « Événements
   archivés », et peut être désarchivé à tout moment.

## Carnets physiques et outil de génération

Un carnet physique n'a de sens qu'avant d'être vendu : c'est vous qui le
préparez, bien avant qu'une association ne l'achète et ne l'active sur son
événement. L'outil dédié à cette préparation, `/page/impression.html`,
n'est pas mis en avant ailleurs sur le site et reste réservé à votre
compte administrateur.

Pour chaque carnet, vous choisissez un préfixe de numérotation et un
nombre de billets, et l'outil génère :

- un **QR par billet**, identique en principe sur toute la numérotation
  d'un même carnet, qui pointe vers la page de consultation de la tombola
  (`carnet.html?ref=...`) — c'est celui que l'acheteur scanne ; tant que le
  carnet n'est pas encore activé sur un événement, la page affiche
  simplement que la tombola n'est pas encore configurée ;
- un **QR d'activation**, imprimé une seule fois sur la couverture du
  carnet (jamais sur les billets), qui contient le code secret que
  l'organisateur saisira dans son espace pour rattacher le carnet à son
  événement.

Séparer les deux évite qu'un simple acheteur, en scannant son propre
billet, puisse connaître le code permettant d'activer le carnet à la place
de l'association qui l'a acheté.

## Décisions prises pour vous (et pourquoi)

- **Format des codes de billets** : libre. La base de données ne force
  aucun format particulier (ni longueur, ni préfixe précis) : elle compare
  simplement les codes en majuscules et sans espaces superflus, et ignore
  les zéros de tête du numéro (un billet enregistré « A-064 » est retrouvé
  même si l'acheteur tape « A-64 »), pour tolérer une petite différence de
  saisie. Votre imprimeur peut donc garder sa numérotation habituelle.
- **Plus de lots que de billets rattachés** : si un tirage n'a plus de
  billet disponible (tous les billets rattachés à l'événement ont déjà
  gagné un lot), le bouton « Tirer ce lot » affiche un message d'erreur
  clair plutôt que d'attribuer un même billet à deux lots. Mieux vaut
  ajuster le nombre de lots ou activer un carnet supplémentaire que de
  forcer un tirage incohérent.
- **Pas de vérification de billet depuis l'accueil** : l'accueil ne
  propose plus de choisir une tombola dans une liste déroulante (ça
  aurait révélé le nom de toutes les tombolas de toutes les associations
  utilisant la plateforme, pas seulement les vôtres). La vérification d'un
  billet se fait uniquement depuis la page publique de l'événement
  concerné, via le lien ou le QR code imprimé sur le billet.
- **Aucun événement listable publiquement** : ni la base de données ni
  aucune page ne permettent de récupérer la liste de tous les événements
  existants. Un événement n'est consultable que si l'on connaît déjà son
  lien précis (identifiant technique, ou référence d'un billet dont le
  carnet a été activé) — jamais par une recherche ou un parcours de la
  liste complète, même via un appel direct à Supabase.
- **Un carnet ne s'active qu'une fois** : le code d'activation d'un carnet
  physique est marqué utilisé dès la première activation réussie, sur
  n'importe quel événement. Impossible de rattacher deux fois le même
  carnet, même par erreur.
- **Deux QR codes distincts sur un carnet physique** : le QR des billets
  (public, un par numéro) et le QR d'activation (couverture, secret)
  portent des informations différentes, pour qu'un acheteur ne puisse
  jamais activer un carnet à la place de l'association qui l'a acheté.

## Ce qu'il reste à faire de votre côté

Cette livraison contient tout le code de la plateforme, mais pas
l'infrastructure elle-même (que seul vous pouvez créer avec vos propres
comptes) :

- Créer le projet Supabase et y appliquer les migrations SQL (étapes 1 et 2
  ci-dessus).
- Vérifier que la connexion par e-mail est bien activée (étape 3).
- Connecter ce dépôt à un projet Vercel (étape 4).
- Générer quelques carnets physiques de test avec `/page/impression.html`,
  puis faire un essai complet (création d'un événement, activation d'un
  carnet, un tirage) avant d'utiliser la plateforme pour une vraie tombola.

## Organisation du code

```
assets/tombola.css        styles communs à toutes les pages
assets/tombola.js         connexion à Supabase + fonctions communes
page/index.html           accueil : présentation + vérification de billet
page/organisateur.html    connexion, gestion des événements, activation de carnets, tirage au sort
page/carnet.html          page publique d'un événement (lots, résultats en direct)
page/impression.html      outil réservé à l'administrateur : génère des carnets physiques
supabase/migrations/      structure de la base de données et règles de sécurité
vercel.json               configuration minimale pour l'hébergement Vercel
```

Pas de framework, pas d'étape de build : chaque page est un fichier HTML
autonome, à ouvrir tel quel une fois hébergé.
