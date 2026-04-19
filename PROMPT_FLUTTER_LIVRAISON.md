# PROMPT — Application Flutter Livraison
### Sucre Store · Reproduction du design mobile

---

> **Usage :** Copier ce prompt dans ton agent IA (Cursor, Claude, Copilot, etc.)
> pour générer les écrans Flutter **LoginScreen** et **DashboardScreen (Livreur)**
> avec le design exact de l'application existante.

---

## CONTEXTE

Tu es un développeur Flutter senior. Reproduis exactement deux écrans
d'une application mobile de livraison en Flutter, en respectant à la lettre
le design system décrit ci-dessous.

Ne crée aucune logique métier réelle (API, auth, state management) —
utilise uniquement des données mockées et des `StatefulWidget` simples.

---

## DESIGN SYSTEM — SUCRE STORE

### Palette de couleurs

| Nom           | Valeur hex | Usage                              |
|---------------|------------|------------------------------------|
| primary       | `#f5ad41`  | Ambre/doré — couleur principale    |
| primaryDark   | `#d89a35`  | Variante sombre du primaire        |
| secondary     | `#242021`  | Quasi-noir — boutons foncés        |
| secondaryLight| `#3a3638`  | Variante claire du secondaire      |
| white         | `#ffffff`  | Fonds de cards                     |
| gray50        | `#f9fafb`  | Fond dashboard                     |
| gray100       | `#f3f4f6`  | Fond skeleton, séparateurs         |
| gray200       | `#e5e7eb`  | Bordures légères                   |
| gray300       | `#d1d5db`  | Bordures champs input              |
| gray400       | `#9ca3af`  | Placeholders, labels secondaires   |
| gray500       | `#6b7280`  | Textes secondaires                 |
| gray600       | `#4b5563`  | Bouton Appeler                     |
| gray700       | `#374151`  | Labels de champ                    |
| gray800       | `#1f2937`  | Titre SUCRE STORE                  |
| gray900       | `#111827`  | Textes principaux                  |
| error         | `#dc2626`  | Messages d'erreur                  |
| blue50        | `#eff6ff`  | Fond icône livraison               |
| blue100       | `#dbeafe`  | Bordure bouton Y aller             |
| blue600       | `#2563eb`  | Icône et texte navigation          |
| green600      | `#16a34a`  | Bouton confirmer livraison         |
| amber50       | `#fef9ec`  | Fond global écran login            |
| amberBg       | `#fef3c7`  | Fond badge boutique                |
| offlineBg     | `#f59e0b`  | Bannière hors-ligne                |
| offlineDark   | `#1c1917`  | Titre bannière offline             |
| offlineSubtext| `#44403c`  | Sous-titre bannière offline        |

---

### Typographie

- Police : système par défaut Flutter (pas de police custom)
- Titres principaux : `fontWeight w800`, `letterSpacing` variable
- Labels de champ : `w600`, taille `13`
- Corps : `w500` à `w700` selon le contexte

---

### Bordures & Radius

| Élément              | borderRadius |
|----------------------|--------------|
| Card login           | 20           |
| OrderCard            | 24           |
| Champs input         | 10           |
| Boutons principaux   | 12 à 16      |
| Icon buttons ronds   | 22 (cercle 44×44) |
| Badges / tabs        | 8 à 12       |

---

### Ombres

| Élément           | offset | opacity | blurRadius | elevation |
|-------------------|--------|---------|------------|-----------|
| Card login        | (0, 8) | 0.12    | 24         | 8         |
| OrderCard         | (0, 2) | 0.06    | 12         | 3         |
| Bouton submit     | (0, 4) | 0.35    | 8          | 5         |
| Bouton confirm ✓  | (0, 0) | 0.30    | 6          | 4         |

---

## ÉCRAN 1 — LoginScreen

**Fichier :** `lib/screens/login_screen.dart`

### Structure générale

- `Scaffold` sans `AppBar`
- `SafeArea` + `SingleChildScrollView`
- Fond plein `#fef9ec` (amber-50) sur tout l'écran
- Contenu centré verticalement, `padding` horizontal `24`

---

### Card centrale

- `maxWidth 400`, centrée horizontalement
- `backgroundColor white`, `borderRadius 20`
- `padding 32`, gap entre sections `20`
- Shadow : offset `(0,8)`, opacity `0.12`, blur `24`, elevation `8`
- `borderWidth 1`, `borderColor #f3f4f6`

**Contenu de la card (de haut en bas) :**

#### 1. Section logo

- Container `150×150` avec image logo (`resizeMode: contain`)
  - Si image absente : `CircleAvatar` ambre avec icône `store`
- Texte `"SUCRE STORE"` — fontSize `26`, w800, color gray800, letterSpacing `1`
- Texte `"Espace Livreur"` — fontSize `14`, color gray500, w500

#### 2. Bloc erreur *(conditionnel)*

- Visible uniquement si un message d'erreur est présent
- `Row` : icône `error_outline` rouge size `16` + texte erreur
- `backgroundColor #fef2f2`, `borderWidth 1`, `borderColor #fecaca`
- `borderRadius 10`, `padding 12`

#### 3. Champ "Nom d'utilisateur"

- Label au-dessus : fontSize `13`, w600, color gray700
- `Row` container : borderWidth `1.5`, borderColor gray300, borderRadius `10`, minHeight `50`, paddingH `12`
- Icône `person_outline` size `18`, color gray500, marginRight `8`
- `TextField` : fontSize `15`, color secondary, flex 1
- Placeholder : `"admin@example.com"`, couleur gray300
- `keyboardType: emailAddress`, pas de capitalisation

#### 4. Champ "Mot de passe"

- Même structure que ci-dessus
- Icône `lock_outline` à gauche
- Placeholder `"••••••••"`
- Bouton toggle show/hide (icône `visibility` / `visibility_off`, size `18`, color gray500) à droite
- `obscureText` contrôlé par state

#### 5. Bouton "Se connecter"

- `backgroundColor primary (#f5ad41)`, `borderRadius 12`
- `paddingVertical 15`, `minHeight 52`
- Texte : `"Se connecter"`, color secondary, fontSize `16`, w700
- Shadow ambre : opacity `0.35`, blur `8`, elevation `5`
- État chargement : `CircularProgressIndicator` petit, color secondary
- Disabled (`opacity 0.6`) pendant le chargement

#### 6. Footer textes

- `"Accès réservé aux livreurs"` — center, gray500, fontSize `12`
- **En dehors de la card** : `"Connexion sécurisée par JWT"` — marginTop `16`, gray500, fontSize `11`

---

### Comportement mock

- `onTap` "Se connecter" → `setState isLoading = true` → `Future.delayed(1.5s)` → navigate vers `DashboardScreen`
- Si champs vides → afficher `"Veuillez remplir tous les champs"` dans le bloc erreur

---

## ÉCRAN 2 — DashboardScreen (Espace Livreur)

**Fichier :** `lib/screens/dashboard_screen.dart`

### Structure générale

- `Scaffold` sans `AppBar`
- `SafeArea` edges top uniquement
- `backgroundColor gray50 (#f9fafb)`
- `Column` : `[NetworkBanner, Expanded(padding H16, T12, contenu)]`

---

### Widget NetworkBanner

**Fichier :** `lib/widgets/network_banner.dart`

- Visible uniquement si `isOnline == false`
- `backgroundColor #f59e0b`, paddingH `16`, paddingV `10`
- `Row` : emoji 📡 fontSize `20` + `Column` [`"Hors-ligne"` w700 13 color `#1c1917` / `"Vos actions seront synchronisées à la reconnexion"` fontSize `11` color `#44403c`]

---

### Header

`Row` spaceBetween, alignItems center, marginBottom `16`

**Gauche :**
- `"Bonjour 👋"` — fontSize `24`, w800, color gray900, letterSpacing `-0.5`
- Username mock ex. `"livreur_01"` — fontSize `13`, w500, color gray500, marginTop `2`

**Droite — deux icon buttons ronds (44×44, borderRadius 22) :**
- backgroundColor white, border gray200, shadow léger (opacity 0.06)
- Bouton refresh : icône `Icons.refresh` size `20`
  - En cours : border primary, icône color primary
  - Repos : icône color gray500
- Bouton logout : icône `Icons.logout` size `20`, color gray500 → retour LoginScreen

---

### Tab Switcher

- Container blanc, `borderRadius 16`, `padding 6`, marginBottom `16`
- Shadow opacity `0.05`, border gray200
- `Row` avec 2 onglets `flex:1` :

| État       | Style                                          |
|------------|------------------------------------------------|
| Non actif  | paddingV 10, borderRadius 12, texte gray500 w700 fontSize 13 |
| Actif      | backgroundColor secondary, shadow secondary 0.2, texte white w700 |

- Badge count (si orders > 0) : container blanc `18×18`, borderRadius `10`, fontSize `10` w800 color secondary
- Libellés : `"Disponibles"` et `"Mes Courses"`

---

### Liste des commandes

`ListView`, paddingBottom `32`

**État vide :**
- `Column` center, paddingV `64`, paddingH `32`, gap `12`
- Container `80×80`, borderRadius `40`, border `2` gray100 dashed, bg gray50 + icône `directions_car_outlined` size `48` color gray200
- Titre fontSize `18`, w700, gray900
- Sous-titre fontSize `13`, gray500, textAlign center, lineHeight `20`
- Si offline : badge `"📱 Mode hors-ligne actif"` bg `#fef3c7`, color `#92400e`, borderRadius `8`

**État loading :** 2 skeleton cards grises (height `160`, borderRadius `24`, bg gray200, opacity `0.5`)

---

### Widget OrderCard

**Fichier :** `lib/widgets/order_card.dart`

Container blanc, borderRadius `24`, shadow (offset 0,2 opacity 0.06 blur 12), elevation `3`, marginBottom `16`, border gray100, overflow hidden

#### Card Header

`Row` spaceBetween, paddingH `20`, paddingV `14`
bg `rgba(249,250,251,0.5)`, borderBottom `1` `#f9fafb`

**Gauche (Row gap 8) :**
- Badge numéro `#CMD-001` : bg white, border gray200, borderRadius `8`, paddingH `10`, paddingV `4` — fontSize `12` w700 gray900
- Badge heure `14:32` : bg gray100, borderRadius `8`, Row[icône `access_time` size `12` gray500 + texte]
- Badge `⏳ sync` *(si pending)* : bg `#fef3c7`, fontSize `10` w700 color `#92400e`

**Droite :** total `"15 000 F"` — fontSize `18`, w800, color primary

---

#### Card Body (padding 20, gap 16)

**Point de retrait — Boutique**

`Row` gap `12` :
- Icône container `40×40`, borderRadius `20`, bg `#fef3c7` + icône `storefront_outlined` size `20` color primary
- `Column` flex 1 :
  - Label `"BOUTIQUE"` — fontSize `10` w800 color primary letterSpacing `0.5`
  - Row : nom boutique cliquable `"SUCRE STORE"` w700 + badge téléphone inline `[icône call size 10 + numéro]` bg `#fff7ed` border `#ffedd5` borderRadius `6`
  - Adresse boutique — fontSize `13` w500 gray500

**Séparateur route**

`Column` width `40`, center, gap `4`, marginV `-8`
→ 3 points (4×4, borderRadius `2`, bg gray200)

**Adresse de livraison**

`Row` gap `12` :
- Icône container `40×40`, borderRadius `20`, bg blue50 + icône `location_on` size `20` color blue600
- `Column` flex 1 :
  - Adresse client — fontSize `16` w700 gray900, maxLines `2`
  - `"Client : Jean Dupont"` — fontSize `13` w500 gray500

---

#### Actions selon le mode

**Mode `"available"` → Bouton "Accepter la course"**

`Row` center gap `8`, bg secondary, borderRadius `16`, paddingV `14`, paddingH `20`, marginTop `4`
→ Texte `"Accepter la course"` color white fontSize `15` w700 + icône `chevron_right` size `20` white

**Mode `"my-orders"` → Actions livreur**

`Column` gap `12` :

Grille 2 colonnes (`Row` gap `12`) :
- **Appeler** (flex 1) : bg gray50, border gray100, borderRadius `12`, paddingV `12` — `Column` center [icône `call` size `20` gray600 + `"Appeler"` fontSize `12` w700 gray600]
- **Y aller** (flex 1) : bg blue50, border blue100, borderRadius `12`, paddingV `12` — `Column` center [icône `navigation` size `20` blue600 + `"Y aller"` fontSize `12` w700 blue600]

Zone validation (bg gray50, borderRadius `16`, padding `16`, border gray100, gap `10`) :
- Label `"VALIDATION LIVRAISON"` — fontSize `10` w700 gray400 letterSpacing `1`
- `Row` gap `10` :
  - `TextField` flex 1 : bg white, border gray200, borderRadius `12`, paddingH `16`, textAlign center, fontSize `18` w700, color secondary, letterSpacing `2`, keyboardType number, placeholder `"Code (ex: 123456)"` gray400
  - Bouton confirm `50×50` : bg green600, borderRadius `12`, icône `check_circle` size `24` white, shadow green600 opacity `0.3`

---

## DONNÉES MOCKÉES

```dart
final List<Map<String, dynamic>> mockOrders = [
  {
    'id': 1,
    'orderNumber': 'CMD-2024-001',
    'createdAt': '2024-01-15T14:32:00',
    'total': 15000,
    'customerName': 'Jean Dupont',
    'customerAddress': 'Quartier Hamdallaye, Rue KA-123, Conakry',
    'customerPhone': '+224 620 000 000',
    'syncStatus': 'synced',
  },
  {
    'id': 2,
    'orderNumber': 'CMD-2024-002',
    'createdAt': '2024-01-15T15:10:00',
    'total': 8500,
    'customerName': 'Fatoumata Diallo',
    'customerAddress': 'Coleah Camayenne, Immeuble Bah, Conakry',
    'customerPhone': '+224 628 111 222',
    'syncStatus': 'pending',
  },
];

final Map<String, String> shopInfo = {
  'name': 'SUCRE STORE',
  'address': 'Kaloum, Centre Ville, Conakry',
  'phone': '+224 625 000 000',
  'location': 'Kaloum Conakry',
};
```

---

## MAPPING DES ICÔNES (Ionicons → Material Icons)

| Ionicons original      | Material Icons Flutter         |
|------------------------|-------------------------------|
| person-outline         | `Icons.person_outline`        |
| lock-closed-outline    | `Icons.lock_outline`          |
| eye-outline            | `Icons.visibility_outlined`   |
| eye-off-outline        | `Icons.visibility_off_outlined`|
| alert-circle           | `Icons.error_outline`         |
| refresh                | `Icons.refresh`               |
| log-out-outline        | `Icons.logout`                |
| time-outline           | `Icons.access_time_outlined`  |
| car-sport-outline      | `Icons.directions_car_outlined`|
| storefront             | `Icons.storefront_outlined`   |
| location               | `Icons.location_on`           |
| call                   | `Icons.call`                  |
| navigate               | `Icons.navigation`            |
| checkmark-circle       | `Icons.check_circle`          |
| chevron-forward        | `Icons.chevron_right`         |

---

## NAVIGATION

- `Navigator.push` / `pop` classique (pas de package tiers)
- `LoginScreen` → `DashboardScreen` après délai mock de `1.5s`
- Bouton logout → retour `LoginScreen`
- Tab state géré localement avec `setState`
- Les 2 onglets affichent les mêmes `mockOrders` :
  - Onglet "Disponibles" → mode `available`
  - Onglet "Mes Courses" → mode `my-orders`

---

## PACKAGES REQUIS

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Aucun package tiers — uniquement flutter/material.dart
```

---

## STRUCTURE DES FICHIERS

```
lib/
├── main.dart
├── screens/
│   ├── login_screen.dart
│   └── dashboard_screen.dart
└── widgets/
    ├── network_banner.dart
    └── order_card.dart
```

---

## CONTRAINTES IMPÉRATIVES

1. Respecter **exactement** toutes les valeurs de couleurs hex
2. Respecter **exactement** les valeurs de borderRadius, padding, fontSize
3. Chaque `BoxDecoration` doit reproduire fidèlement les ombres décrites
4. Les éléments conditionnels (erreur, badge pending, offline banner) doivent être toggleables via un bouton ou switch dans l'UI pour la démo
5. Le code doit **compiler sans erreur** avec Flutter 3.x stable
6. Code propre, pas de commentaires TODO

---

*Sucre Store · Prompt généré le 09/04/2026*
