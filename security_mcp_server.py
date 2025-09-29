#!/usr/bin/env python3
"""
BlackArch Security Tools MCP Server
Provides security testing tools through MCP protocol for educational purposes
"""

import subprocess
import time
import logging
import re
import os
import json
from typing import Dict, List, Optional, Any
from pathlib import Path
from mcp.server.fastmcp import FastMCP

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastMCP server
mcp = FastMCP("BlackArchSecurityTools")

# Security configuration
ALLOWED_TARGETS_REGEX = re.compile(r'^(localhost|127\.0\.0\.1|10\.|192\.168\.|172\.)', re.IGNORECASE)
MAX_SCAN_TIME = 300  # 5 minutes max per scan
SCAN_DIRECTORY = "/tmp/scans"
SAFE_PORTS = [22, 23, 25, 53, 80, 110, 143, 443, 993, 995]

def ensure_non_root():
    """Ensure we're not running as root for security"""
    if os.geteuid() == 0:
        logger.error("This tool should not be run as root for security reasons")
        raise PermissionError("Must run as non-root user")

def sanitize_target(target: str) -> str:
    """Sanitize and validate target IP/domain"""
    target = target.strip()
    if not target:
        raise ValueError>("Target cannot be empty")
    
    # Only allow private networks and localhost for educational purposes
    if not ALLOWED_TARGETS_REGEX.match(target):
        raise ValueError(f"Target {target} not allowed. Only private networks (192.168.x.x, 10.x.x.x, localhost) permitted")
    
    return target

def sanitize_port_range(ports: str) -> str:
    """Sanitize port range input"""
    if not ports:
        return "22,23,25,53,80,110,143,443,993,995"
    
    # Basic validation - only numbers, commas, dashes
    if not re.match(r'^[0-9,\-\s]+$', ports):
        raise ValueError("Invalid port format. Use numbers, commas, or ranges (e.g., 80,443,8000-9000)")
    
    return ports

def cleanup_temp_files():
    """Clean up temporary scan files"""
    try:
        for file_path in Path(SCAN_DIRECTORY).glob("*.txt"):
            if file_path.stat().st_mtime < time.time() - 3600:  # 1 hour old
                file_path.unlink()
    except Exception as e:
        logger.warning(f"Failed to cleanup temp files: {e}")

def run_command(cmd: List[str], timeout: int = MAX_SCAN_TIME) -> Dict[str, Any]:
    """Run command with timeout and proper error handling"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=SCAN_DIRECTORY
        )
        
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "return_code": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Command timed out after {timeout} seconds",
            "return_code": -1
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Command execution error: {str(e)}",
            "return_code": -1
        }

# Security tool wrappers

@mcp.tool()
def nmap_scan(target: str, scan_type: str = "basic", ports: str = "", options: str = "") -> str:
    """
    Perform nmap network scan
    
    Args:
        target: Target host or network (allowed: private networks only)
        scan_type: Type of scan (basic, aggressive, stealth, udp)
        ports: Port range or ports to scan (default: common ports)
        options: Additional nmap options
    
    Returns:
        Formatted nmap results
    """
    ensure_non_root()
    target = sanitize_target(target)
    
    # Set scan timeout based on type
    timeouts = {
        "basic": 60,
        "aggressive": 120,
        "stealth": 180,
        "udp": 240
    }
    timeout = timeouts.get(scan_type, 60)
    
    # Build nmap command
    cmd = ["nmap", "-v"]
    
    # Add scan type specific options
    if scan_type == "basic":
        cmd.extend(["-sS", "-T4"])
    elif scan_type == "aggressive":
        cmd.extend(["-sS", "-A", "-T4"])
    elif scan_type == "stealth":
        cmd.extend(["-sS -T2", "-f"])
    elif scan_type == "udp":
        cmd.extend(["-sU", "-T3"])
    
    # Add ports
    if ports:
        ports_sanitized = sanitize_port_range(ports)
        cmd.extend(["-p", ports_sanitized])
    else:
        cmd.extend(["-p", "22,23,25,53,80,110,143,443,993,995"])
    
    # Add target
    cmd.append(target)
    
    # Add additional options if specified
    if options:
        cmd.extend(options.split())
    
    logger.info(f"Running nmap scan: {' '.join(cmd)}")
    
    result = run_command(cmd, timeout)
    
    if result["success"]:
        return f"✅ Nmap {scan_type} scan completed successfully\n\n{result['stdout']}"
    else:
        return f"❌ Nmap scan failed\n\nError: {result['stderr']}\n\nCommand: {' '.join(cmd)}"

@mcp.tool()
def nikto_scan(target: str, port: int = 80, ssl: bool = False) -> str:
    """
    Perform web vulnerability scan using Nikto
    
    Args:
        target: Target web server (IP or hostname)
        port: Port number to scan
        ssl: Use HTTPS
        
    Returns:
        Formatted Nikto scan results
    """
    ensure_non_root()
    target = sanitize_target(target)
    
    protocol = "https" if ssl else "http"
    url = f"{protocol}://{target}:{port}"
    
    cmd = ["nikto", "-h", url, "-Format", "txt"]
    
    logger.info(f"Running Nikto scan: {' '.join(cmd)}")
    
    result = run_command(cmd)
    
    if result["success"]:
        # Parse and format results
        lines = result["stdout"].strip().split('\n')
        formatted_output = []
        
        for line in lines:
            if line.strip():
                formatted_output.append(line)
        
        return f"✅ Nikto scan completed for {url}\n\n" + "\n".join(formatted_output)
    else:
        return f"❌ Nikto scan failed\n\nError: {result['stderr']}"

@mcp.tool()
def dirb_scan(target: str, port: int = 80, ssl: bool = False, wordlist: str = "") -> str:
    """
    Perform directory brute force scan using Dirb
    
    Args:
        target: Target web server
        port: Port number
        ssl: Use HTTPS
        wordlist: Wordlist file (optional)
    
    Returns:
        Formatted Dirb scan results
    """
    ensure_non_root()
    target = sanitize_target(target)
    
    protocol = "https" if ssl else "http"
    url = f"{protocol}://{target}:{port}"
    
    cmd = ["dirb": url]
    
    if wordlist:
        cmd.append(wordlist)
    
    logger.info(f"Running Dirb scan: {' '.join(cmd)}")
    
    result = run_command(cmd, 180)  # 3 minute timeout for dirb
    
    if result["success"]:
        return f"✅ Dirb scan completed for {url}\n\n{result['stdout']}"
    else:
        return f"❌ Dirb scan failed\n\nError: {result['stderr']}"

@mcp.tool()
def wpscan_scan(target: str, port: int = 80, ssl: bool = False, enumerate: List[str] = None) -> str:
    """
    Scan WordPress sites for vulnerabilities using WPScan
    
    Args:
        target: Target WordPress site
        port: Port number
        ssl: Use HTTPS
        enumerate: Items to enumerate (users, plugins, themes, etc.)
    
    Returns:
        Formatted WPScan results
    """
    ensure_non_root()
    target = sanitize_target(target)
    
    protocol = "https" if ssl else "http"
    url = f"{protocol}://{target}:{port}"
    
    cmd = ["wpscan", "--url", url, "--no-banner"]
    
    if enumerate:
        for item in enumerate:
            cmd.extend(["--enumerate", item])
    
    logger.info(f"Running WPScan: {' '.join(cmd)}")
    
    result = run_command(cmd, 300)
    
    if result["success"]:
        return f"✅ WPScan completed for {url}\n\n{result['stdout']}"
    else:
        return f"❌ WPScan failed\n\nError: {result['stderr']}"

@mcp.tool()
def sqlmap_scan(target: str, method: str = "GET", data: str = "", cookie: str = "") -> str:
    """
    Test for SQL injection vulnerabilities using SQLMap
    
    Args:
        target: Target URL or endpoint
        method: HTTP method (GET, POST)
        data: POST data (for POST requests)
        cookie: Session cookies
    
    Returns:
        Formatted SQLMap results
    """
    ensure_non_root()
    target = sanitize_target(target)
    
    cmd = ["sqlmap", "-u", target, "--batch", "--no-logging"]
    
    if method.upper() == "POST":
        cmd.extend(["--data", data])
    
    if cookie:
        cmd.extend(["--cookie", cookie])
    
    logger.info(f"Running SQLMap: {' '.join(cmd)}")
    
    result = run_command(cmd, 300)
    
    if result["success"]:
        return f"✅ SQLMap scan completed for {target}\n\n{result['stdout']}"
    else:
        return f"❌ SQLMap scan failed\n\nError: {result['stderr']}"

@mcp.tool()
def searchsploit_search(keyword: str, platform: str = "", exploit_type: str = "") -> str:
    """
    Search for known exploits using SearchSploit
    
    Args:
        keyword: Search keyword
        platform: Target platform/OS
        exploit_type: Type of exploit (remote, local, webapps, etc.)
    
    Returns:
        Formatted SearchSploit results
    """
    cmd = ["searchsploit", keyword]
    
    if platform:
        cmd.extend(["-p", platform])
    
    if exploit_type:
        cmd.extend(["-t", exploit_type])
    
    logger.info(f"Running SearchSploit: {' '.join(cmd)}")
    
    result = run_command(cmd)
    
    if result["success"]:
        return f"✅ SearchSploit search completed for '{keyword}'\n\n{result['stdout']}"
    else:
        return f"❌ SearchSploit search failed\n\nError: {result['stderr']}"

@mcp.tool()
def hydra_bruteforce(target: str, service: str, username: str, wordlist: str = "") -> str:
    """
    Perform brute force attack using Hydra (for authorized testing only)
    
    Args:
        target: Target IP address
        service: Service to attack (ssh, ftp, http-post-form, etc.)
        username: Username for brute force
        wordlist: Path to password wordlist (optional)
    
    Returns:
        Formatted Hydra results
    """
    ensure_non_root()
    target = sanitize_target(target)
    
    cmd = ["hydra", "-l", username, "-P", wordlist or "/usr/share/wordlists/rockyou.txt"]
    cmd.extend([target, service])
    
    logger.info(f"Running Hydra: {' '.join(cmd)}")
    
    result = run_command(cmd, 180)
    
    if result["success"]:
        return f"✅ Hydra brute force completed\n\n{result['stdout']}"
    else:
        return f"❌ Hydra brute force failed\n\nError: {result['stderr']}"

# Informational tools

@mcp.tool()
def list_available_tools() -> str:
    """List all available security tools in the container"""
    tools_info = """
    Available BlackArch Security Tools:

    Network Scanning:
    - nmap: Network mapper and port scanner
    - nmap_scan: MCP wrapper for nmap with safety restrictions

    Web Application Testing:
    - nikto: Web vulnerability scanner  
    - dirb: Directory brute forcer
    - wpscan: WordPress security scanner
    - sqlmap: SQL injection testing tool

    Security Research:
    - searchsploit: Exploit database search
    - hydra: Password brute forcer

    System Information:
    - Available tools can be verified with: which <tool_name>
    - Tool versions: <tool_name> --version
    """
    
    # Check which tools are actually available
    available_tools = []
    tool_commands = ["nmap", "nikto", "dirb", "wpscan", "sqlmap", "searchsploit", "hydra"]
    
    for tool in tool_commands:
        try:
            result = subprocess.run(["which", tool], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                available_tools.append(tool)
        except:
            pass
    
    available_info = f"\nCurrently installed tools: {', '.join(available_tools)}\n"
    
    return tools_info + available_info

@mcp.tool()
def show_security_disclaimer() -> str:
    """Display security and legal disclaimer"""
    return """
    ⚠️  SECURITY TESTING DISCLAIMER ⚠️
    
    This tool is for authorized security testing ONLY:
    
    1. Only test systems you own or have explicit permission to test
    2. Only target private networks (192.168.x.x, 10.x.x.x, localhost)
    3. This tool runs with restricted permissions for safety
    4. Always follow responsible disclosure practices
    5. Respect privacy and applicable laws
    
    Educational Use Only:
    - This MCP server is designed for learning cybersecurity concepts
    - Practice in isolated lab environments
    - Understand ethical hacking principles
    
    ⚖️ Legal Notice:
    Unauthorized penetration testing is illegal.
    Always obtain proper authorization before testing.
    """

# Initialize scan directory and cleanup
if __name__ == "__main__":
    try:
        # Ensure scan directory exists
        Path(SCAN_DIRECTORY).mkdir(exist_ok=True)
        
        # Cleanup old files
        cleanup_temp_files()
        
        logger.info("BlackArch Security Tools MCP Server starting...")
        logger.info(f"Scan directory: {SCAN_DIRECTORY}")
        logger.info("Server configured for educational security testing only")
        
        mcp.run(transport='stdio')
        
    except Exception as e:
        logger.error(f"Server initialization failed: {e}")
        raise
