# Tombola Connect

Plateforme web pour accompagner vos carnets de tombola papier « connectés » :
chaque billet porte un code unique préimprimé, et cette plateforme permet de
suivre en ligne l'inscription des billets et le tirage au sort, en direct.

Deux profils :

- **L'organisateur** (l'association qui a acheté les carnets) : crée un
  carnet, indique les lots à gagner, enregistre les codes des billets déjà
  imprimés, puis déclenche le tirage lot par lot le jour J.
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
   publique de chaque carnet.
4. [`0004_lots_imprimes.sql`](supabase/migrations/0004_lots_imprimes.sql) —
   permet de relier un carnet à un lot de billets déjà imprimés à l'avance
   (voir [Billets pré-imprimés avec QR code](#billets-pré-imprimés-avec-qr-code)
   plus bas).
5. [`0005_generer_lots_imprimes.sql`](supabase/migrations/0005_generer_lots_imprimes.sql) —
   ajoute l'outil (page `impression.html`) qui prépare de nouveaux lots
   avant l'impression.
6. [`0006_deuxieme_administrateur.sql`](supabase/migrations/0006_deuxieme_administrateur.sql) —
   reconnaît une deuxième adresse e-mail administrateur pour cet outil.
7. [`0007_archivage_carnet.sql`](supabase/migrations/0007_archivage_carnet.sql) —
   permet d'archiver un carnet terminé pour l'écarter de la liste
   principale.
8. [`0008_exclusion_billets.sql`](supabase/migrations/0008_exclusion_billets.sql) —
   permet d'exclure un billet abîmé ou perdu du tirage au sort, sans le
   supprimer.
9. [`0009_confidentialite_carnets.sql`](supabase/migrations/0009_confidentialite_carnets.sql) —
   empêche de lister tous les carnets de la plateforme (voir plus bas).
10. [`0010_icone_carnet.sql`](supabase/migrations/0010_icone_carnet.sql) —
    ajoute une icône décorative au choix pour chaque carnet.

Ne relancez pas un script déjà exécuté sur le même projet : chacun n'est
prévu que pour une seule application. Si vous ajoutez ce dépôt à un nouveau
projet Supabase plus tard, il faudra les rejouer tous, dans l'ordre.

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
chaque carnet a sa propre page publique `/page/carnet.html?id=...` (le lien
exact est affiché dans l'espace organisateur une fois le carnet créé).

## Utiliser la plateforme

1. Ouvrez l'espace organisateur, indiquez votre e-mail, cliquez sur le lien
   reçu.
2. Créez un carnet (nom de la tombola, description, date du tirage, et si
   vous le souhaitez le nom, la présentation et le contact de l'association
   qui organise, ainsi qu'une icône au choix parmi celles proposées — ces
   informations s'affichent sur la page publique du carnet).
3. Ajoutez les lots, du plus important (rang 1) au dernier. Une erreur de
   frappe ? Chaque lot peut être renommé ou supprimé depuis la liste, et le
   carnet lui-même (nom, description, dates, infos d'organisation) peut être
   modifié à tout moment via « Modifier les informations du carnet ».
4. Enregistrez les codes des billets déjà imprimés : soit une plage (par
   exemple préfixe `A-`, de `1` à `500`), soit une liste collée depuis un
   fichier de votre imprimeur. Un billet abîmé, perdu ou déchiré avant le
   tirage ? Indiquez son code dans « Exclure un billet du tirage » : il
   reste enregistré (un acheteur peut toujours vérifier son code) mais ne
   pourra plus être tiré au sort. Réintégrable à tout moment.
5. Partagez le lien public du carnet (affiché dans l'espace organisateur)
   avec les acheteurs de billets, ou téléchargez le QR code fourni juste en
   dessous et faites-le imprimer sur les billets par votre imprimeur : un
   scan amène directement sur la page de la tombola.
6. Le jour du tirage, ouvrez le carnet dans l'espace organisateur et cliquez
   sur « Tirer ce lot » pour chaque lot, dans l'ordre de votre choix. Les
   visiteurs qui regardent la page publique voient les gagnants apparaître
   en direct, sans recharger la page.
7. Une fois la tombola terminée, cliquez sur « Archiver ce carnet » pour le
   sortir de votre liste principale (« Mes carnets ») sans rien changer
   pour le public ni pour les billets déjà enregistrés. Un carnet archivé
   reste consultable dans la section « Carnets archivés », et peut être
   désarchivé à tout moment.

## Billets pré-imprimés avec QR code

Pour les carnets vendus avec des billets déjà imprimés à l'avance (avant
même de savoir quelle association les achètera), deux QR codes différents
sont prévus :

- Un **QR public**, identique sur chaque billet du carnet, qui pointe vers
  la page de consultation de la tombola (`carnet.html?ref=...`). C'est celui
  que les acheteurs scannent.
- Un **QR d'activation**, imprimé une seule fois sur la couverture du
  carnet (jamais sur les billets), qui contient en plus une clé secrète.
  C'est celui que l'association scanne pour configurer son carnet : la page
  de l'espace organisateur s'ouvre automatiquement pré-remplie, il ne reste
  qu'à créer le carnet (nom, lots...) pour que tout soit relié — aucune
  saisie manuelle de code n'est nécessaire.

Séparer les deux évite qu'un simple acheteur, en scannant son propre
billet, puisse connaître de quoi configurer un carnet à la place de
l'association.

**Avant l'impression d'un nouveau lot**, préparez les références et clés
d'activation avec l'outil dédié : `/page/impression.html`. Cette page n'est
pas mise en avant ailleurs sur le site (elle n'est utile qu'à vous) et est
réservée à votre compte : indiquez combien de carnets vous préparez,
l'outil génère chaque référence, sa clé secrète, et les deux images de QR
code prêtes à télécharger et à transmettre à votre imprimeur (le QR des
billets et le QR de couverture, pour chaque lot).

Un carnet créé sans passer par un QR d'activation fonctionne normalement :
son lien public utilise alors son identifiant technique
(`carnet.html?id=...`) plutôt qu'une référence imprimée.

## Décisions prises pour vous (et pourquoi)

- **Format des codes de billets** : libre. La base de données ne force
  aucun format particulier (ni longueur, ni préfixe précis) : elle compare
  simplement les codes en majuscules et sans espaces superflus, et ignore
  les zéros de tête du numéro (un billet enregistré « A-064 » est retrouvé
  même si l'acheteur tape « A-64 »), pour tolérer une petite différence de
  saisie. Votre imprimeur peut donc garder sa numérotation habituelle.
- **Plus de lots que de billets enregistrés** : si un tirage n'a plus de
  billet disponible (tous les billets enregistrés ont déjà gagné un lot sur
  ce carnet), le bouton « Tirer ce lot » affiche un message d'erreur clair
  plutôt que d'attribuer un même billet à deux lots. Mieux vaut ajuster le
  nombre de lots ou enregistrer davantage de billets que de forcer un
  tirage incohérent.
- **Pas de vérification de billet depuis l'accueil** : l'accueil ne
  propose plus de choisir une tombola dans une liste déroulante (ça
  aurait révélé le nom de toutes les tombolas de toutes les associations
  utilisant la plateforme, pas seulement les vôtres). La vérification d'un
  billet se fait uniquement depuis la page publique du carnet concerné,
  via le lien ou le QR code fourni par l'organisateur.
- **Aucun carnet listable publiquement** : ni la base de données ni
  aucune page ne permettent de récupérer la liste de tous les carnets
  existants. Un carnet n'est consultable que si l'on connaît déjà son
  lien précis (identifiant technique ou référence imprimée) — jamais par
  une recherche ou un parcours de la liste complète, même via un appel
  direct à Supabase.
- **Deux QR codes distincts pour les billets pré-imprimés** : le QR des
  billets (public) et le QR d'activation (couverture, secret) portent des
  informations différentes, pour qu'un acheteur ne puisse jamais configurer
  un carnet à la place de l'association qui a acheté les billets.

## Ce qu'il reste à faire de votre côté

Cette livraison contient tout le code de la plateforme, mais pas
l'infrastructure elle-même (que seul vous pouvez créer avec vos propres
comptes) :

- Créer le projet Supabase et y appliquer la migration SQL (étapes 1 et 2
  ci-dessus).
- Vérifier que la connexion par e-mail est bien activée (étape 3).
- Connecter ce dépôt à un projet Vercel (étape 4).
- Faire un essai complet (création d'un carnet de test, quelques billets,
  un tirage) avant d'utiliser la plateforme pour une vraie tombola.

## Organisation du code

```
assets/tombola.css        styles communs à toutes les pages
assets/tombola.js         connexion à Supabase + fonctions communes
page/index.html           accueil : présentation + vérification de billet
page/organisateur.html    connexion, gestion des carnets, tirage au sort
page/carnet.html          page publique d'un carnet (lots, résultats en direct)
page/impression.html      outil réservé à l'administrateur : prépare les lots à imprimer
supabase/migrations/      structure de la base de données et règles de sécurité
vercel.json               configuration minimale pour l'hébergement Vercel
```

Pas de framework, pas d'étape de build : chaque page est un fichier HTML
autonome, à ouvrir tel quel une fois hébergé.
