// Tombola Connect — initialisation du client Supabase + fonctions communes
// aux 3 pages. Chargé après le script CDN "@supabase/supabase-js" et avant
// le script propre à chaque page.

// ============================================================================
// ⚠️ À REMPLACER : coller ici les valeurs de votre projet Supabase.
// Elles se trouvent dans le tableau de bord Supabase → Project Settings → API.
// La clé "anon" est publique par nature (elle est visible dans le navigateur
// de tout le monde) : ce n'est pas une clé secrète, elle est protégée par les
// règles de sécurité (RLS) définies dans supabase/migrations/0001_init.sql.
// ============================================================================
const SUPABASE_URL = "https://mxcsbrigfuhzcmttpzqz.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_SDkXcdNkJPjjcb9g29MNNQ_e4DwNTca";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ----------------------------------------------------------------------------
// Affichage de messages (succès / erreur / info) dans un conteneur donné.
// ----------------------------------------------------------------------------
function afficherMessage(conteneur, texte, type) {
  conteneur.textContent = texte;
  conteneur.className = "message " + (type || "info");
  conteneur.hidden = false;
}

function effacerMessage(conteneur) {
  conteneur.textContent = "";
  conteneur.hidden = true;
}

// ----------------------------------------------------------------------------
// Formatage d'une date pour l'affichage (ex: "samedi 14 juin 2026 à 20h30").
// ----------------------------------------------------------------------------
function formaterDate(valeurIso) {
  if (!valeurIso) return "Date du tirage non précisée";
  const date = new Date(valeurIso);
  return date.toLocaleDateString("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

// ----------------------------------------------------------------------------
// Construit une liste de codes de billets à partir d'une plage
// (préfixe + numéro de début + numéro de fin), en conservant le même
// nombre de chiffres que le numéro de fin (ex: 001, 002, ... 150).
// ----------------------------------------------------------------------------
function construireCodesDepuisPlage(prefixe, debut, fin) {
  const debutNombre = parseInt(debut, 10);
  const finNombre = parseInt(fin, 10);
  if (Number.isNaN(debutNombre) || Number.isNaN(finNombre) || finNombre < debutNombre) {
    throw new Error("La plage de numéros n'est pas valide (le début doit être inférieur ou égal à la fin).");
  }
  const nbChiffres = String(fin).trim().length;
  const codes = [];
  for (let n = debutNombre; n <= finNombre; n++) {
    codes.push(prefixe + String(n).padStart(nbChiffres, "0"));
  }
  return codes;
}

// ----------------------------------------------------------------------------
// Découpe une liste collée (un code par ligne, ou séparés par des virgules
// ou espaces) en tableau de codes non vides.
// ----------------------------------------------------------------------------
function construireCodesDepuisListe(texte) {
  return texte
    .split(/[\s,;]+/)
    .map((code) => code.trim())
    .filter((code) => code.length > 0);
}

// ----------------------------------------------------------------------------
// Lit dans l'URL soit l'identifiant technique d'un événement (?id=...,
// lien copié depuis l'espace organisateur), soit la référence publique
// imprimée sur un billet (?ref=..., lien encodé dans le QR code de chaque
// billet d'un carnet physique — choisie avant même qu'aucun événement
// n'existe, donc résolue séparément).
// ----------------------------------------------------------------------------
function identifiantEvenementDepuisUrl() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("id");
  const ref = params.get("ref");
  if (!id && !ref) return null;
  return { id, ref };
}

function idCarnetDepuisUrl() {
  return new URLSearchParams(window.location.search).get("id");
}
