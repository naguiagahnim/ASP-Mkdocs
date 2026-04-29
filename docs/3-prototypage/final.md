# Chatbot final 

## Vue d'ensemble

Ce projet représente une évolution majeure du prototype initial de chatbot à base de recherche BM25. L'architecture s'est transformée d'un simple moteur de recherche sémantique en un **système complet d'acquisition, d'extraction et de recherche documentaire automatisé** utilisant l'OCR Mistral, un CLI Rust, et un moteur hybride BM25+LLM.

## Architecture globale du système

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DOCUMENTS SOURCE                                │
│         PDF / PNG / JPG (Guides ASP, procédures ESAT)              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        CLI RUST (cli/)                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 3 Modes : LocalDocuments │ FetchFromList │ PdfToPng        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                    │                                │
│                                    ▼                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │           MISTRAL OCR (via LiteLLM Proxy)                    │   │
│  │  - Encodage base64 des documents                            │   │
│  │  - Annotation JSON schema (base.json)                       │   │
│  │  - Extraction structurée (id, procédures, FAQ, UI, etc.)   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                    │                                │
│                                    ▼                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │        RÉSULTATS JSON (data/cli_results/results.json)       │   │
│  │  Format : DocumentAnalysisResult { meta, entries[] }        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CHATBOT (chatbot/)                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              BM25Finder (Hybride)                           │   │
│  │                                                             │   │
│  │  1. Reformulation LLM (BM25_REFORMULATION_PROMPT)           │   │
│  │     ↓                                                        │   │
│  │  2. Recherche exacte par ID (prioritaire)                    │   │
│  │     ↓                                                        │   │
│  │  3. Scoring BM25 (Embedder + Scorer + IDF)                 │   │
│  │     ↓                                                        │   │
│  │  4. Recherche contextuelle (related_intents, domain)         │   │
│  │     ↓                                                        │   │
│  │  5. Synthèse LLM (BM25_SYNTHESIS_PROMPT)                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                    │                                │
│                                    ▼                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              RÉPONSE UTILISATEUR                             │   │
│  │  Format Markdown structuré avec procédures, alertes, FAQ    │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Interface en ligne de commande (`cli/`)

### Objectif et rôle

Le CLI est un outil Rust autonome dont la mission est de **transformer des documents administratifs non structurés (PDF, PNG) en données structurées JSON** prêtes à être consommées par le moteur de recherche du chatbot.

### Structure du code

```
cli/
├── Cargo.toml                  # Dépendances : reqwest, serde, base64, etc.
├── base.json                   # Schéma JSON Schema pour l'OCR
├── src/
│   ├── main.rs                 # Point d'entrée, sélection du mode, orchestration
│   ├── mistral.rs              # Client OCR Mistral via LiteLLM
│   ├── process.rs              # Logique de téléchargement et conversion PDF→PNG
│   ├── document_processor.rs   # Structures de données (DocumentEntry, etc.)
│   └── lib.rs                 # Module exports
└── documents/                  # Dossier des PDF locaux à traiter
```

### Modes opérationnels

Le CLI propose **3 modes** définis dans `cli/src/main.rs:16-21` :

| Mode | Variante | Source | Traitement |
|------|----------|--------|------------|
| `LocalDocuments` | 1 | Dossier `documents/` | Analyse directe des PDF locaux |
| `FetchFromList` | 2 | URL liste distante | Télécharge les PNG depuis `http://demo-chatbot.s3.fr-par.scw.cloud/guides/png/liste.png.txt` puis analyse |
| `PdfToPng` | 3 | PDF local | Convertit le PDF en PNG (ImageMagick) puis analyse chaque page |

#### Flux détaillé du mode LocalDocuments (`main.rs:87-113`)

```rust
Mode::LocalDocuments => {
    // 1. Découverte des documents
    let documents = find_documents(&documents_dir);  // Scan documents/*.pdf
    
    // 2. Analyse séquentielle avec gestion d'erreurs
    run_analysis(documents.iter().map(|p| (p.as_path(), filename)))
}
```

#### Fonction `run_analysis` (`main.rs:160-217`)

Cette fonction orchestre l'analyse avec :
- **Affichage de progression** : `[1/5] Analyzing: document.pdf...`
- **Gestion des rate limits** : En cas d'erreur 429, attend 10s et retry
- **Délai entre requêtes** : 3 secondes (`DELAY_NORMAL_SECS`)
- **Collecte des résultats** et erreurs

### Gestion des erreurs et résilience

```rust
// main.rs:181-199
if error_msg.contains("429") || error_msg.to_lowercase().contains("too many requests") {
    println!("Rate limited, waiting {} seconds before retry...", DELAY_RATE_LIMIT_SECS);
    thread::sleep(Duration::from_secs(DELAY_RATE_LIMIT_SECS));
    
    // Retry unique
    match mistral::analyze_local_document(&doc_path.to_path_buf()) {
        Ok(result) => { /* succès */ }
        Err(retry_err) => { errors.push((filename, retry_err.to_string())); }
    }
}
```

### Sortie des résultats

Les résultats sont sauvegardés dans `data/cli_results/results.json` au format :

```json
[
  {
    "meta": {
      "version": "1.0",
      "created": "2026-04-27T10:30:00Z",
      "language": "fr",
      "source_document": "guide_esat.pdf"
    },
    "entries": [ /* DocumentEntry[] */ ]
  }
]
```

---

## Intégration Mistral OCR (`cli/src/mistral.rs`)

### Principe technique

L'OCR Mistral est appelé via un **proxy LiteLLM** qui unifie l'accès aux modèles. Le endpoint utilisé est `{OPENAI_BASE_URL}/ocr`.

### Configuration via variables d'environnement

```rust
// mistral.rs:17-31
pub struct ApiConfiguration {
    base_url: String,    // ex: https://litellm-proxy.example.com
    api_key: String,     // Clé API
    model: String,       // ex: "mistral/mistral-ocr-latest"
}

impl ApiConfiguration {
    pub fn from_env() -> Self {
        let base_url = env::var("OPENAI_BASE_URL")?;
        let api_key = env::var("OPENAI_API_KEY")?;
        let model = env::var("OPENAI_OCR_MODEL")?;
        // ...
    }
}
```

### Préparation du document

Le document est lu, encodé en base64, puis transformé en Data URI :

```rust
// mistral.rs:161-169
let file_data = fs::read(path)?;
let base64_data = STANDARD.encode(&file_data);

let mime_type = match path.extension().and_then(|e| e.to_str()) {
    Some("pdf") => "application/pdf",
    Some("png") => "image/png",
    Some("jpg") | Some("jpeg") => "image/jpeg",
    _ => "application/octet-stream",
};

let data_uri = format!("data:{};base64,{}", mime_type, base64_data);
```

### Requête OCR avec schéma d'annotation

La requête utilise le format `document_annotation_format` pour forcer la sortie JSON :

```rust
// mistral.rs:181-211
let request = OcrRequest {
    model: api_configuration.model,
    temperature: 0.1,  // Très déterministe
    document: Document {
        document_type: "document_url".to_string(),
        document_url: data_uri,
    },
    document_annotation_format: Some(serde_json::json!({
        "type": "json_schema",
        "json_schema": {
            "name": "document_annotation",
            "schema": document_annotation_schema()  // Charge base.json
        }
    })),
    document_annotation_prompt: Some(
        "Analyse ce document et extrait les informations structurées. \
         Pour chaque page/écran identifié, remplis les champs: \
         id, domain, intent, category, summary, keywords, \
         breadcrumb_trail, context_prerequisites, procedure, faq, \
         alerts, ui_coordinates. Sois précis et exhaustif.".to_string()
    ),
    include_image_base64: Some(false),  // Économise la bande passante
};
```

### Schéma d'extraction (`base.json`)

Le fichier `cli/base.json` définit la structure JSON extraite. Il est utilisé de deux façons :

1. **Pour la validation** : Le champ `document_annotation_format` de l'API
2. **Pour la fallback** : La fonction `document_annotation_schema()` (`mistral.rs:34-94`) extrait la sous-partie `entries.items` pour l'OCR

#### Nouveaux champs par rapport au document BM25 original

| Champ | Type | Description | Nouveauté |
|-------|------|-------------|-----------|
| `breadcrumb_trail` | string | Fil d'Ariane visible dans l'interface (ex: "Accueil > ESAT > Déclarations") | Nouveau |
| `context_prerequisites` | string | Contenu de la page précédente (contexte avant l'écran actuel) | Nouveau |
| `ui_coordinates` | object | Coordonnées des éléments UI positionnés (top_left, center, etc.) | Nouveau |
| `locations` | array[object] | Organismes avec type, nom, adresse | Enrichi |
| `alerts` | array[object] | Alertes avec type (info/warning/error) et message | Inchangé |

#### Structure de `ui_coordinates` (`document_processor.rs:83-95`)

```rust
pub struct UICoordinates {
    pub top_left_elements: Option<Vec<UIElement>>,
    pub top_right_elements: Option<Vec<UIElement>>,
    pub bottom_left_elements: Option<Vec<UIElement>>,
    pub bottom_right_elements: Option<Vec<UIElement>>,
    pub center_elements: Option<Vec<UIElement>>,
}

pub struct UIElement {
    pub element_type: String,  // "button", "link", "input", etc.
    pub label: String,          // Texte visible
    pub position: Option<String>,
    pub action: Option<String>, // Action déclenchée
}
```

### Parsing de la réponse OCR

La réponse de Mistral OCR contient soit une annotation structurée, soit des pages markdown :

```rust
// mistral.rs:231-301
let ocr_response: MistralOCRResponse = serde_json::from_str(&response_text)?;

let entries: Vec<DocumentEntry> = if had_valid_annotation && !parsed_entries.is_empty() {
    parsed_entries  // Utilise les données structurées
} else {
    // Fallback : crée une entrée par page avec le markdown brut
    ocr_response.pages.iter().map(|page| DocumentEntry {
        id: format!("page_{}", page.index),
        summary: Some(page.markdown.clone()),
        // autres champs à "unknown" ou None
    }).collect()
};
```

### Fonction `parse_annotation_entries` (`mistral.rs:304-350`)

Cette fonction robuste gère plusieurs formats de réponse :

1. **Format direct** : `annotation["entries"]` est un array
2. **Format imbriqué** : `annotation["properties"]["entries"]` (schéma)
3. **Format stringifié** : L'annotation est une chaîne JSON encodée

Les entrées avec `domain == "unknown"` ou `id` vide sont filtrées.

---

## Traitement des documents (`cli/src/process.rs`)

### FetchFromList (`process.rs:18-133`)

Télécharge une liste de fichiers depuis une URL distante :

```rust
const BASE_URL: &str = "http://demo-chatbot.s3.fr-par.scw.cloud/guides/png";
const LIST_URL: &str = "http://demo-chatbot.s3.fr-par.scw.cloud/guides/png/liste.png.txt";

pub fn fetch_and_analyze_from_list(output_dir: &Path) -> Result<...> {
    // 1. Télécharge la liste
    let list_response = client.get(LIST_URL).send()?;
    let file_names: Vec<String> = list_content.lines()
        .filter(|l| !l.is_empty() && !l.ends_with(".txt"))
        .map(|l| l.to_string())
        .collect();
    
    // 2. Pour chaque fichier
    for file_name in file_names {
        let file_url = format!("{}/{}", BASE_URL, file_name);
        let bytes = client.get(&file_url).send()?.bytes()?;
        
        // 3. Sauvegarde localement temporairement
        let local_path = download_dir.join(file_name);
        fs::write(&local_path, &bytes)?;
        
        // 4. Analyse avec Mistral OCR
        match mistral::analyze_local_document(&local_path) { ... }
    }
    
    // 5. Nettoyage
    let _ = fs::remove_dir_all(&download_dir);
}
```

### PdfToPng (`process.rs:135-255`)

Convertit un PDF en pages PNG avec ImageMagick :

```rust
pub fn convert_pdf_to_pngs_and_analyze(pdf_path: &Path, output_dir: &Path) -> Result<...> {
    // Conversion avec ImageMagick (density 300 DPI)
    let status = Command::new("convert")
        .arg("-density")
        .arg("300")          // Haute qualité pour l'OCR
        .arg(pdf_path)
        .arg(&output_pattern) // "nom_%03d.png"
        .status()?;
    
    // Analyse chaque PNG généré
    for png_path in png_files {
        match mistral::analyze_local_document(png_path) { ... }
    }
}
```

---

## Structures de données (`cli/src/document_processor.rs`)

### DocumentEntry - L'entrée structurée

```rust
pub struct DocumentEntry {
    pub id: String,
    pub domain: String,
    pub intent: String,
    pub category: String,
    pub location_context: Option<Vec<String>>,
    pub keywords: Option<Vec<String>>,
    pub summary: Option<String>,
    pub procedure: Option<Procedure>,
    pub locations: Option<Vec<Location>>,
    pub faq: Option<Vec<FAQEntry>>,
    pub images: Option<Vec<ImageRef>>,
    pub alerts: Option<Vec<Alert>>,
    pub related_intents: Option<Vec<String>>,
    pub context_prerequisites: Option<String>,   // Nouveau
    pub breadcrumb_trail: Option<String>,         // Nouveau
    pub ui_coordinates: Option<UICoordinates>,   // Nouveau
}
```

Les champs `Option<...>` utilisent `#[serde(skip_serializing_if = "Option::is_none")]` pour alléger le JSON.

### DocumentAnalysisResult - Le résultat complet

```rust
pub struct DocumentAnalysisResult {
    pub meta: AnalysisMeta,
    pub entries: Vec<DocumentEntry>,
}
```

---

## Évolution du BM25 Finder (`chatbot/src/domain/bm25_finder.rs`)

### Architecture hybride

Le `BM25Finder` a évolué d'un simple moteur BM25 vers un **système hybride** combinant :

1. **Recherche lexicale BM25** (avec pondérations avancées)
2. **Reformulation de requêtes par LLM** (avant recherche)
3. **Synthèse de réponse par LLM** (après recherche)
4. **Gestion contextuelle** (via `RwLock<Option<KnowledgeEntry>>`)

### Configuration Bm25Config (`bm25_finder.rs:10-135`)

#### Nouveaux champs de configuration

```rust
pub struct Bm25Config {
    pub field_weights: HashMap<String, f32>,
    pub idf_weights: HashMap<String, f32>,
    pub b: f32,                // Paramètre de normalisation (0.75)
    pub k1: f32,               // Paramètre de saturation (1.5)
    pub min_score_threshold: f32, // Seuil de pertinence (0.08 - abaissé !)
    pub avgdl: f32,            // Longueur moyenne du corpus (300.0)
}
```

#### Pondérations de champs enrichies

| Champ | Ancien poids | Nouveau poids | Justification |
|-------|-------------|---------------|---------------|
| `id` | Non utilisé | **5.0** | Identifiant unique = match prioritaire |
| `intent` | 1.5 | **3.5** | Intention critique pour le matching |
| `keywords` | 3.0 | **3.2** | Léger ajustement |
| `summary` | 2.0 | **2.8** | Augmenté |
| `procedure_steps` | 1.5 | **2.5** | Nouveau champ décomposé |
| `faq_q` | 1.0 | **2.5** | Questions FAQ très pondérées |
| `faq_a` | 1.0 | **2.0** | Réponses FAQ |
| `domain` | 1.5 | **2.0** | Meilleur filtrage thématique |
| `category` | Non présent | **1.8** | Nouveau |
| `breadcrumb_trail` | Non présent | **1.8** | Nouveau |
| `context_prerequisites` | Non présent | **1.5** | Nouveau |
| `alerts` | Non présent | **1.5** | Nouveau |
| `related_intents` | Non présent | **1.5** | Nouveau |
| `procedure_required` | Non présent | **1.5** | Nouveau |
| `images_description` | Non présent | **1.2** | Nouveau |

#### Pondération IDF spécifique enrichie

Le nombre de termes avec poids personnalisés est passé d'une dizaine à **plus de 70 termes** (`bm25_finder.rs:39-121`) :

| Catégorie | Termes | Poids typiques |
|-----------|--------|----------------|
| **ESAT** | `esat2` (2.5), `esat` (2.0), `dm` (1.9) | 1.9 - 2.5 |
| **Déclarations** | `declaration` (1.8), `declaration mensuelle` (2.5) | 1.8 - 2.5 |
| **Acteurs** | `mandataire` (2.0), `travailleur` (1.8), `travailleur handicape` (2.5) | 1.8 - 2.5 |
| **Organismes** | `asp` (1.6), `ars` (1.7), `finess` (1.7) | 1.6 - 1.7 |
| **Identifiants** | `dsn` (1.8), `nir` (1.8), `siret` (1.8) | 1.8 |
| **Actions** | `initialisation` (1.9), `creer` (1.6), `modifier` (1.6) | 1.6 - 1.9 |
| **Concepts** | `habiliation` (1.7), `cotisation` (1.7), `paiement` (1.6) | 1.6 - 1.7 |
| **Éléments UI** | `ecran` (1.4), `bouton` (1.3), `menu` (1.4) | 1.3 - 1.4 |

### Reformulation de requêtes par LLM

Avant la recherche BM25, le message utilisateur est reformulé par un LLM via le prompt `BM25_REFORMULATION_PROMPT` (`bm25_finder.rs:152-216`).

#### Objectif du prompt

```
Tu es un expert en reformulation de requetes pour un moteur de recherche BM25 
dans une base de connaissances technique de l'ASP.
```

#### Règles de reformulation

1. **Détection exacte** : Si la question contient un ID, sigle ou mot-clé technique → LE CONSERVER ABSOLUMENT
2. **Analyse de l'intention** : Procédurelle, informationnelle, problème, ou mot-clé direct
3. **Entités métier** : Identifier sigles (ESAT, DSN, FINESS), concepts, actions
4. **Construction** (6-15 termes) : Inclure marqueurs + mots-clés, verbe d'action + objet
5. **Nettoyage** : Supprimer articles, prépositions, pronoms, formulations polies

#### Exemples du prompt

| Question utilisateur | Requête reformulée |
|----------------------|-------------------|
| "Comment declarer les travailleurs handicapes a l'ASP?" | "creer declaration mensuelle ESAT travailleurs handicapes procedure" |
| "C'est quoi un ESAT?" | "ESAT definition etablissement service accompagnement travail" |
| "J'ai une erreur quand je veux valider ma declaration" | "erreur validation declaration ESAT probleme" |
| "Fiche ESPACE001" | "ESPACE001" |
| "aide au poste" | "aide au poste ESAT" |

#### Implémentation dans `trouver_reponse` (`bm25_finder.rs:585-595`)

```rust
let reformulated_query = tokio::task::block_in_place(|| {
    runtime.block_on(async {
        api_interrogator::request_with_system(message, BM25_REFORMULATION_PROMPT)
            .await
            .ok()?
            .choices
            .first()
            .map(|c| c.message.content.trim().to_string())
    })
})
.unwrap_or_else(|| message.to_string());  // Fallback sur le message original
```

### Recherche hybride dans `find_entry_with_context` (`bm25_finder.rs:428-477`)

La recherche suit un pipeline en 3 étapes :

#### Étape 1 : Recherche exacte par ID (`bm25_finder.rs:431-434`)

```rust
if let Some(entry) = self.search_by_exact_id(&msg_lower) {
    info!("Match exact par ID : id={}", entry.id);
    return Some((1.0, entry));  // Score parfait
}
```

La fonction `search_by_exact_id` (`bm25_finder.rs:479-494`) vérifie si le message contient :
- Un `id` d'entrée (ex: "ESPACE001")
- Un `keyword` d'entrée (longueur > 4)

#### Étape 2 : Scoring BM25 avec critères multiples (`bm25_finder.rs:436-465`)

```rust
let query_embedding = Self::embed_with_weights(&self.embedder, message, &self.config.idf_weights);
let matches = self.scorer.matches(&query_embedding);

for best in matches.iter().take(5) {  // Top 5 résultats
    if let Some(ie) = self.indexed_entries.get(best.id) {
        let entry_keywords = ie.entry.keywords.join(" ");
        let combined = format!("{} {} {}", ie.entry.id, ie.entry.summary, entry_keywords);
        let combined_lower = combined.to_lowercase();
        
        // Compte le nombre de mots de la requête présents dans l'entrée
        let match_count = msg_lower.split_whitespace()
            .filter(|w| w.len() > 2 && combined_lower.contains(w))
            .count();
        
        let required_matches = if msg_lower.split_whitespace().count() <= 3 { 1 } else { 2 };
        
        // Match si assez de mots correspondent OU score élevé (> 0.15)
        if match_count >= required_matches || best.score > 0.15 {
            return Some((best.score, &ie.entry));
        }
    }
}
```

#### Étape 3 : Fallback avec seuil minimal (`bm25_finder.rs:467-476`)

```rust
if let Some(best) = matches.first() {
    if best.score >= self.config.min_score_threshold {  // 0.08
        return self.indexed_entries.get(best.id)
            .map(|ie| (best.score, &ie.entry));
    }
}
```

### Gestion contextuelle améliorée (`bm25_finder.rs:496-557`)

La fonction `search_with_context` gère les questions de suivi de manière sophistiquée :

```rust
fn search_with_context(&self, message: &str) -> Option<(f32, &KnowledgeEntry)> {
    let current_context = self.context.read().unwrap();
    if let Some(ctx) = current_context.as_ref() {
        let msg = message.to_lowercase();
        
        // Mots-contextuels étendus
        let mots_contextuels = [
            "et pour", "et comment", "et si", "dans ce cas",
            "comment faire", "la procédure", "ensuite", "apres",
            "suite", "continuer",
        ];
        
        if mots_contextuels.iter().any(|m| msg.contains(m)) {
            // Filtre les candidats par domaine ou intentions liées
            let candidates: Vec<&KnowledgeEntry> = self.knowledge_base.entries.iter()
                .filter(|e| e.id != ctx.id && (
                    e.domain == ctx.domain || 
                    e.related_intents.contains(&ctx.intent)
                ))
                .collect();
            
            // Recherche par similarité cosinus parmi les candidats
            for candidate in candidates {
                let candidate_text = format!("{} {} {} {}", 
                    candidate.id, candidate.intent, 
                    candidate.summary, candidate.keywords.join(" "));
                
                let query_emb = Self::embed_with_weights(...);
                let candidate_emb = Self::embed_with_weights(...);
                let similarity = Self::cosine_similarity(&query_emb, &candidate_emb);
                
                if similarity > best_score && similarity > 0.05 {
                    best_score = similarity;
                    best_entry = Some(candidate);
                }
            }
        }
    }
    // Fallback sur la recherche normale
    self.find_entry_with_context(message)
}
```

### Synthèse de réponse par LLM

Une fois l'entrée trouvée, le LLM génère une réponse formatée via `BM25_SYNTHESIS_PROMPT` (`bm25_finder.rs:218-242`) :

```rust
let final_response = tokio::task::block_in_place(|| {
    runtime.block_on(async {
        let extracted_data = serde_json::to_string_pretty(&entry).unwrap_or_default();
        let prompt = BM25_SYNTHESIS_PROMPT
            .replace("{extracted_data}", &extracted_data)
            .replace("{user_question}", message);
        
        match api_interrogator::request_with_system(message, &prompt).await {
            Ok(resp) => resp.choices.first()
                .map(|c| c.message.content.trim().to_string())
                .unwrap_or_else(|| entry.summary.clone()),
            Err(_) => entry.summary.clone(),  // Fallback
        }
    })
});
```

#### Règles du prompt de synthèse

```
REGLES OBLIGATOIRES:
1. Base-toi EXCLUSIVEMENT sur les donnees extraites
2. Utilise le format MARKDOWN:
   - ## pour les titres principaux
   - ### pour les sous-titres
   - **texte** pour le gras
   - 1. pour les listes ordonnees (etapes)
   - > pour les alertes
   - `code` pour les donnees techniques
3. Si une procedure existe, presente-la en liste ordonnee
4. Si des alertes sont presentes, utilise le format >
5. Ne mentionne pas les codes techniques (IDs)
```

### Construction du corpus textuel (`bm25_finder.rs:293-352`)

La fonction `build_corpus_text` agrège tous les champs pour l'indexation BM25 :

```rust
fn build_corpus_text(entry: &KnowledgeEntry) -> String {
    let mut parts = Vec::new();
    
    // Identifiants et métadonnées
    parts.push(entry.id.clone());
    parts.push(entry.domain.clone());
    parts.push(entry.intent.clone());
    parts.push(entry.category.clone());
    
    // Mots-clés (doublés : pris 2 fois pour renforcer le poids)
    parts.extend(entry.keywords.iter().cloned());
    parts.extend(entry.keywords.iter().take(8).cloned());
    
    // Contenu principal
    parts.push(entry.summary.clone());
    
  // Procédure
    if let Some(ref proc) = entry.procedure {
        parts.extend(proc.steps.iter().cloned());
        parts.extend(proc.required_documents.iter().cloned());
        parts.extend(proc.optional_documents.iter().cloned());
    }
    
    // FAQ
    for faq in &entry.faq {
        parts.push(faq.q.clone());
        parts.push(faq.a.clone());
    }
    
    // Contexte et métadonnées enrichies
    parts.extend(entry.related_intents.iter().cloned());
    for alert in &entry.alerts {
        parts.push(alert.message.clone());
    }
    for loc in &entry.location_context {
        parts.push(loc.clone());
    }
    
    // Nouveaux champs du document OCR
    if let Some(ref bc) = entry.breadcrumb_trail { parts.push(bc.clone()); }
    if let Some(ref cp) = entry.context_prerequisites { parts.push(cp.clone()); }
    for img in &entry.images {
        parts.push(img.description.clone());
    }
    
    parts.join(" ")
}
```

**Particularité** : Les mots-clés sont volontairement dupliqués (lignes 310-311) pour augmenter leur poids dans le corpus BM25.

### Similarité cosinus (`bm25_finder.rs:404-426`)

Utilisée pour la recherche contextuelle entre embeddings :

```rust
fn cosine_similarity(a: &Embedding, b: &Embedding) -> f32 {
    let a_vec: HashMap<u32, f32> = a.0.iter().map(|t| (t.index, t.value)).collect();
    let b_vec: HashMap<u32, f32> = b.0.iter().map(|t| (t.index, t.value)).collect();
    
    let mut dot = 0.0;
    let mut norm_a = 0.0;
    let mut norm_b = 0.0;
    
    for (idx, val_a) in &a_vec {
        norm_a += val_a * val_a;
        if let Some(val_b) = b_vec.get(idx) {
            dot += val_a * val_b;
        }
    }
    // ...
}
```

---

## API Interrogator (`chatbot/src/api_interrogator.rs`)

### Rôle

Ce module gère les appels asynchrones aux modèles de langage via le proxy LiteLLM. Il est utilisé pour :
- La reformulation de requêtes (dans `BM25Finder`)
- La synthèse de réponses (dans `BM25Finder`)

### Configuration

Utilise les variables d'environnement :
- `OPENAI_BASE_URL` : URL du proxy LiteLLM
- `OPENAI_API_KEY` : Clé API
- `OPENAI_CHAT_MODEL` : Modèle de chat (ex: `mistral/mistral-small-latest`)

### Structure de requête

```rust
pub struct LitellmRequest {
    model: String,
    messages: Vec<LitellmRequestMessages>,
}

impl LitellmRequest {
    pub fn with_system(model: &str, user_message: &str, system_prompt: &str) -> Self {
        Self {
            model: model.to_string(),
            messages: vec![
                LitellmRequestMessages {
                    role: "system".to_string(),
                    content: system_prompt.to_string(),
                },
                LitellmRequestMessages {
                    role: "user".to_string(),
                    content: user_message.to_string(),
                },
            ],
        }
    }
}
```

### Réponse

```rust
pub struct LitellmResponse {
    pub id: String,
    pub created: i64,
    pub model: String,
    pub choices: Vec<Choice>,
    pub usage: Usage,  // tokens, coût
}

pub struct Choice {
    pub message: Message,  // contient le contenu textuel
}
```

---

## Structures de données du chatbot (`chatbot/src/domain/structs.rs`)

### KnowledgeEntry vs DocumentEntry

Le chatbot utilise `KnowledgeEntry` (`structs.rs:68-99`) qui est une version épurée de `DocumentEntry` (du CLI) :

| Champ | KnowledgeEntry (chatbot) | DocumentEntry (CLI) | Différence |
|-------|--------------------------|---------------------|------------|
| `id` | `String` (default "") | `String` | Identique |
| `domain` | `String` (default "") | `String` | Identique |
| `intent` | `String` (default "") | `String` | Identique |
| `category` | `String` (default "") | `String` | Identique |
| `keywords` | `Vec<String>` (default []) | `Option<Vec<String>>` | Pas d'Option dans KnowledgeEntry |
| `summary` | `String` (default "") | `Option<String>` | Pas d'Option |
| `procedure` | `Option<Procedure>` | `Option<Procedure>` | Identique |
| `faq` | `Vec<FaqItem>` (default []) | `Option<Vec<FAQEntry>>` | Pas d'Option |
| `alerts` | `Vec<Alert>` (default []) | `Option<Vec<Alert>>` | Pas d'Option |
| `locations` | `Vec<Location>` (default []) | `Option<Vec<Location>>` | Pas d'Option |
| `images` | `Vec<Image>` (default []) | `Option<Vec<ImageRef>>` | Pas d'Option |
| `related_intents` | `Vec<String>` (default []) | `Option<Vec<String>>` | Pas d'Option |
| `breadcrumb_trail` | `Option<String>` | `Option<String>` | Identique |
| `context_prerequisites` | `Option<String>` | `Option<String>` | Identique |
| `ui_coordinates` | Absent | `Option<UICoordinates>` | Présent uniquement dans DocumentEntry |

**Note** : `KnowledgeEntry` est conçu pour être directement désérialisé depuis le JSON du CLI (les champs `Option` deviennent des valeurs par défaut vides grâce à `#[serde(default)]`).

### Trait Finder (`chatbot/src/domain/finder.rs`)

Définit l'interface que doit implémenter tout moteur de recherche :

```rust
pub trait Finder: Send + Sync + 'static {
    fn get_sections(&self) -> &Vec<Section>;
    fn trouver_reponse(
        &self,
        message: &str,
        dermiere_question: &RwLock<Option<String>>,
    ) -> Option<String>;
    fn get_context(&self) -> &RwLock<Option<KnowledgeEntry>>;
}
```

`BM25Finder` implémente ce trait (`bm25_finder.rs:560-626`), avec `get_sections()` qui retourne `unimplemented!()` car le nouveau système n'utilise plus les sections mais les entrées BM25.

---

## Chargement et initialisation (`BM25Finder::try_new`)

### Chargement des données (`bm25_finder.rs:245-291`)

```rust
pub fn try_new() -> Result<Self, Box<dyn std::error::Error>> {
    // 1. Charge data/cli_results/results.json
    let data_path = Self::get_data_path("cli_results/results.json");
    let data = fs::read_to_string(&data_path)?;
    
    // 2. Parse comme un Vec<KnowledgeBase> (car le CLI produit un array)
    let all_bases: Vec<KnowledgeBase> = serde_json::from_str(&data)?;
    
    // 3. Fusionne toutes les bases en une seule
    let knowledge_base = KnowledgeBase {
        meta: all_bases.first().map(|b| b.meta.clone()).unwrap_or_default(),
        entries: all_bases.iter().flat_map(|b| b.entries.clone()).collect(),
    };
    
    // 4. Crée l'Embedder BM25 avec paramètres
    let embedder: Embedder<u32> = EmbedderBuilder::with_avgdl(100.0)
        .language_mode(Language::French)
        .b(config.b)
        .k1(config.k1)
        .build();
    
    // 5. Indexe toutes les entrées
    let mut scorer = Scorer::<usize>::new();
    for (idx, indexed) in indexed_entries.iter().enumerate() {
        let embedding = Self::embed_with_weights(&embedder, &indexed.corpus_text, &config.idf_weights);
        scorer.upsert(&idx, embedding);
    }
    
    Ok(Self { knowledge_base, embedder, scorer, config, indexed_entries, context: RwLock::new(None) })
}
```

### Résolution du chemin de données (`bm25_finder.rs:393-402`)

```rust
fn get_data_path(filename: &str) -> std::path::PathBuf {
    if let Ok(data_dir) = std::env::var("DATA_DIR") {
        return std::path::PathBuf::from(data_dir).join(filename);
    }
    let cwd_path = std::path::PathBuf::from("data").join(filename);
    if cwd_path.exists() {
        return cwd_path;
    }
    std::path::PathBuf::from("../data").join(filename)  // Fallback workspace root
}
```

---

## Le proxy LiteLLM

### Rôle central

Le proxy LiteLLM est utilisé à la fois pour :
1. **L'OCR Mistral** : Endpoint `{base_url}/ocr`
2. **Le chat/LLM** : Endpoint `{base_url}/chat/completions`

### Avantages

- **Unification d'API** : Compatible OpenAI pour tous les modèles
- **Gestion centralisée** : Rate limiting, coûts, logs
- **Flexibilité** : Permet de changer de modèle (mistral-ocr-latest, mistral-small-latest, etc.) sans modifier le code

---

##  Pipeline complet de bout en bout

### Étape 1 : Acquisition documentaire

```bash
cd /home/gab/Documents/asp/Prototypes/cli
cargo run
# Sélectionne le mode (1, 2 ou 3)
# Traite les documents → appelle Mistral OCR → sauvegarde results.json
```

**Exemple de sortie** :
```
=== Document Analysis CLI ===

Select mode:
  1. Analyze local PDFs from documents/ folder
  2. Fetch PNGs from remote list and analyze
  3. Convert PDF to PNGs and analyze each page

Enter choice (1/2/3): 1

Do you want to proceed with the analysis ? (y/N) y

Documents directory: "~/Documents/asp/Prototypes/documents"

Found 3 document(s) to analyze:
  1. guide_esat.pdf
  2. procedure_dsn.pdf
  3. aide_poste.pdf

[1/3] Analyzing: guide_esat.pdf...
  ✓ Successfully analyzed
  Waiting 3 seconds before next request...

[2/3] Analyzing: procedure_dsn.pdf...
  ✓ Successfully analyzed

...

Saving 3 result(s) to "~/Documents/asp/Prototypes/data/cli_results/results.json"...
✓ Results saved successfully!

=== Summary ===
  Documents processed: 3
  Errors: 0
```

### Étape 2 : Structure des données produites

`data/cli_results/results.json` :
```json
[
  {
    "meta": {
      "version": "1.0",
      "created": "2026-04-27T14:30:00Z",
      "language": "fr",
      "source_document": "guide_esat.pdf"
    },
    "entries": [
      {
        "id": "asp_esat_guide",
        "domain": "social",
        "intent": "guide_utilisation",
        "category": "administration",
        "keywords": ["ASP", "ESAT", "déclaration mensuelle", "guide pratique"],
        "summary": "Guide pratique pour l'initialisation des déclarations mensuelles...",
        "breadcrumb_trail": "Accueil > ESAT > Déclarations mensuelles",
        "context_prerequisites": "Écran de sélection de l'établissement",
        "procedure": {
          "steps": ["Accéder à l'écran d'administration...", ...],
          "required_documents": ["SIRET de l'établissement"],
          "optional_documents": []
        },
        "faq": [
          {"q": "Qui peut créer une déclaration ?", "a": "Seul un administrateur ASP..."}
        ],
        "alerts": [
          {"type": "info", "message": "Les déclarations sont généralement créées automatiquement."}
        ],
        "ui_coordinates": {
          "top_left_elements": [
            {"element_type": "button", "label": "Retour", "action": "Navigate back"}
          ],
          "center_elements": [
            {"element_type": "input", "label": "SIRET", "position": "center-top"}
          ]
        }
      }
    ]
  }
]
```

### Étape 3 : Indexation par BM25Finder

Au démarrage du chatbot, `BM25Finder::try_new()` :
1. Lit `results.json`
2. Parse les entrées
3. Construit le corpus textuel pour chaque entrée (`build_corpus_text`)
4. Crée les embeddings BM25 avec pondération IDF
5. Indexe dans le `Scorer`

### Étape 4 : Interaction utilisateur

```
Utilisateur: "Comment faire une déclaration mensuelle ASP ?"
                    ↓
    ┌───────────────────────────────────────────────┐
    │ Reformulation LLM (BM25_REFORMULATION_PROMPT) │
    │ "creer declaration mensuelle ASP procedure"    │
    └───────────────────────────────────────────────┘
                    ↓
    ┌───────────────────────────────────────────────┐
    │ Recherche exacte par ID ?                     │
    │ → Non                                         │
    └───────────────────────────────────────────────┘
                    ↓
    ┌───────────────────────────────────────────────┐
    │ Scoring BM25                                  │
    │ Embedding(query) vs Embeddings(index)         │
    │ → Score = 0.15 pour "asp_esat_guide"          │
    └───────────────────────────────────────────────┘
                    ↓
    ┌───────────────────────────────────────────────┐
    │ Gestion contextuelle ?                        │
    │ → Non (première question)                      │
    └───────────────────────────────────────────────┘
                    ↓
    ┌───────────────────────────────────────────────┐
    │ Synthèse LLM (BM25_SYNTHESIS_PROMPT)          │
    │ Génère réponse Markdown structurée            │
    └───────────────────────────────────────────────┘
                    ↓
Utilisateur: "## Guide pratique pour l'initialisation...
             
             ### Procédure
             1. Accéder à l'écran d'administration...
             2. Sélectionner l'établissement...
             
             > Les déclarations sont généralement créées automatiquement.
             
             ### FAQ
             **Q: Qui peut créer une déclaration ?**
             R: Seul un administrateur ASP..."
```

---

## Comparaison détaillée : Avant / Maintenant

### Source de la base de connaissances

| Aspect | Avant (Document BM25) | Maintenant |
|--------|----------------------|------------|
| **Création** | Saisie manuelle JSON | OCR Mistral automatisé via CLI |
| **Format source** | JSON édité à la main | PDF/PNG natifs (guides ASP officiels) |
| **Effort** | Élevé (saisie manuelle) | Faible (déposez les PDF, lancez le CLI) |
| **Fraîcheur** | Statique | Dynamique (re-lancez le CLI sur nouveaux docs) |

### Moteur de recherche BM25

| Aspect | Avant | Maintenant |
|--------|-------|------------|
| **Poids des champs** | 6 champs pondérés | 15+ champs pondérés |
| **Poids IDF** | ~10 termes personnalisés | **70+ termes** personnalisés |
| **Seuil de pertinence** | 0.3 | **0.08** (plus permissif) |
| **Champ `id`** | Non utilisé dans le scoring | **5.0** (prioritaire) |
| **Nouveaux champs** | Non présents | `breadcrumb_trail`, `context_prerequisites`, `ui_coordinates`, etc. |

### Pipeline de recherche

| Aspect | Avant | Maintenant |
|--------|-------|------------|
| **Reformulation** | Aucune | **LLM reformulation** (avant BM25) |
| **Matching exact** | Recherche BM25 seulement | **Recherche par ID exacte** (prioritaire) |
| **Critères BM25** | Score seul > 0.3 | Score > 0.08 **OU** mots-correspondants |
| **Contexte** | Mots-clés contextuels simples | **Filtrage par `related_intents` + similarité cosinus** |
| **Synthèse** | Formatage manuel Rust | **LLM synthèse Markdown** (après BM25) |

### Gestion du contexte

| Aspect | Avant | Maintenant |
|--------|-------|------------|
| **Détection** | Liste de mots-contextuels | Liste enrichie + analyse sémantique |
| **Recherche** | Fallback sur entrées liées | **Similarité cosinus** parmi les candidats filtrés |
| **Seuil contextuel** | N/A | 0.05 (très permissif) |

### Architecture logicielle

| Aspect | Avant | Maintenant |
|--------|-------|------------|
| **Structure** | Monolithique (chatbot seul) | **Architecture distribuée** (CLI + Chatbot) |
| **Couches** | Non définies | **DDD** : domain/ → infrastructure/ → application/ |
| **Interfaces** | Implémentation directe | **Trait `Finder`** (abstraction) |
| **LLM** | Aucun | **2 usages** : Reformulation + Synthèse |
| **Proxy** | N/A | **LiteLLM** centralisé |

### Format des données

| Aspect | Avant | Maintenant |
|--------|-------|------------|
| **KnowledgeEntry** | 12 champs | 16 champs (ajout `breadcrumb_trail`, `context_prerequisites`, `ui_coordinates`) |
| **Documents** | Uniquement JSON | **PDF/PNG → OCR → JSON** |
| **UI** | Aucune info UI | **`ui_coordinates`** avec éléments positionnés |

---

## Apport du proxy LiteLLM détaillé

### Centralisation

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│   CLI OCR   │────────▶│ LiteLLM Proxy │────────▶│  Mistral OCR    │
│ (mistral.rs)│         │              │         │  API            │
└─────────────┘         │              │         └─────────────────┘
                        │              │
┌─────────────┐         │              │         ┌─────────────────┐
│ Chatbot LLM │────────▶│              │────────▶│  Mistral Chat   │
│(api_interr.)│         └──────────────┘         │  API            │
└─────────────┘                                   └─────────────────┘
```

### Avantages concrets

1. **Gestion unifiée des clés API** : Une seule variable `OPENAI_API_KEY`
2. **Rate limiting centralisé** : Le proxy peut gérer les quotas globalement
3. **Suivi des coûts** : La réponse `Usage` inclut le champ `cost`
4. **Switch facile de modèles** : Modifiez `OPENAI_OCR_MODEL` ou `OPENAI_CHAT_MODEL`
5. **Compatibilité OpenAI** : Le code utilise le format standard OpenAI

---

## Conclusions et apports du projet

### Automatisation complète

Le projet est passé d'un **prototype statique** à un **système dynamique d'acquisition documentaire** :
- Les documents administratifs (PDF/PNG) sont transformés automatiquement en données structurées
- La base de connaissances est mise à jour en relançant simplement le CLI sur de nouveaux documents

### Hybrisation intelligente

Le `bm25_finder` combine désormais :
1. **Recherche lexicale** (BM25 avec pondérations fines)
2. **Compréhension sémantique** (LLM reformulation + synthèse)
3. **Gestion contextuelle** (similarité cosinus + `related_intents`)

### Maintenabilité accrue

L'architecture en couches DDD sépare clairement :
- **Domain** : Logique métier (`bm25_finder`, `structs`, `finder`)
- **Infrastructure** : Implémentations techniques (`api_interrogator`, `embedding`)
- **Application** : Cas d'utilisation (`chatbot_service`)

### Extensibilité

Le proxy LiteLLM et l'interface `Finder` permettent d'ajouter facilement :
- D'autres modèles LLM (Claude, GPT, etc.)
- D'autres moteurs de recherche (vectoriel, RAG, etc.)
- D'autres sources de données (API, bases SQL, etc.)

### Capacités de l'OCR Mistral

L'OCR ne se contente plus d'extraire du texte, il :
- Structure les données selon un schéma JSON précis (`base.json`)
- Identifie les procédures, FAQ, alertes, éléments UI
- Capture le contexte de navigation (`breadcrumb_trail`)
- Détecte les prérequis contextuels (`context_prerequisites`)

---


