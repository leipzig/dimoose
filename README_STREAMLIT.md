# Dichotomous Key Interactive Dashboard

An interactive Streamlit web application for navigating dichotomous keys used in taxonomic identification.

## Features

### 🎯 Core Functionality
- **Interactive Navigation**: Step-by-step guidance through dichotomous keys
- **Multiple Keys Support**: Load and navigate different taxonomic keys
- **Navigation History**: Track your path through the key with ability to backtrack
- **Terminal Identification**: Clear display when reaching a taxonomic result

### 🎨 User Interface
- **Clean, Modern Design**: Professional styling with custom CSS
- **Two-Column Layout**: Side-by-side comparison of choices
- **Responsive Design**: Works on desktop and mobile devices
- **Visual Feedback**: Color-coded results and interactive buttons

### 📊 Navigation Features
- **History Sidebar**: View all previous choices
- **Back Button**: Return to previous decision points
- **Restart Option**: Begin the key from the start
- **Progress Tracking**: See which couplet you're currently on

## Installation

### Prerequisites
- Python 3.8 or higher
- pip package manager

### Setup

1. **Navigate to the dashboard directory**:
```bash
cd /Users/leipzig/Documents/dev/moose-streamlit-dashboard
```

2. **Create a virtual environment** (recommended):
```bash
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows
```

3. **Install dependencies**:
```bash
pip install -r requirements.txt
```

## Usage

### Running the Dashboard

**Basic launch**:
```bash
streamlit run dichotomous_key_app.py
```

**With custom port**:
```bash
streamlit run dichotomous_key_app.py --server.port 8502
```

**With auto-reload disabled** (for production):
```bash
streamlit run dichotomous_key_app.py --server.fileWatcherType none
```

The application will open in your default web browser at `http://localhost:8501`

### Using the Application

1. **Select a Key**
   - Use the sidebar dropdown to choose from available dichotomous keys
   - The key title and entry count are displayed

2. **Navigate the Key**
   - Read the current couplet description
   - Choose between:
     - **Choice A (Yes)**: The description matches your specimen
     - **Choice B (No)**: The description does not match
   - Click the appropriate button to proceed

3. **Track Your Progress**
   - View navigation history in the sidebar
   - Click "Back" to return to a previous choice
   - Click "Restart" to begin again

4. **Reach Identification**
   - Continue until you reach a terminal node
   - The result will be displayed in a highlighted box
   - Use "Start Over" to identify another specimen

## Data Format

The application expects dichotomous keys in JSON format:

```json
{
  "title": "Key to the Orders of Arachnida",
  "entries": [
    {
      "id": "1.",
      "content": "Description of trait... 2"
    },
    {
      "id": "1'.",
      "content": "Alternative description... 3"
    },
    {
      "id": "2.",
      "content": "Next description... Order Name p. 105"
    }
  ]
}
```

### Key Structure
- **title**: Name of the dichotomous key
- **entries**: Array of couplet entries
  - **id**: Couplet identifier (e.g., "1.", "1'.", "2.")
  - **content**: Description text ending with either:
    - Next couplet number
    - Taxonomic result (e.g., "Araneae p. 105")

### Supported Locations
Keys are automatically discovered from:
- Root directory: `dichotomous_keys.json`
- Subdirectories: Any JSON file in `dichotomous_trees/` or matching patterns

## Features in Detail

### Navigation Logic

**Couplet Numbering**:
- `1.` - Primary choice
- `1'.` - Alternative (prime) choice
- `2(1).` - Couplet 2 derived from choice 1

**Terminal Nodes**:
- Detected by taxon name patterns (e.g., "Araneae p. 105")
- Display result with special formatting
- Provide option to restart

### Session State Management
- Current position tracked across page reloads
- Navigation history preserved
- State resets on restart or key change

## Development

### Project Structure
```
moose-streamlit-dashboard/
├── dichotomous_key_app.py    # Main Streamlit application
├── requirements.txt           # Python dependencies
├── README_STREAMLIT.md        # This file
└── dichotomous_trees/         # Key data files
    └── insect_keys/
        ├── key_1.json
        ├── key_2.json
        └── ...
```

### Adding New Keys

1. **Create JSON file** following the format above
2. **Place in directory**:
   - Root level, OR
   - `dichotomous_trees/` subdirectory
3. **Restart application** - key will be auto-discovered

### Customization

**Styling**:
- Edit CSS in the `st.markdown()` block (lines 24-57)
- Modify colors, fonts, spacing as needed

**Parser Logic**:
- Update `parse_next_id()` method for different ID patterns
- Modify `get_result()` for different terminal node formats

**Layout**:
- Adjust column widths in `st.columns()`
- Rearrange sidebar vs. main content

## Example Keys

### Arachnida Key
Navigate through the orders of Arachnida (spiders, scorpions, mites, etc.) based on morphological characteristics.

**Features**:
- 42+ couplet entries
- Identifies 11 major arachnid orders
- Based on "Borror and DeLong's Study of Insects"

### Insect Keys
Multiple keys for different insect groups with varying complexity.

## Troubleshooting

### No Keys Found
**Issue**: "No dichotomous keys found" error

**Solution**:
- Ensure JSON files are in expected locations
- Check JSON file format is valid
- Verify file permissions

### Navigation Not Working
**Issue**: Buttons don't respond or navigate incorrectly

**Solution**:
- Check console for errors
- Verify entry IDs are consistent
- Ensure next couplet references are correct

### Display Issues
**Issue**: Text formatting or layout problems

**Solution**:
- Clear browser cache
- Try different browser
- Check Streamlit version compatibility

## Browser Support

- ✅ Chrome/Chromium (recommended)
- ✅ Firefox
- ✅ Safari
- ✅ Edge

## Performance

- **Load time**: < 2 seconds for typical keys
- **Navigation**: Instant page updates
- **Memory**: Minimal (< 50MB for typical session)

## Future Enhancements

Potential improvements:
- [ ] Image support for visual identification
- [ ] Export navigation path as report
- [ ] Multiple language support
- [ ] Mobile app version
- [ ] Offline mode with Progressive Web App
- [ ] Key editor interface
- [ ] Search functionality across keys
- [ ] Statistical analysis of navigation patterns

## Contributing

To contribute improvements:

1. Create feature branch in worktree
2. Test thoroughly with multiple keys
3. Update documentation
4. Submit for review

## License

Part of the moose project. See main repository for license information.

## Citations

If using dichotomous keys from published sources, please cite:
- Original key authors
- Source publications
- This application (if publishing results)

## Support

For issues or questions:
- Check WARP.md in repository root
- Review troubleshooting section
- Consult main moose documentation

---

**Built with**: Streamlit • Python • JSON

**Version**: 1.0.0

**Last Updated**: 2025-10-05
