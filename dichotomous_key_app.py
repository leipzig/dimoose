#!/usr/bin/env python3
"""
Dichotomous Key Interactive Dashboard
--------------------------------------
A Streamlit application for navigating dichotomous keys interactively.
Supports the Arachnida key and other taxonomic keys.
"""

import streamlit as st
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Page configuration
st.set_page_config(
    page_title="Dichotomous Key Navigator",
    page_icon="🔬",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
<style>
    .big-font {
        font-size:20px !important;
        font-weight: bold;
    }
    .choice-button {
        padding: 20px;
        margin: 10px 0;
        border-radius: 10px;
        border: 2px solid #ddd;
        background-color: #f9f9f9;
        cursor: pointer;
    }
    .choice-button:hover {
        background-color: #e6f3ff;
        border-color: #4CAF50;
    }
    .result-box {
        padding: 20px;
        margin: 20px 0;
        border-radius: 10px;
        background-color: #e8f5e9;
        border: 3px solid #4CAF50;
    }
    .history-item {
        padding: 10px;
        margin: 5px 0;
        background-color: #f0f0f0;
        border-radius: 5px;
        font-size: 14px;
    }
</style>
""", unsafe_allow_html=True)


class DichotomousKey:
    """Class to handle dichotomous key navigation."""
    
    def __init__(self, key_data: Dict):
        """Initialize with key data."""
        self.title = key_data.get('title', 'Unknown Key')
        self.entries = key_data.get('entries', [])
        self.couplets = key_data.get('couplets', {})
        
        # Build lookup dictionary
        self.entry_dict = {entry['id']: entry for entry in self.entries}
    
    def get_entry(self, entry_id: str) -> Optional[Dict]:
        """Get an entry by ID."""
        return self.entry_dict.get(entry_id)
    
    def parse_next_id(self, content: str) -> Optional[str]:
        """Extract the next couplet ID from content."""
        import re
        # Look for patterns like "2", "10", "35", etc. at the end
        match = re.search(r'\b(\d+\'\?)\s*$', content)
        if match:
            return match.group(1)
        
        match = re.search(r'\b(\d+)\s*$', content)
        if match:
            return f"{match.group(1)}."
        
        # Check for explicit taxon name (terminal node)
        # Pattern: Order/Family name followed by page number
        match = re.search(r'([A-Z][a-z]+(?:ae|ida|ida|inae)?)\s+p\.\s*\d+', content)
        if match:
            return None  # Terminal node
        
        return None
    
    def get_result(self, content: str) -> Optional[str]:
        """Extract taxonomic result from content."""
        import re
        # Look for taxon names with page numbers
        match = re.search(r'([A-Z][a-z]+(?:ae|ida|inae)?)\s+p\.\s*\d+', content)
        if match:
            return match.group(1)
        return None
    
    def is_terminal(self, entry_id: str) -> bool:
        """Check if entry is a terminal node."""
        entry = self.get_entry(entry_id)
        if not entry:
            return False
        
        content = entry.get('content', '')
        return self.get_result(content) is not None


def load_available_keys() -> Dict[str, Path]:
    """Load all available dichotomous keys."""
    keys = {}
    
    # Check for Arachnida key in root
    if os.path.exists('dichotomous_keys.json'):
        keys['Arachnida (Root)'] = Path('dichotomous_keys.json')
    
    # Check dichotomous_trees directory
    for json_file in Path('.').rglob('*.json'):
        if 'dichotomous' in str(json_file) or 'key' in str(json_file).lower():
            key_name = json_file.stem.replace('_', ' ').title()
            keys[f"{key_name} ({json_file.parent.name})"] = json_file
    
    return keys


def load_key(key_path: Path) -> Optional[DichotomousKey]:
    """Load a dichotomous key from file."""
    try:
        with open(key_path, 'r') as f:
            data = json.load(f)
        return DichotomousKey(data)
    except Exception as e:
        st.error(f"Error loading key: {e}")
        return None


def display_navigation_panel():
    """Display the navigation history panel."""
    if 'history' in st.session_state and st.session_state.history:
        st.sidebar.markdown("### 📜 Navigation History")
        
        for i, (couplet_id, choice, content) in enumerate(reversed(st.session_state.history)):
            # Truncate content for display
            display_content = content[:60] + "..." if len(content) > 60 else content
            st.sidebar.markdown(f"""
            <div class="history-item">
                <strong>{i+1}. Couplet {couplet_id}</strong><br/>
                Choice: {choice}<br/>
                <small>{display_content}</small>
            </div>
            """, unsafe_allow_html=True)
        
        col1, col2 = st.sidebar.columns(2)
        with col1:
            if st.button("⬅️ Back", use_container_width=True):
                if len(st.session_state.history) > 0:
                    st.session_state.history.pop()
                    if st.session_state.history:
                        last_entry = st.session_state.history[-1]
                        st.session_state.current_id = last_entry[0]
                    else:
                        st.session_state.current_id = "1."
                    st.rerun()
        
        with col2:
            if st.button("🔄 Restart", use_container_width=True):
                st.session_state.history = []
                st.session_state.current_id = "1."
                st.rerun()


def display_current_couplet(key: DichotomousKey):
    """Display the current couplet and choices."""
    current_id = st.session_state.get('current_id', '1.')
    entry = key.get_entry(current_id)
    
    if not entry:
        st.error(f"Entry {current_id} not found in key")
        return
    
    content = entry['content']
    
    # Check if terminal node
    result = key.get_result(content)
    if result:
        st.markdown(f"""
        <div class="result-box">
            <h2>🎯 Result: {result}</h2>
            <p>{content}</p>
        </div>
        """, unsafe_allow_html=True)
        
        if st.button("🔄 Start Over", type="primary"):
            st.session_state.history = []
            st.session_state.current_id = "1."
            st.rerun()
        return
    
    # Display current couplet
    st.markdown(f"""
    <div class="big-font">
        Couplet {current_id}
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown(f"**{content}**")
    
    # Find corresponding prime entry (alternative choice)
    prime_id = current_id.rstrip('.') + "'."
    prime_entry = key.get_entry(prime_id)
    
    if prime_entry:
        # Two-choice couplet
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("### Choice A (Yes)")
            st.info(content)
            if st.button("Select Choice A ✓", key="choice_a", use_container_width=True):
                next_id = key.parse_next_id(content)
                if next_id:
                    st.session_state.history.append((current_id, "A", content))
                    st.session_state.current_id = next_id
                    st.rerun()
                else:
                    st.warning("No next step found")
        
        with col2:
            st.markdown("### Choice B (No)")
            prime_content = prime_entry['content']
            st.info(prime_content)
            if st.button("Select Choice B ✓", key="choice_b", use_container_width=True):
                next_id = key.parse_next_id(prime_content)
                if next_id:
                    st.session_state.history.append((current_id, "B", prime_content))
                    st.session_state.current_id = next_id
                    st.rerun()
                else:
                    st.warning("No next step found")
    else:
        # Single entry - extract next step
        st.info("Make your choice based on the description above")
        if st.button("Continue ➡️", type="primary", use_container_width=True):
            next_id = key.parse_next_id(content)
            if next_id:
                st.session_state.history.append((current_id, "Continue", content))
                st.session_state.current_id = next_id
                st.rerun()


def main():
    """Main application function."""
    st.title("🔬 Dichotomous Key Navigator")
    st.markdown("*Interactive tool for taxonomic identification using dichotomous keys*")
    
    # Initialize session state
    if 'current_id' not in st.session_state:
        st.session_state.current_id = "1."
    if 'history' not in st.session_state:
        st.session_state.history = []
    
    # Sidebar - Key selection
    st.sidebar.title("🗂️ Key Selection")
    
    available_keys = load_available_keys()
    
    if not available_keys:
        st.error("No dichotomous keys found. Please ensure JSON key files are in the directory.")
        st.info("""
        Expected file locations:
        - `dichotomous_keys.json` (root)
        - `dichotomous_trees/**/*.json`
        """)
        return
    
    selected_key_name = st.sidebar.selectbox(
        "Select a dichotomous key:",
        options=list(available_keys.keys())
    )
    
    key_path = available_keys[selected_key_name]
    key = load_key(key_path)
    
    if not key:
        return
    
    st.sidebar.markdown(f"**Key:** {key.title}")
    st.sidebar.markdown(f"**Entries:** {len(key.entries)}")
    st.sidebar.markdown("---")
    
    # Display navigation panel
    display_navigation_panel()
    
    # Main content area
    st.markdown("---")
    
    # Display instructions
    with st.expander("ℹ️ How to Use", expanded=False):
        st.markdown("""
        ### Instructions
        
        1. **Read the description** carefully for the current couplet
        2. **Choose the option** that best matches your specimen
        3. **Navigate** through the key by making selections
        4. **Use the sidebar** to:
           - View your navigation history
           - Go back to previous choices
           - Restart the key
        
        ### Understanding Dichotomous Keys
        
        - Each **couplet** presents two alternative choices
        - Choice **A** means the description matches your specimen
        - Choice **B** (prime) means it does not match
        - Continue until you reach a **terminal identification**
        
        ### Tips
        
        - Take your time reading descriptions
        - Have reference materials handy
        - If uncertain, note both paths and backtrack if needed
        """)
    
    # Display current couplet
    display_current_couplet(key)
    
    # Footer
    st.markdown("---")
    st.markdown("""
    <div style='text-align: center; color: #666; padding: 20px;'>
        <small>Dichotomous Key Navigator | Built with Streamlit</small>
    </div>
    """, unsafe_allow_html=True)


if __name__ == "__main__":
    main()
