# Chatbot déterministe

## Technologies utilisées

Nous utiliserons ici le langage Rust pour le backend, en utilisant
principalement le module [axum](https://docs.rs/axum/latest/axum/) qui fera ici
office de serveur HTTP pour afficher les pages HTML ainsi que les interactions
nécessitant une certaine logique, comme poser une question au bot. Le frontend
est développé en [HTMX](https://htmx.org/), qui permet notamment d'aisément
envoyer des requêtes HTTP directement depuis du HTML et utilise
[Tailwind CSS](https://tailwindcss.com/) afin de pouvoir rapidement prototyper
une interface convenable.

## Comment marche-t-il ?

Le bot fonctionne d'une manière relativement simple. Lorsque l'utilisateur pose
une question, celui-ci cherche d'abord dans les questions prédéfinies voir si
celle-ci en fait partie dans le but de récupérer la réponse prédéfinie associée
; c'est essentiellement le cas des questions associées aux boutons qui sont
directement récupérées depuis la base de connaissances les contenant. Si le
programme ne trouve pas de question prédéfinie, alors celui-ci cherche si un mot
contenu dans la question est présent dans une liste de déclencheurs pouvant
déclencher telle ou telle réponse. L'ordre de priorité est donc défini par
l'ordre dans lequel les questions sont insérées dans le fichier JSON les
contenant.
