#!/usr/bin/env python3
"""
Auto-restart wrapper for Cruise backend server.
Restarts the server automatically if it crashes.
"""
import subprocess
import sys
import time
from datetime import datetime

def log(msg):
    """Print timestamped log message."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {msg}")

def run_server():
    """Run the server with auto-restart on crash."""
    restart_count = 0
    max_restarts = 10
    restart_delay = 3  # seconds
    
    log("🚀 Starting Cruise backend server with auto-restart...")
    
    while restart_count < max_restarts:
        try:
            log(f"Starting server (attempt {restart_count + 1}/{max_restarts})...")
            
            # Run the server
            process = subprocess.Popen(
                [sys.executable, "main.py"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            # Stream output in real-time
            for line in process.stdout:
                print(line, end='')
            
            # Wait for process to complete
            return_code = process.wait()
            
            if return_code == 0:
                log("✅ Server stopped gracefully (exit code 0)")
                break
            else:
                log(f"⚠️ Server crashed with exit code {return_code}")
                restart_count += 1
                
                if restart_count < max_restarts:
                    log(f"Restarting in {restart_delay} seconds...")
                    time.sleep(restart_delay)
                else:
                    log(f"❌ Max restarts ({max_restarts}) reached. Stopping.")
                    break
                    
        except KeyboardInterrupt:
            log("🛑 Server stopped by user (Ctrl+C)")
            if process:
                process.terminate()
            break
        except Exception as e:
            log(f"❌ Error running server: {e}")
            restart_count += 1
            if restart_count < max_restarts:
                time.sleep(restart_delay)

if __name__ == "__main__":
    run_server()
