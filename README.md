# CityMaker for Godot - FREE Edition

A procedural city generation tool for Godot Engine that creates realistic urban environments with roads, buildings, and decorative elements.

> **💡 This is the FREE version** - Looking for advanced features? [See below](#-get-the-full-version) for the complete toolkit!

---

## 🎯 What's Included (FREE Version)

The free version includes the core city generation script:

### ✅ CityMaker.gd - Procedural City Generator
- **Grid-based city generation** - Create cities with customizable grid sizes
- **Intelligent road system** - Automatic road placement with lane configuration
- **Dynamic building placement** - Buildings of various sizes placed intelligently in city blocks
- **Decorative elements** - Scatter props like benches, trees, or street furniture
- **Boundary generation** - Automatic perimeter roads around the city
- **Configurable density** - Control building and decor density
- **Model organization** - Clean node hierarchy with grouped elements
- **Automatic height calculation** - Buildings and decor placed at correct heights
- **Random seed support** - Reproducible or random generation

[Download](https://github.com/sanjaymeherdev/Grid-City-Maker/releases)

---

## 🚀 Get the FULL Version

Unlock the complete CityMaker toolkit with powerful productivity tools that save hours of manual work!

### 💎 Premium Features Included

#### 🔧 **GridMaker.gd** - Instant Grid Generation
- Create custom grid layouts in seconds
- Automatic boundary road placement
- Corner piece support
- Configurable tile sizes and grid dimensions
- Perfect for starting your city projects quickly
- Compatible with export/import workflow

#### 📦 **Auto-Populate.gd** - Automated Asset Management
- **Automatically fills asset arrays** - No more manual dragging!
- Scans directories and populates all model arrays
- Works with base tiles, buildings, and decor
- Updates scenes automatically
- Saves hours of repetitive work
- One-click asset management

#### 📤 **Export.gd** - Scene to JSON Exporter
- Export entire Godot scenes to JSON format
- Preserves positions, rotations, and scales
- Groups instances by model type
- Compatible with Blender import workflow
- Perfect for scene version control
- Makes scene data portable and editable

#### 📥 **Import.gd** - JSON to Scene Importer
- Import JSON data back into Godot scenes
- Recreates entire scenes from JSON files
- Handles thousands of instances efficiently
- Perfect for collaborative workflows
- Works seamlessly with Blender exports
- Batch processing support

#### 🎨 **Material.gd** - Material Extraction Tool
- Extract materials from meshes
- Save as reusable .tres files
- Break embedded material dependencies
- Organize material libraries
- Quick material duplication
- Essential for asset management

#### 🎨 **Blender Export Scripts** (Python)

**ExportAll.py** - Batch GLB Exporter
- Export all mesh objects as individual GLB files
- Automatic file naming
- Batch processing for entire scenes
- Perfect for preparing assets for Godot

**MeshExport.py** - Smart Material-Based Exporter
- Export unique materials only (avoids duplicates)
- Intelligent material identification
- Optimized for large scenes
- Reduces file redundancy

**JSONExport.py** - Blender to Godot JSON
- Export Blender scenes directly to Godot-compatible JSON
- Preserves transforms (position, rotation, scale)
- Groups instances by model
- Seamless Blender → Godot workflow
- Supports complex scenes with thousands of objects

---

## 💰 Pricing

**Full CityMaker Toolkit**: **₹999** (One-time payment)

### What You Get:
✅ All 5 Godot editor scripts (GridMaker, Auto-Populate, Export, Import, Material)  
✅ All 3 Blender Python scripts (ExportAll, MeshExport, JSONExport)  
✅ CityMaker.gd (FREE script included)  
✅ Complete documentation for all tools  
✅ Email support for setup questions  
✅ Lifetime updates  
✅ Commercial license included  

---

## 📞 Contact & Purchase

### Ready to supercharge your workflow?

**Contact me to purchase the full version:**

📱 **WhatsApp**: [+91 7504704502](https://wa.me/917504704502)  
📸 **Instagram**: [@freelance.sanjay](https://instagram.com/freelance.sanjay)

**Payment Methods Accepted:**
- UPI
- Bank Transfer (India)
- PayPal (International)

> **Note**: After payment, you'll receive the complete toolkit within 24 hours via email or Google Drive link.

---

## 🎓 Why Choose the Full Version?

### Time Savings
- **GridMaker**: Create base grids in 30 seconds vs 30 minutes manually
- **Auto-Populate**: Fill 100+ asset slots in 5 seconds vs hours of dragging
- **Export/Import**: Move scenes between projects in minutes

### Workflow Benefits
- **Blender Integration**: Seamless workflow between Blender and Godot
- **Version Control**: JSON exports make scenes trackable in Git
- **Collaboration**: Share scenes as JSON with team members
- **Asset Management**: Organize materials and models professionally

### Professional Quality
- Battle-tested scripts used in production
- Clean, commented code
- Regular updates and improvements
- Proven to save hours per project

---

## 📚 CityMaker Documentation

### Requirements

- Godot Engine 4.x
- 3D models in `.glb` format:
  - Base tile (ground)
  - Road straight piece
  - Road corner piece
  - Building models
  - Decor models

### Installation

1. Copy `citymaker.gd` into your Godot project
2. Organize your 3D models into folders:
   ```
   res://bases/          # Ground and road tiles
   res://buildings/      # Building models
   res://decors/         # Decoration models
   ```

### Basic Usage

1. **Configure Model Paths** - Edit the configuration section at the top of `citymaker.gd`:

```gdscript
# Model Folders
var base_folder_path: String = "res://bases/"
var building_models_folder: String = "res://buildings/"
var decor_models_folder: String = "res://decors/"

# Base Model Names (without .glb extension)
var ground_tile_name: String = "base"
var road_straight_name: String = "road_straight"
var road_corner_name: String = "road_corner"
```

2. **Configure Grid Size** - Set your desired city dimensions:

```gdscript
var grid_size_tiles: Vector2i = Vector2i(30, 30)  # 30x30 tile grid
var tile_size: Vector3 = Vector3(2.0, 0, 2.0)     # Each tile is 2x2 units
```

3. **Configure Roads** - Define the road layout:

```gdscript
var lanes_x: int = 3              # Vertical roads (North-South)
var lanes_y: int = 2              # Horizontal roads (East-West)
var lane_width: int = 1           # Width of each road in tiles
```

4. **Run the Script**:
   - In Godot Editor, go to **File → Run**
   - Select `citymaker.gd`
   - The generated scene will open automatically

### Advanced Configuration

#### Building Settings

```gdscript
var building_min_size_tiles: Vector2i = Vector2i(1, 1)  # Minimum size
var building_max_size_tiles: Vector2i = Vector2i(5, 5)  # Maximum size
var building_spacing_tiles: int = 1                      # Space between buildings
var building_density_multiplier: float = 1.5            # Density control
```

#### Decor Settings

```gdscript
var decor_density: float = 0.50  # 50% chance per available tile
var decor_spacing_tiles: int = 1  # Minimum spacing from buildings/roads
```

#### Generation Options

```gdscript
var use_corner_pieces: bool = true      # Use corner road pieces
var random_seed: int = 42               # Set to 0 for random each time
var generate_buildings: bool = true     # Enable/disable buildings
var generate_decor: bool = true         # Enable/disable decor
```

### How It Works

1. **Base Grid Generation** - Creates a grid of ground tiles
2. **Road Placement** - Adds roads based on lane configuration
3. **Boundary Creation** - Surrounds the city with perimeter roads
4. **Section Analysis** - Divides the city into buildable blocks
5. **Building Placement** - Intelligently places buildings in available spaces
6. **Decor Placement** - Scatters decorative elements on remaining ground tiles
7. **Scene Creation** - Packages everything into a Godot scene

### Model Requirements

#### Ground Tile
- A flat tile representing the ground surface
- Recommended size: 2x2 units

#### Road Pieces
- **Straight**: A straight road segment
- **Corner**: A 90-degree corner piece (optional)
- Should align with ground tile dimensions

#### Buildings
- Various building models in `.glb` format
- Can be different sizes
- Script will automatically scale and place them

#### Decor
- Small props (benches, trees, lampposts, etc.)
- Placed on ground tiles around buildings

---

## 🤝 Support & Updates

### Email Support
After purchasing, you get email support for:
- Setup assistance
- Script configuration help
- Troubleshooting
- Best practices guidance

### Free Updates
All purchasers receive:
- Bug fixes
- New features
- Compatibility updates
- Performance improvements

---

## ⚖️ License

### FREE Version (CityMaker.gd)
- Free for personal and commercial use
- No attribution required
- Provided as-is

### FULL Version (All Premium Scripts)
- Commercial license included with purchase
- Use in unlimited projects
- No royalties or recurring fees
- Cannot resell or redistribute the scripts themselves

---

## 🌟 Testimonials

> "The Auto-Populate script alone saved me days of work. Best ₹999 I've spent!" - *Game Developer*

> "GridMaker + CityMaker combo is incredible. Created my entire city layout in an afternoon." - *3D Artist*

> "The Blender integration is seamless. Export from Blender, import to Godot, done!" - *Indie Studio*

---

## ❓ FAQ

**Q: Do I need both Blender and Godot?**  
A: The Godot scripts work standalone. Blender scripts are optional extras for enhanced workflow.

**Q: Can I use this for commercial games?**  
A: Yes! Commercial license is included with the full version.

**Q: What if I have issues?**  
A: Email support is included. I'll help you get set up.

**Q: Are there refunds?**  
A: Due to the digital nature, no refunds. But I'm confident you'll love it!

**Q: Will this work with Godot 5?**  
A: Currently for Godot 4.x. Free updates will include Godot 5 compatibility.

**Q: How do I get updates?**  
A: I'll email you when updates are available.

---

## 🎁 Special Offer

**First 10 customers get**: Extended 1-month support + Custom script modification (one small feature request)

---

## 📞 Get Started Today!

Don't let manual work slow you down. Get the full CityMaker toolkit and boost your productivity!

**Contact me now:**

📱 **WhatsApp**: [+91 7504704502](https://wa.me/917504704502)  
📸 **Instagram**: [@freelance.sanjay](https://instagram.com/freelance.sanjay)

---

**Made with ❤️ for the Godot community**

*Transform your city-building workflow today!*
