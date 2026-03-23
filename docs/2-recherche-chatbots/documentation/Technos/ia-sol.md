# Expérimentations avec différents types d'IA générative dans l'objectif de l'intégrer dans le chatbot

## Genii / Tolk.ai

RDV effectué le 11 mars 2026.

### Avantages
- Passe les tests de sécurité requis par le gouvernement au sein de plusieurs de
  ses institutions
- Préfère ne pas répondre plutôt que d'halluciner, **selon eux** leur taux
  d'hallucinations est d'environ 1 %
- Peut se baser sur des sites grâce à leur "sitemap", ou sur des documents de
  types variés (CSV, DOCX, ODT, PDF, etc.)
- Le reste des avantages est plutôt spécifique à l'ASP et ne seront pas
  mentionnés ici

### Désavantages
  - Difficilement modulable : on glisse un document ou renseigne un site et la magie opère

## Wikit
### Présentation
Ils ont l’air d’être familiers avec le public, donc éventuellement avec les normes
Résumé des besoins, cf [réunion besoins](/docs/2-recherche-chatbots/documentation/Besoins) : cible utilisateurs grand public et ça compte aussi les entreprises pas que des particuliers isolés et orienter vers bon type support si chatbot n’y arrive pas

Efficy déjà en place dans l’ASP, est ce que Wikit permet de s’intégrer dedans

Pour l’instant base de connaissances est uniquement FAQ cachée derrière login et du pptx / images donc pas facile d’extraire le texte et extract boîtes mail vers Efficy

Ajd le pb c la forme des documents donc, donc comment faire une bonne base de connaissances propre ? On peut brancher donc Efficy et Alfresco (?), Efficy partenaire Wikit donc ça fonctionne bien ensemble et ils ont deja eu projets communs

S’ils arrivent pas à se connecter c quand c’est fermé (pas d’API ni de service ni rien)

Depuis 2018 plus de 25 salariés, basés à Lyon

Solution principale : plateforme Wikit semantics qui repose sur souveraineté (hébergée chez OVH Cloud), simplicité (no code), multi-LLM et agnostique ; au choix d’un modèle on a plusieurs possibilites selon stratégie (performance, sécurité….) et sécurité (OVH aussi)

Instance Azure Wikit hébergée en France et en Europe

Semantics est un hub d’IA générative donc support métier (RH, IT…), relation client et expérience usager et aussi productivité individuelle donc ça peut être adapté pour les multiples cas d’usage

Utiliser un modèle permet d’empêcher les gens d’utiliser des IA hébergées par les entreprises (GPT etc)

Architecture fonctionnelle : c une grosse plateforme qui permet de créer des applications, soit RAG, Assistant Personnel et Workflow

Integrations Teams, app bureau, API…

par exemple petite bulle page web le cas classique 

Ont-ils des connecteurs qui permettent d’exploiter des lecteurs réseaux ? Genre serveurs de fichiers
> nan, mais possible de pousser des fichiers via l’API

### Démo

Connecteur share point possible

À chaque réponse on peut appuyer sur bouton contacter un agent 
> attention toutefois, peut-être vérifier que le bot indique à l’utilisateur de contacter l’agent sinon il cliquera jamais
JiraSM pour ticketing et IWS (partenaire Wikit aussi)

Depuis le chat on peut voir ses tickets ouverts avec les chatbots et ouverts auprès des agents

L’assistant RAG ne se base QUE sur le RAG, donc il sait pas, il répond pas
L’assistant personnel, lui, peut aller chercher sur Internet

Et enfin agent ITSM, workflow donc / servs MCP, il fait plein d’appels Api, requêtes SQL donc c’est plus lent maisss il a pu faire un graphique et tout

Et en bonus l’agent Annuaire, qui permet de requeter les éléments présents dans  l’annuaire de l’entreprise (qui est …)

Maintenant démo pdv externe, par exemple mairie Saint-Genis-Laval, depuis barre recherche on peut faire question en langage naturel et ça lance un chat

Dans leurs clients, qui utilise les solutions souveraines et qui a un domaine complexe ?
> RH car données sensibles, juridique qui se base aussi sur legifrance

Peut-on garantir que les réponses seront de qualité ? Comment mesurer ça?
> Garbage in, garbage out ca dépend beaucoup de la qualité des données et de leur maintenance, on a aussi des garde-fous pour éviter que le bot devienne raciste (ça serait embêtant) \n On a des statistiques sur les applications, la répartition de l’utilisation de celles-ci et onglet ÉVALUATION qui permet d’évaluer la qualité des réponses qui permet de vérifier si la réponse colle avec la donnée initiale

On peut aussi tout paramétrer et faire des prompts initiaux, les modèles sont hébergés par Wikit donc pas par l’ASP

Comment c’est facturé ?
>Solution SAAS donc un unique coût de licence propre à l’entièreté de l’organisation, 3 niveaux de licences pour deux catégories (starter et enterprise), généralement on se base sur le nb d’utilisateurs de la solution, plus la solution est chère plus y’a d’intégrations etc, y’a un forfait de requêtes annuelles, ici requêtes c’est appel API à LLM
