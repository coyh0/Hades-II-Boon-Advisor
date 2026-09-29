# God Pool — procédure de QA runtime DEV

À exécuter après review et déploiement DEV approuvé. Le God Pool ajoute deux lignes informatives sur les offres de dieux ; il ne doit modifier ni les rangs, ni le bandeau d'analyse, ni `Boon Core Build Missing`.

## Préparation

1. Relever le commit/source déployé, la version du jeu et le build sélectionné. Activer les logs DEBUG du mod si disponibles.
2. Démarrer une nouvelle run avec le build Mobalytics Médée. Pour ce profil, Zeus, Héra, Arès et Déméter sont recommandés ; Héphaïstos et Aphrodite sont hors de la sélection du build.
3. À chaque capture, noter le dieu de l'offre, les deux lignes God Pool, les rangs/états visibles, la présence éventuelle du message Core, et l'entrée `GodPoolContext` dans le log. Ne pas interpréter `Unknown` comme un échec sans comparer l'état natif disponible.

## Scénarios obligatoires

| Étape | Action | Attendu |
| --- | --- | --- |
| 1 | Ouvrir la première offre de dieu recommandé de la run. | `Build God Pool: Recommended`. `Run God Pool: Present` si la prise de l'offre a déjà inscrit ce dieu dans `LootTypeHistory` ; sinon `Unknown` et signaler le moment observé. Les lignes sont distinctes et ne chevauchent pas le titre, le build, le bandeau ou les cartes. |
| 2 | Ouvrir, si la run le permet, une offre d'un dieu hors sélection (par exemple Héphaïstos). | `Build God Pool: Outside`. Le statut de run dépend uniquement de l'historique natif : `Present` si enregistré, `Unknown` si non établi. Les rangs et le message Core restent cohérents avec leurs règles antérieures. |
| 3 | Reroll une offre de dieu. | Les deux lignes sont recalculées une seule fois, sans doublon ni texte périmé. Le dieu/source ne change pas par simple reroll ; son statut observé reste donc stable si l'historique natif est stable. |
| 4 | Passer dans une autre salle/région puis ouvrir une nouvelle offre. | Pas de statut conservé par l'UI précédente. Le nouvel affichage reflète le build actif et le `CurrentRun` courant. |
| 5 | Terminer la run, revenir au Hub et démarrer une nouvelle run. | Aucun état God Pool de la run précédente ne fuit dans la suivante. La première offre utilise le nouvel historique natif. |

## Scénarios opportunistes

- **Remplacement d'un boon :** si un dieu rencontré perd son dernier boon, vérifier lors d'une nouvelle offre de ce dieu que `Present` reste cohérent avec `LootTypeHistory` ; l'inventaire courant seul ne doit pas effacer l'historique.
- **Sauvegarde/reprise :** reprendre une run puis vérifier sur une nouvelle offre que le statut est reconstruit depuis l'historique rechargé.
- **Pool natif complet / offre forcée :** si quatre dieux sont enregistrés et qu'une offre d'un cinquième dieu survient, comparer le statut `Absent`/`Present` à `LootTypeHistory` au moment exact de l'affichage. Si la source ou la limite native est ambiguë, `Unknown` est attendu. Ne pas forcer ce cas par RNG.
- **Source spéciale ou données manquantes :** l'UI ne doit pas afficher une certitude fausse. `Unknown` est le résultat prudent.

## Critères de validation

Les deux dimensions doivent rester indépendantes : un dieu hors recommandation peut être `Present` dans la run ; un dieu recommandé peut être `Unknown` dans une run ouverte. Les offres Pom/Marteau, les écrans PNJ et les sources de dieu non vérifiées ne doivent pas recevoir de contexte God Pool. Vérifier visuellement les positions FR et EN si les deux langues sont disponibles. Joindre captures/logs pour tout décalage ou contradiction avec l'état natif. La review du résultat précède le checkpoint Git et le chantier de nettoyage.

## Clarification validée — God Pool et ranking indépendants

Pendant la QA, une offre Apollon a affiché `Build God Pool: Outside`, `Run God Pool: Present` et `No Reliable Preference`, sans Rank. `Outside` décrit uniquement l'appartenance au God Pool recommandé du build ; il ne cause ni ne supprime un Rank. Le Scoring Engine décide indépendamment : afficher les rangs si les choix évaluables permettent une préférence fiable, `No Reliable Preference` si les choix évalués ne peuvent pas être départagés, et `Incomplete Analysis` si les données ne suffisent pas à évaluer correctement les choix. `Core Boon · Build` reste réservé aux boons explicitement identifiés comme Core dans les données du build ; l'absence de Rank ou le statut `Outside` ne permet pas de l'inférer.
