# Chatbot à base de recherche

## Technologies utilisées
Se référer à [Chatbot déterministe](/docs/3-prototypage/deterministe), le code part de la même base et est une extension de celui d'avant.
Pour la recherche sémantique, nous utilisons la crate
[`bm25`](https://docs.rs/bm25/latest/bm25/) qui implémente l'algorithme
Okapi BM25, un modèle de classement probabiliste utilisé par de nombreux
moteurs de recherche modernes.

## Comment marche-t-il ?

Le bot fonctionne selon une approche de recherche sémantique plutôt que par correspondance exacte. Lorsqu'un utilisateur pose une question, le système commence par transformer cette question en embedding : le message est d'abord tokenisé, puis normalisé (passage en minuscules, suppression des stopwords, application du stemming) avant d'être converti en un vecteur de poids via l'algorithme BM25.

Ensuite, le système compare cette question avec la base de connaissances. Chaque entrée de cette base a été préalablement indexée avec un embedding similaire. Le système calcule alors un score de similarité entre la question et chaque document indexé pour évaluer leur pertinence mutuelle.

Si le score calculé dépasse un seuil de pertinence fixé à 0.3 par défaut, le système retourne la réponse associée au document le plus pertinent. C'est ce mécanisme de scoring qui permet de trouver la meilleure correspondance possible.

Enfin, le système conserve en mémoire la dernière entrée consultée, ce qui lui permet de gérer intelligemment les questions de suivi. Quand un utilisateur demande "et pour ce cas-là ?" ou "comment faire dans mon établissement ?", le bot comprend que la question fait référence à la discussion en cours.

## Structure de la base de connaissances

La base de connaissances est structurée autour d'**entrées thématiques**
(`KnowledgeEntry`), chacune représentant un sujet complet avec ses procédures,
FAQ associées et métadonnées. Voici la structure détaillée d'un fichier JSON :

### Structure globale

```json
{
  "meta": {
    "version": "1.0",
    "created": "2023-10-05",
    "language": "fr"
  },
  "entries": [
    {
      "id": "asp_esat_guide",
      "domain": "social",
      "intent": "guide_utilisation",
      "category": "administration",
      "location_context": ["france"],
      "keywords": ["ASP", "ESAT", "déclaration mensuelle", ...],
      "summary": "Guide pratique pour...",
      "procedure": { ... },
      "locations": [ ... ],
      "faq": [ ... ],
      "images": [ ... ],
      "alerts": [ ... ],
      "related_intents": ["gestion_esat", "declarations_sociales", ...]
    }
  ]
}
```

### Détail des champs d'une entrée

#### Champs d'identification

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | Identifiant unique de l'entrée (ex: `asp_esat_guide`) |
| `domain` | string | Domaine thématique (ex: `social`, `santé`, `agriculture`) |
| `intent` | string | Intention utilisateur principale (ex: `guide_utilisation`, `demande_info`) |
| `category` | string | Catégorie administrative ou fonctionnelle |

#### Champs de contenu

| Champ | Type | Description |
|-------|------|-------------|
| `keywords` | array[string] | Mots-clés pour la recherche (fortement pondérés dans BM25) |
| `summary` | string | Résumé descriptif de l'entrée |
| `procedure` | object | Procédure détaillée avec étapes et documents requis |
| `faq` | array[object] | Questions-réponses fréquentes liées au sujet |

#### Champs de contexte

| Champ | Type | Description |
|-------|------|-------------|
| `location_context` | array[string] | Contextes géographiques applicables |
| `locations` | array[object] | Organismes et adresses associés |
| `related_intents` | array[string] | Intentions liées pour la navigation contextuelle |
| `alerts` | array[object] | Alertes et informations importantes |
| `images` | array[object] | Références aux images et captures d'écran |

### Exemple complet

```json
{
  "id": "asp_esat_guide",
  "domain": "social",
  "intent": "guide_utilisation",
  "category": "administration",
  "location_context": ["france"],
  "keywords": [
    "ASP",
    "ESAT",
    "déclaration mensuelle",
    "guide pratique",
    "administrateur"
  ],
  "summary": "Guide pratique pour l'initialisation des déclarations mensuelles dans l'application ESAT2 de l'Agence de Services et de Paiement (ASP).",
  "procedure": {
    "steps": [
      "Accéder à l'écran d'administration dans l'application ESAT2.",
      "Sélectionner l'établissement concerné.",
      "Choisir le mois et l'année de la déclaration mensuelle.",
      "Valider la création de la déclaration mensuelle."
    ],
    "required_documents": [
      "Accès à l'application ESAT2 avec profil administrateur.",
      "SIRET de l'établissement principal."
    ],
    "optional_documents": []
  },
  "locations": [
    {
      "type": "administration",
      "name": "Agence de Services et de Paiement (ASP)",
      "address": "France"
    }
  ],
  "faq": [
    {
      "q": "Qui peut créer une déclaration mensuelle manuellement ?",
      "a": "Seul un administrateur ASP peut créer une déclaration mensuelle manuellement via l'application ESAT2."
    },
    {
      "q": "Quels sont les délais pour la réception des données DSN ?",
      "a": "Les données DSN sont traitées dans un délai de 2 à 3 jours après leur réception."
    }
  ],
  "images": [
    {
      "ref": "asp_logo",
      "type": "logo",
      "description": "Logo de l'Agence de Services et de Paiement (ASP)."
    },
    {
      "ref": "esat2_screenshot",
      "type": "screenshot",
      "description": "Capture d'écran de l'application ESAT2 montrant le processus de création d'une déclaration mensuelle."
    }
  ],
  "alerts": [
    {
      "type": "info",
      "message": "Les déclarations mensuelles sont généralement créées automatiquement. Cette procédure est uniquement pour les cas où une création manuelle est nécessaire."
    }
  ],
  "related_intents": [
    "gestion_esat",
    "declarations_sociales",
    "administration_asp"
  ]
}
```

## Implémentations

### Architecture du système BM25

Le système repose sur plusieurs composants clés :

#### 1. Configuration BM25 (`Bm25Config`)

La configuration définit les paramètres de l'algorithme :

```rust
pub struct Bm25Config {
    pub field_weights: HashMap<String, f32>,    // Pondération par champ
    pub idf_weights: HashMap<String, f32>,      // Pondération IDF personnalisée
    pub b: f32,                                 // Paramètre de normalisation
    pub k1: f32,                                // Paramètre de saturation
}
```

Les poids par champ sont configurés comme suit :

| Champ | Poids | Justification |
|-------|-------|---------------|
| `keywords` | 3.0 | Les mots-clés sont les plus pertinents |
| `summary` | 2.0 | Le résumé contient l'essentiel |
| `procedure` | 1.5 | Les étapes sont importantes mais secondaires |
| `domain` | 1.5 | Le domaine aide à filtrer le contexte |
| `intent` | 1.5 | L'intention guide la recherche |
| `faq` | 1.0 | Les FAQ sont utiles mais moins prioritaires |

#### 2. Indexation des entrées

Chaque entrée est transformée en un **corpus textuel** unique qui agrège tous
les champs pertinents :

```rust
fn build_corpus_text(entry: &KnowledgeEntry) -> String {
    let mut parts = Vec::new();
    
    // Métadonnées
    parts.push(entry.domain.clone());
    parts.push(entry.intent.clone());
    parts.push(entry.category.clone());
    
    // Mots-clés (fortement pondérés)
    parts.extend(entry.keywords.clone());
    
    // Contenu principal
    parts.push(entry.summary.clone());
    
    // Procédure
    parts.extend(entry.procedure.steps.clone());
    parts.extend(entry.procedure.required_documents.clone());
    parts.extend(entry.procedure.optional_documents.clone());
    
    // FAQ
    for faq in &entry.faq {
        parts.push(faq.q.clone());
        parts.push(faq.a.clone());
    }
    
    // Contexte
    parts.extend(entry.location_context.clone());
    parts.extend(entry.related_intents.clone());
    
    parts.join(" ")
}
```

#### 3. Création de l'embedding

L'embedding est créé avec pondération IDF :

```rust
fn embed_with_weights(
    embedder: &Embedder<u32>,
    text: &str,
    idf_weights: &HashMap<String, f32>,
) -> Embedding {
    // Tokenisation avec normalisation française
    let tokenizer = DefaultTokenizer::builder()
        .language_mode(Language::French)
        .normalization(true)
        .stopwords(true)    // Supprime "le", "la", "de", etc.
        .stemming(true)     // Réduit "déclarations" → "declar"
        .build();

    let tokens = tokenizer.tokenize(text);

    // Comptage des tokens
    let mut token_counts: HashMap<String, u32> = HashMap::new();
    for token in &tokens {
        *token_counts.entry(token.clone()).or_insert(0) += 1;
    }

    // Application des poids IDF
    let mut embedding = Vec::new();
    for (token, count) in token_counts {
        let weight = idf_weights.get(&token).copied().unwrap_or(1.0);
        let value = (count as f32) * weight;
        
        embedding.push(bm25::TokenEmbedding {
            index: token_hash,
            value,
        });
    }

    Embedding(embedding)
}
```

Les termes avec IDF personnalisé incluent :

| Terme | Poids IDF | Raison |
|-------|-----------|--------|
| `esat`, `esat2` | 1.5 | Terme spécifique au domaine |
| `plateforme` | 1.3 | Terme technique important |
| `declaration` | 1.4 | Concept administratif clé |
| `mandataire` | 1.5 | Terme métier spécifique |
| `etablissement` | 1.4 | Entité organisationnelle |
| `travailleur` | 1.4 | Acteur principal |
| `asp`, `ars` | 1.3 | Organismes officiels |
| `finess`, `dsn` | 1.4 | Identifiants administratifs |

#### 4. Recherche et scoring

La recherche utilise le scoring BM25 pour trouver le meilleur match :

```rust
pub fn find_entry_with_context(&self, message: &str) -> Option<(f32, &KnowledgeEntry)> {
    // Création de l'embedding de la requête
    let query_embedding = Self::embed_with_weights(
        &self.embedder, 
        message, 
        &self.config.idf_weights
    );

    // Calcul des scores BM25
    let matches = self.scorer.matches(&query_embedding);

    if let Some(best) = matches.first() {
        let ScoredDocument { id: idx, score } = best;

        // Seuil de pertinence
        if *score < 0.3 {
            return None;
        }

        if let Some(indexed) = self.indexed_entries.get(*idx) {
            return Some((*score, &indexed.entry));
        }
    }
    None
}
```

#### 5. Gestion du contexte conversationnel

Le système détecte les questions contextuelles et recherche dans les entrées
liées :

```rust
fn is_contextual_question(&self, message: &str) -> bool {
    let msg = message.to_lowercase();
    let mots_contextuels = [
        "et pour", "et comment", "et si", "et dans",
        "dans ce cas", "dans cet établissement",
        "comment faire", "comment procéder", "comment gérer",
        "que faire", "quel est", "quels sont",
        "c'est quoi", "peut-on", "est-ce que",
        "y a-t-il", "puis-je", "je peux",
        "mon établissement", "mon esat", "mes travailleurs",
        "la procédure", "cette démarche", "ce guide",
    ];
    mots_contextuels.iter().any(|m| msg.contains(m))
}
```

Si une question contextuelle est détectée, le système filtre les candidats
parmi les entrées liées au contexte actuel :

```rust
fn search_with_context(&self, message: &str) -> Option<(f32, &KnowledgeEntry)> {
    let current_context = self.context.read().unwrap();

    if let Some(ctx) = current_context.as_ref()
        && self.is_contextual_question(message)
    {
        // Filtrer par domaine ou intentions liées
        let candidates: Vec<&KnowledgeEntry> = self
            .knowledge_base
            .entries
            .iter()
            .filter(|e| {
                e.id != ctx.id
                    && (e.domain == ctx.domain
                        || e.related_intents.contains(&ctx.intent)
                        || ctx.related_intents.contains(&e.intent))
            })
            .collect();

        // Recherche par similarité cosinus parmi les candidats
        // ...
    }

    // Fallback sur la recherche normale
    self.find_entry_with_context(message)
}
```

#### 6. Formatage de la réponse

La réponse est formatée de manière structurée :

```rust
fn format_response_with_context(&self, entry: &KnowledgeEntry, score: f32) -> String {
    let mut response = String::new();

    // Résumé principal
    response.push_str(&entry.summary);
    response.push_str("\n\n");

    // Étapes de procédure
    if !entry.procedure.steps.is_empty() {
        response.push_str("Voici comment procéder :\n");
        for (i, step) in entry.procedure.steps.iter().enumerate() {
            response.push_str(&format!("{}. {}\n", i + 1, step));
        }
        response.push('\n');
    }

    // Documents requis
    if !entry.procedure.required_documents.is_empty() {
        response.push_str("Assurez-vous d'avoir : ");
        // ... formatage de la liste
        response.push_str(".\n\n");
    }

    // Alertes
    for alert in &entry.alerts {
        match alert.alert_type.as_str() {
            "info" => response.push_str(&format!("! {}", alert.message)),
            "warning" => response.push_str(&format!("!! {}", alert.message)),
            "error" => response.push_str(&format!("!!! {}", alert.message)),
            _ => response.push_str(&format!("- {}", alert.message)),
        }
        response.push('\n');
    }

    response
}
```

### Avantages de l'approche BM25

L'un des atouts majeurs de BM25 réside dans sa capacité à effectuer une recherche sémantique. Contrairement à un simple matching exact de mots-clés, cet algorithme comprend la pertinence relative des termes et gère beaucoup mieux les variations linguistiques, ce qui rend la recherche plus flexible et pertinente.

La pondération intelligente des champs constitue un autre avantage notable. Les champs jugés plus importants comme les mots-clés ou le résumé ont davantage de poids dans la recherche, et les termes rares identifiés via l'IDF sont valorisés. Cette hiérarchisation permet de prioriser les informations les plus pertinentes pour l'utilisateur.

La normalisation linguistique renforce encore cette pertinence. Le stemming permet de réduire les mots à leur racine, si bien que "déclarations" correspondra à "déclaration". La suppression des stopwords élimine également les mots-outils qui n'apportent rien à la recherche.

Le système intègre aussi une gestion du contexte conversationnel. Il peut suivre une discussion en cours et comprendre les questions de suivi liées au sujet traité, offrant ainsi une expérience plus fluide et naturelle à l'utilisateur.

Enfin, le seuil de pertinence de 0.3 permet d'éviter de retourner des réponses peu fiables. Si le score d'un match est en dessous de ce seuil, le système préfère ne pas répondre plutôt que de risquer de donner une information inexacte.

### Limitations actuelles

L'approche BM25 reste malgré tout limitée par certains aspects fondamentaux. Premièrement, la base de connaissances constitue un facteur déterminant : l'algorithme ne peut trouver que ce qui existe déjà dans cette base. Si elle est incomplète ou mal structurée, les résultats seront inévitablement décevants. C'est un peu comme chercher dans une bibliothèque vide.

Deuxièmement, BM25 ne propose pas de compréhension sémantique profonde au sens où on l'entendrait avec des modèles de langage modernes. L'algorithme reste basé sur les mots eux-mêmes. Les synonymes qui ne sont pas explicitement présents dans les mots-clés ne seront pas matched, ce qui peut créer des angles morts dans la recherche.

La qualité des résultats dépend également fortement de la configuration des poids. Trouver le bon équilibre entre les différents champs et les pondérations IDF demande du temps et des tests. Une mauvaise configuration peut dégrader significativement la pertinence des réponses.

Enfin, le système ne peut pas reformuler automatiquement une question mal posée. Si l'utilisateur exprime mal sa requête ou omet des mots-clés importants, le bot ne pourra pas deviner son intention réelle. Il faudra alors que l'utilisateur reformule lui-même sa question.

## Conclusions

L'implémentation de BM25 représente une amélioration significative par rapport au simple keyword matching. Le système est capable de comprendre les variations linguistiques grâce au stemming et à la normalisation, ce qui lui permet de reconnaître "déclaration" et "déclarations" comme relevant de la même racine. Il peut également pondérer intelligemment les différents champs du document pour donner plus d'importance aux mots-clés qu'au contenu secondaire. La gestion du contexte conversationnel permet de suivre les échanges et de traiter les questions de suivi de manière cohérente. Enfin, les réponses retournées sont structurées avec les procédures détaillées et les alertes pertinentes.

Cependant, cette approche reste limitée par la nature même de BM25 : un
algorithme de recherche textuelle, pas un modèle de langage. Pour aller plus
loin, une intégration avec un modèle d'embedding neuronal (type transformers)
permettrait une véritable compréhension sémantique, au prix d'une complexité
accrue et de besoins en calcul plus importants.

L'architecture actuelle offre un bon compromis entre performance, simplicité et
maintenabilité, tout en fournissant une expérience utilisateur correcte pour
un chatbot d'assistance administrative.
