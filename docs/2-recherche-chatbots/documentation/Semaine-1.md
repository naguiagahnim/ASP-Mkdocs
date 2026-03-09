# Documentation semaine 1

Différents types de chatbots :

- Chatbot décisionnel
  - Se base sur des questions et réponses prédéfinies pour "répondre"
- Chatbot basé sur un LLM
  - Comme dans le nom, utilise un modèle d'ia conversationnelle pour répondre.
    Besoin d'un RAG pour cadrer
- Chatbot "hybride", basé sur les deux solutions susmentionnées

Après lecture des papiers, on en retire :

# Typologie des chatbots

## Chatbots à règles (rule‑based / décisionnels)

- Fonctionnement :
  - Basés sur des règles explicites : arbres de décision, scripts if/else,
    expressions régulières, patterns AIML, moteurs de règles.
  - Le concepteur définit un ensemble de conditions sur l'entrée (intent, mots
    clés) et la réponse associée.
- Avantages :
  - Comportement très contrôlable et prévisible.
  - Faciles à valider pour des cas d'usage simples (FAQ, formulaires).
- Limites :
  - Difficiles à maintenir quand le nombre de règles explose.
  - Faible capacité de généralisation, ne gèrent pas bien les formulations
    inattendues.

## Chatbots à base de recherche (retrieval‑based)

- Fonctionnement :
  - Le bot dispose d'une base de paires (contexte, réponse) ou de documents.
  - En gros recherche dans docs mais c pas préparé donc remplis pas besoin
    réponses toutes prêtes
  - À chaque requête, il cherche la réponse la plus pertinente parmi un set
    fixe.
  - Mécanismes typiques :
    - Similarité TF‑IDF / BM25 sur le texte.
    - Embeddings sémantiques + distance cosinus.
- Avantages :
  - Réponses maîtrisées (tout vient d'un corpus validé).
  - Moins de risques d'hallucinations.
- Limites :
  - Ne produit pas de réponses vraiment nouvelles.
  - Qualité dépend fortement de la couverture de la base de connaissances.

## Chatbots génératifs (neural / LLM‑based)

- Fonctionnement :
  - Utilisent un modèle de langage neuronal (RNN, seq2seq, maintenant surtout
    transformers).
  - Génération token par token à partir du contexte (conversation).
- Avantages :
  - Grande flexibilité, capacité à gérer des requêtes ouvertes, à reformuler, à
    généraliser.
- Limites :
  - Risque de réponses incorrectes ou « hallucinations ».
  - Contrôle plus délicat, besoin de garde‑fous (filtrage, RAG, règles métier).

## Chatbots hybrides

- Combinaison de plusieurs approches :
  - Retrieval + génération (RAG) : on récupère d'abord des documents pertinents,
    puis le LLM synthétise une réponse à partir de ces documents.
  - Règles + LLM : certaines intentions sont gérées par des règles, le reste est
    délégué au modèle de langage.
- Objectif :
  - Tirer parti de la flexibilité des modèles génératifs tout en gardant de la
    robustesse et de la conformité grâce au retrieval et aux règles.

## Cas d'usages

Certains groupes de métiers d'agents de l'ASP ainsi que leurs usagers sont
impliqués.

> Permet de spécialiser le chatbot au lieu d'être trop généraliste

**Agents**

- Faciliter certaines tâches
  - IAE
    - FAQ dynamique
      - Sur site web d'aide de l'IAE, ajout recherche qui recherche à la fois
        sur question et réponse pour filtrer
      - Proposé : TF-IDF en cherchant proximité mots entre la question et les
        questions
      - Si on mettait un LLM dessus, il pourrait en dériver des questions
        similaires, et éventuellement rajouter les nouvelles questions posées
      - Pour grand public
    - FAQ sur sujet précis
      - À partir liste questions-réponses, générer réponses plus circonstanciées
        (car sujet assez spécifique)
      - Scénariser dans chatbot fait de séparer question en fonction du nb de
        salariés
        - Réponses jugées pas complètement satisfaisantes, mais l'IA manquait de
          contexte car que document FAQ et manuel IAE, il aurait fallu lui
          donner les documents officiels, législatifs etc.
      - Pour collègues ASP qui répondaient aux entreprises
      - besoin bon cadre pour bons résultats
- Condenser certaines informations à partir des données fournies

**Usagers**

- Accompagner dans des démarches parfois intimidantes, sans le faire à leur
  place
- La plupart des gens ont essayé chatgpt, donc des outils comme
  [Open WebUI](Technos/Technologies.md#back) seraient pratiques pour capitaliser
  sur leur familiarité avec l'interface

Le cas d'usage prioritaire serait probablement les usagers.

## Questions ouvertes

Quelle modalité la plus appropriée pour présenter l'information pour usager
"grand public" ? Est-ce que chatbot mieux que FAQ dynamique / IA générative ?

### Pistes

Commencer à se créer un petit cas :

- De quel type de chatbot a-t-on besoin ?
  - Peut-on utiliser l'ia générative pour générer et maintenir une base de
    connaissances pour un chatbot fixe, pour enregistrer plein de variations de
    connaissances etc.
    - Si jamais changement important, IA peut mettre à jour
  - Intégrer comment ? bouton en bas ? dans tchap ?

À regarder : WIKIT, [Vidéo armée](https://www.youtube.com/watch?v=IpzYxcQ8gvc),
genii
