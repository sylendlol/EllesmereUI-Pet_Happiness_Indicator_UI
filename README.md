# EllesmereUI-Pet_Happiness_Indicator_UI

<img width="1579" height="1161" alt="{F29D0DF3-EC64-4ACD-82AA-B266B9E865DD}" src="https://github.com/user-attachments/assets/2ea38c23-75c8-4712-9b38-21bfeee8a916" />


Modern, configurable styles for the hunter pet happiness indicator on the EllesmereUI pet frame in **WoW Forever**.

EllesmereUI shows pet happiness with the original Blizzard face icon. This add-on keeps that icon as an option and adds four flat styles that fit the EllesmereUI look. It also adds a few visibility options.

> Standalone add-on. It does **not** modify any EllesmereUI file, so EllesmereUI updates won't overwrite it.

---

## Features

### Five indicator styles

| Style | Description |
|---|---|
| **Icon (Blizzard)** | The original happiness face (default, same as stock EllesmereUI) |
| **Dot** | A small flat colored circle |
| **Bar** | A thin colored strip along the frame edge (horizontal on top/bottom, vertical on left/right) |
| **Pips** | Three segments: 3 filled = Happy, 2 = Content, 1 = Unhappy |
| **Text** | `Happy 125%` / `Content 100%` / `Unhappy 75%` in the state color, with the damage percentage optional |

### Options

- **Size**: one slider that follows the selected style. It sets the icon or dot size, the bar thickness, the pip height or the font size. Each style remembers its own size.
- **Position**: Left, Right, Top, or **Bottom** (new), plus X / Y offsets.
- **Only When Not Happy**: hides the indicator while your pet is Happy and shows it only when the pet drops to Content or Unhappy.
- **Pulse When Unhappy**: the indicator slowly pulses while your pet is Unhappy, so you notice before it runs away. Works with every style, including the icon.
- **Colors**: separate Happy, Content and Unhappy colors (all styles except Icon).
- **Style settings** (cog next to Style): Bar Length % and Text: Show Damage %.
- **Tooltip**: hovering the indicator shows the stock EllesmereUI tooltip, which lists happiness, damage %, loyalty trend and diet.
- **Live preview**: the options preview shows the selected style. When *Only When Not Happy* is on, the preview shows the Unhappy state so you can still see it.

All settings are saved in your EllesmereUI profile with the other pet frame settings.

---

## Requirements

- WoW Forever (Interface `16001`)
- EllesmereUI **v9.5.4 or newer** (tested on 9.5.4), including the **Unit Frames** module
- A **Hunter** with a pet. Only hunter pets have happiness, so other classes see nothing.

---

## Installation

1. Download or clone this repository.
2. Copy the `EllesmereUI_PetHappiness` folder into:
   ```
   World of Warcraft\_classic_beta_\Interface\AddOns\
   ```
   The result should be `...\AddOns\EllesmereUI_PetHappiness\EllesmereUI_PetHappiness.toc`.
3. Restart the game or type `/reload`.
4. Make sure **EllesmereUI Pet Happiness** is enabled in the AddOns list on the character select screen.

---

## Usage

Open EllesmereUI → **Unit Frames** → **Pet** → **PET HAPPINESS**:

| Left | Right |
|---|---|
| Show Happiness | Size |
| Position | **Style** (⚙ Bar Length %, Show Damage %) |
| **Only When Not Happy** | **Pulse When Unhappy** |
| **Happy Color** | **Content Color** |
| **Unhappy Color** | |

Bold rows come from this add-on. *Show Happiness*, *Size* and *Position* are EllesmereUI's own rows: this add-on makes *Size* follow the selected style and adds the *Bottom* position.

---

## How it works (for developers)

- Wraps `ns.UF_ApplyPetHappiness` and `ns.UF_RefreshPetHappiness` from EllesmereUI Unit Frames (`EUI_UnitFrames_ForeverExtras.lua`).
- Keeps EllesmereUI's own indicator frame (`pf._petHappy`) as the holder. The hunter-only rule, frame alpha, mouseover fade and tooltip therefore still come from EllesmereUI. The new styles are drawn on a child layer inside that frame.
- The options rows are added by wrapping `ns.UFO_BuildPetOptions` and, during that one call, `W.DualRow`. The new rows are built inside the PET HAPPINESS section, under the Position row.
- The options preview is restyled by wrapping `ns.UFO_BuildUnitPreview` and the preview's `Update`.

Settings keys (in `db.profile.pet`):

| Key | Default |
|---|---|
| `phStyle` | `"icon"` (`icon` / `dot` / `bar` / `pips` / `text`) |
| `phOnlyUnhappy` | `false` |
| `phPulse` | `false` |
| `phSize_dot` / `phSize_bar` / `phSize_pips` / `phSize_text` | `10` / `4` / `14` / `12` (the icon uses EllesmereUI's `happinessSize`) |
| `phBarLength` | `100` |
| `phShowDmg` | `true` |
| `phColorHappy` / `phColorContent` / `phColorUnhappy` | green / yellow / red |
| `happinessAlign` | adds `"bottom"` to EllesmereUI's `left` / `right` / `top` |

---

## Known limitations

- If a future EllesmereUI update renames the *Show Happiness* or *Position* rows, the extra options won't appear. The indicator falls back to the stock icon behavior until the add-on is updated.

---

## Credits

- EllesmereUI by Ellesmere. This is an unofficial add-on built on top of it.
- Pet happiness API: `C_PetInfo.GetPetHappiness()` (WoW Forever).
