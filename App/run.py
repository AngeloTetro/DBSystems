#!/usr/bin/env python3
"""
Simple Flask App Launcher
Starts the web application directly
"""

import sys
from pathlib import Path

def start_flask_app():
    """Start the Flask application"""
    print("=" * 60)
    print("🌐 Starting Web Application")
    print("=" * 60)
    
    # Add current directory to path to import app
    app_dir = Path(__file__).parent
    sys.path.insert(0, str(app_dir))
    
    try:
        from app import app
        
        print("\n📱 Flask app is running!")
        print("🔗 Open your browser and navigate to:")
        print("   → http://localhost:5000")
        print("\n💡 Press Ctrl+C to stop the server\n")
        
        # Run Flask app in debug mode
        app.run(debug=True, host='localhost', port=5000)
        
    except ImportError as e:
        print(f"❌ Error importing Flask app: {e}")
        return False
    except Exception as e:
        print(f"❌ Error starting Flask app: {e}")
        return False

if __name__ == '__main__':
    try:
        start_flask_app()
    except KeyboardInterrupt:
        print("\n\n👋 Application stopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
