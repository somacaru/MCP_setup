# BlackArch Security Tools MCP Server

A comprehensive Model Context Protocol (MCP) server that integrates BlackArch Linux security tools for educational penetration testing. Built with security-first principles and strict input validation.

## What is MCP?

The Model Context Protocol (MCP) is a standard for connecting AI assistants to external data sources and tools. This project serves as a starting point for building your own MCP servers.

## Features

- **Echo Tool**: A simple tool that echoes back any message you send
- **Echo Resource**: A resource that can be read with custom messages
- **FastMCP Framework**: Built using the modern FastMCP library
- **Comprehensive Testing**: Includes PowerShell and Bash test scripts
- **Easy Setup**: Minimal dependencies and clear structure

## Quick Start

### Prerequisites

- Python 3.13 or higher
- [jq](https://stedolan.github.io/jq/download/) (for JSON formatting in tests)

### Installation

1. **Clone or download this project**
2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```
   or using uv (recommended):
   ```bash
   uv sync
   ```

### Running the Server

```bash
python echo_server.py
```

The server runs in stdio mode, waiting for JSON-RPC requests.

### Testing the Server

#### Quick Test with jq
```bash
# Test tool listing
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}' | python echo_server.py

echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' | python echo_server.py

echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python echo_server.py | jq
```

#### Comprehensive Testing

**PowerShell (Windows):**
```powershell
& "C:\Program Files\PowerShell\7-preview\pwsh.exe" -File test_echo_mcp.ps1
```

**Bash (Linux/macOS):**
```bash
chmod +x test_echo_mcp.sh
./test_echo_mcp.sh
```

## Project Structure

```
project-011/
├── echo_server.py          # Main MCP server implementation
├── test_echo_mcp.ps1       # Comprehensive PowerShell test script
├── test_echo_mcp.sh        # Bash test script
├── requirements.txt        # Python dependencies
├── pyproject.toml         # Project configuration
└── README.md              # This file
```

## Understanding the Code

### Basic MCP Server Structure

```python
from mcp.server.fastmcp import FastMCP

# Create the MCP server
mcp = FastMCP("YourServerName")

# Define a tool
@mcp.tool()
def your_tool(param: str) -> str:
    """Description of what your tool does"""
    return f"Result: {param}"

# Define a resource
@mcp.resource("your://{param}")
def your_resource(param: str) -> str:
    """Description of your resource"""
    return f"Resource content: {param}"

# Run the server
if __name__ == "__main__":
    mcp.run(transport='stdio')
```

### Key Concepts

- **Tools**: Functions that can be called by AI assistants to perform actions
- **Resources**: Data sources that can be read by AI assistants
- **Transport**: How the server communicates (stdio, HTTP, etc.)
- **JSON-RPC**: The protocol used for communication

## Creating Your Own MCP Server

### 1. Start with the Echo Server

Copy this project and modify `echo_server.py`:

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("MyCustomServer")

@mcp.tool()
def my_custom_tool(input_data: str) -> str:
    """My custom tool that does something useful"""
    # Your logic here
    return f"Processed: {input_data}"

if __name__ == "__main__":
    mcp.run(transport='stdio')
```

### 2. Add More Complex Tools

```python
from typing import List, Dict, Any
import requests

@mcp.tool()
def fetch_weather(city: str) -> Dict[str, Any]:
    """Fetch weather data for a city"""
    # Your API call logic here
    return {"city": city, "temperature": "22°C", "condition": "sunny"}

@mcp.tool()
def process_data(data: List[str]) -> List[str]:
    """Process a list of data items"""
    return [item.upper() for item in data]
```

### 3. Add Resources

```python
@mcp.resource("data://{dataset}")
def get_dataset(dataset: str) -> str:
    """Get data from a specific dataset"""
    # Your data retrieval logic here
    return f"Data from {dataset}: ..."
```

### 4. Update Dependencies

Add any new dependencies to `requirements.txt`:

```
mcp[cli]>=1.15.0
requests>=2.31.0
pandas>=2.0.0
```

## Integration with AI Assistants

### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "echo-server": {
      "command": "python",
      "args": ["C:/path/to/your/echo_server.py"]
    }
  }
}
```

### Other MCP Clients

The server follows the MCP specification and should work with any MCP-compatible client.

## Testing Your Server

### Manual Testing

1. **Initialize the server**:
   ```json
   {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}
   ```

2. **Send initialized notification**:
   ```json
   {"jsonrpc":"2.0","method":"notifications/initialized","params":{}}
   ```

3. **List available tools**:
   ```json
   {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
   ```

4. **Call a tool**:
   ```json
   {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo_tool","arguments":{"message":"Hello!"}}}
   ```

### Automated Testing

Use the provided test scripts as templates for your own testing:

- `test_echo_mcp.ps1` - Comprehensive PowerShell testing
- `test_echo_mcp.sh` - Bash testing

## Common Issues and Solutions

### "Failed to validate request: Received request before initialization was complete"

**Solution**: Always send the initialization sequence first:
1. `initialize` request
2. `notifications/initialized` 
3. Then your actual requests

### "Tool not found" errors

**Solution**: Check that your tool is properly decorated with `@mcp.tool()` and the name matches exactly.

### Performance issues

**Solution**: 
- Use async functions for I/O operations
- Implement proper error handling
- Consider caching for expensive operations

## Next Steps

1. **Explore the MCP Specification**: [Official MCP Documentation](https://modelcontextprotocol.io/)
2. **Check out FastMCP**: [FastMCP GitHub](https://github.com/jlowin/fastmcp)
3. **Build Real Tools**: Create tools that interact with APIs, databases, or file systems
4. **Add Authentication**: Implement security for production use
5. **Deploy**: Consider containerization with Docker

## Contributing

This is a template project. Feel free to:
- Fork and modify for your needs
- Add more examples
- Improve the test scripts
- Share your MCP server implementations

## License

This project is provided as-is for educational and development purposes.

---

**Happy MCP Development!** 🚀

For questions or issues, refer to the [MCP Community](https://github.com/modelcontextprotocol) or create an issue in your fork of this project.
