# BlackArch Security Tools MCP Server
# Educational penetration testing environment with security restrictions

FROM blackarchlinux:latest

# Set environment variables
ENV SCAN_DIRECTORY=/scans
ENV MAX_SCAN_TIME=300
ENV NONROOT=true

# Install Python 3 and pip
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    python3 \
    python-pip \
    sudo \
    curl \
    wget \
    git

# Create non-root user for security
RUN useradd -m -s /bin/bash security
RUN usermod -aG sudo security
RUN echo "security ALL=(ALL) NOPASSWD: /usr/bin/nmap, /usr/bin/nikto, /usr/bin/dirb, /usr/bin/wpscan, /usr/bin/sqlmap, /usr/bin/searchsploit, /usr/bin/hydra" >> /etc/sudoers

# Create scan directory with proper permissions
RUN mkdir -p $SCAN_DIRECTORY && \
    chown security:security $SCAN_DIRECTORY && \
    chmod 755 $SCAN_DIRECTORY

# Install additional required tools if not already present
RUN pacman -S --noconfirm \
    nmap \
    nikto \
    dirb \
    wpscan \
    sqlmap \
    exploit-db \
    hydra \
    wordlists || true

# Install Python MCP dependency
RUN pip3 install mcp[cli]>=1.15.0

# Install FastMCP
RUN pip3 install fastmcp

# Copy MCP server and test files
COPY security_mcp_server.py /
COPY test_security_mcp.ps1 /
COPY requirements.txt /

# Install Python dependencies
RUN pip3 install -r requirements.txt

# Set proper permissions
RUN chown security:security /security_mcp_server.py
RUN chmod +x /security_mcp_server.py

# Switch to non-root user
USER security
WORKDIR /home/security

# Set up environment
ENV PATH="/home/security/.local/bin:$PATH"
ENV PYTHONPATH="/security_mcp_server.py"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import subprocess; subprocess.run(['pgrep', '-f', 'security_mcp_server'], check=True)" || exit 1

# Expose port for MCP inspector (optional)
EXPOSE 6274

# Default command
CMD ["python3", "/security_mcp_server.py"]
