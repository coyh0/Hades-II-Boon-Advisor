# Compatibilité avec les patches Hades II

`Test-PatchCompatibility.ps1` a deux modes.

## Runtime

Install et Update utilisent automatiquement `-Mode Runtime`. Ce mode vérifie
l'exécutable Hades II, les scripts critiques et les ancres structurelles
requises par le mod. Il ne requiert ni Python, ni runtime Lua de test, ni
données canoniques, ni tests du dépôt développeur.

Les résultats sont :

- `PASS` : l'installation ou la mise à jour peut continuer.
- `MANUAL RUNTIME TEST REQUIRED` : l'opération est refusée par prudence ; ce
  résultat ne prouve pas que le mod est incompatible.
- `FAIL` : une vérification structurelle connue a échoué ; l'opération est
  refusée.

La V1 ne fournit aucun contournement `Force`.

## Full

`Full` est le mode développeur/release et le mode par défaut quand le script
est exécuté directement sans `-Mode`. Il ajoute à la vérification Runtime la
validation du projet, les validations canoniques, la génération déterministe
et les tests Lua 5.2/équivalence actuellement implémentés.

Exemple développeur :

```powershell
.\tools\Test-PatchCompatibility.ps1 `
    -Mode Full `
    -GameRoot "D:\Games\Hades2" `
    -PythonPath "C:\Path\To\python.exe" `
    -LuaDllPath "D:\Games\Hades2\Ship\lua52.dll"
```

Les utilisateurs finaux n'ont pas besoin d'exécuter le mode Full.
